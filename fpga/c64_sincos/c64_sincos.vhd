library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- The following defines the type fraction_type,
-- and the helper functions real2fraction and fraction2real.

library work;
   use work.c64_sincos_pkg.all;

-- This module takes a C64 floating point number (s_exp_i, s_mant_i) and
-- returns the sine (m_sin_exp_o, m_sin_mant_o) and the cosine (m_cos_exp_o,
-- m_cos_mant_o) as C64 floating point numbers.
--
-- It calculates C_GUARD_BITS (see c64_sincos_pkg) extra bits in order to
-- reduce rounding error.
--
-- Input and output are given in C64 floating point format (5-byte).
-- * exp is the exponent byte.
-- * mant is the mantissa (must be normalized).
-- Example values
-- Value |  Exp | Mantissa
--   0.0 | 0x00 |   XXXXXXXX
--   0.5 | 0x80 | 0x00000000
--   1.0 | 0x81 | 0x00000000
--  -1.0 | 0x81 | 0x80000000
-- See also: https://www.c64-wiki.com/wiki/Floating_point_arithmetic
--
-- The algorithm is described here:
-- https://www.allaboutcircuits.com/technical-articles/an-introduction-to-the-cordic-algorithm/
--
-- Step 1 is to reduce modulo 2*pi and de-normalize (i.e. apply the exponent).
-- Step 2 is to determine octant and reduce modulo pi/4.
-- Step 3 is to apply the Cordic algorithm, G_STEPS iterations in each clock
-- cycle.
-- Step 4 is to construct the output result using the octant.
-- Step 5 is to normalize (i.e. to calculate the exponent).
-- Steps 1 and 2 are done in one clock cycle, and so are steps 4 and 5.
--
-- Interface:
-- The input is accepted when s_valid_i and s_ready_o are both asserted on the
-- same clock edge. The result is presented when m_valid_o is asserted, and is
-- held stable until m_ready_i is asserted. None of the output signals depend
-- combinatorially on any of the input signals. rst_i is a synchronous reset
-- (active high). It clears m_valid_o, and abandons a calculation in progress.
--
-- Latency and throughput:
-- m_valid_o is asserted 32/G_STEPS + 2 clock cycles after the input is
-- accepted, i.e. 10 clock cycles for G_STEPS = 4. A new input is accepted in
-- the clock cycle after the result is written to the output register. So if
-- m_ready_i is constantly asserted, a new input is accepted every
-- 32/G_STEPS + 3 clock cycles.

entity c64_sincos is
   generic (
      -- The number of CORDIC iterations in each clock cycle. 32 must be
      -- divisible by it, i.e. 1, 2, 4, 8, 16, or 32.
      G_STEPS : positive := 4;
      G_DEBUG : boolean  := false
   );
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;

      -- Input
      s_valid_i    : in  std_logic;
      s_ready_o    : out std_logic;
      s_exp_i      : in  std_logic_vector( 7 downto 0);   -- Angle in radians, exponent
      s_mant_i     : in  std_logic_vector(31 downto 0);   -- Angle in radians, mantissa

      -- Output
      m_valid_o    : out std_logic;
      m_ready_i    : in  std_logic;
      m_sin_exp_o  : out std_logic_vector( 7 downto 0);   -- Sine, exponent
      m_sin_mant_o : out std_logic_vector(31 downto 0);   -- Sine, mantissa
      m_cos_exp_o  : out std_logic_vector( 7 downto 0);   -- Cosine, exponent
      m_cos_mant_o : out std_logic_vector(31 downto 0)    -- Cosine, mantissa
   );
end entity c64_sincos;

architecture synthesis of c64_sincos is

   -- C_ANGLE_NUM is the number of CORDIC iterations.
   constant C_ANGLE_NUM : natural         := 33;

   -- This calculates the scaling used in the CORDIC algorithm.
   -- The returned value is approximately 0.6072529350088812, in the limit
   -- of large value of C_ANGLE_NUM.

   pure function calc_scaling return fraction_type is
      variable res_v : real := 1.0;
   begin
      for i in 0 to C_ANGLE_NUM - 1 loop
         res_v := res_v * (1.0 + 1.0 / (4.0 ** i));
      end loop;
      res_v := 1.0 / sqrt(res_v);

      return real2fraction(res_v);
   end function calc_scaling;

   constant C_SCALE       : fraction_type := calc_scaling;
   constant C_TWO_OVER_PI : fraction_type := real2fraction(0.6366197723675814);

   -- IDLE_ST      : Waiting for a new input.
   -- REDUCE_ST    : Reduce the angle to [0, pi/4], and do the first CORDIC
   --                iteration.
   -- CALC_ST      : The other CORDIC iterations, G_STEPS in each clock cycle.
   -- NORMALIZE_ST : Normalize the final x and y, and write the result to the
   --                output register as soon as the output register is free.
   type   state_type is (
      IDLE_ST, REDUCE_ST, CALC_ST, NORMALIZE_ST
   );
   signal state : state_type            := IDLE_ST;

   signal arg_exp  : unsigned( 7 downto 0);                -- Exponent
   signal arg_mant : unsigned(31 downto 0);                -- Mantissa

   -- The range reduction, see REDUCE_ST
   signal reduce_prod   : unsigned(C_SIZE + 32 downto 0);
   signal reduce_sign   : std_logic;
   signal reduce_shift  : integer range -C_SIZE to C_SIZE;
   signal reduce_angle  : fraction_type;
   signal reduce_octant : unsigned(2 downto 0);
   signal octant        : unsigned(2 downto 0);   -- reduce_octant, stored in REDUCE_ST

   -- The remaining angle, in units of pi/2. After the range reduction it is a
   -- value in [0.0, 0.5], representing an angle in [0, pi/4], and the first
   -- iteration subtracts 0.5 from it.
   -- During calculation, the value may stray slightly outside this interval,
   -- but it will always represent a signed value in [-1.0, 1.0[, i.e. an angle in
   -- [-pi/2, pi/2[.
   signal angle : fraction_type;

   -- x and y will eventually become the result of sine and cosine.
   -- The value of x represents an unsigned value in [0.0, 2.0[.
   -- The value of y represents a signed value in [-1.0, 1.0[.
   signal x : fraction_type;
   signal y : fraction_type;

   -- The CORDIC iterations after the first are done in C_CYCLES clock cycles,
   -- and count is the clock cycle in CALC_ST.
   constant C_CYCLES : natural := (C_ANGLE_NUM - 1) / G_STEPS;
   signal   count    : natural range 0 to C_CYCLES - 1;

   signal rotate_x : fraction_type;
   signal rotate_y : fraction_type;
   signal exp_x    : unsigned(7 downto 0);
   signal exp_y    : unsigned(7 downto 0);

   -- The output registers
   signal sin_exp  : unsigned( 7 downto 0);
   signal sin_mant : unsigned(31 downto 0);
   signal cos_exp  : unsigned( 7 downto 0);
   signal cos_mant : unsigned(31 downto 0);

   pure function count_leading_zeros (arg : fraction_type) return natural is
   begin
      for i in arg'left downto arg'right loop
         if arg(i) /= '0' then
            return arg'left - i;
         end if;
      end loop;
      return arg'length;
   end function count_leading_zeros;

   -- Rotate a fraction either right or left. Interpret the fraction as a signed number.

   pure function rotate (arg : fraction_type; ncount : integer) return unsigned is
      variable res_v : fraction_type;
   begin
      if ncount > 0 then
         -- rotate right
         res_v                           := (others => arg(C_SIZE));
         res_v(C_SIZE - ncount downto 0) := arg(C_SIZE downto ncount);
      else
         -- rotate left
         res_v                         := (others => '0');
         res_v(C_SIZE downto - ncount) := arg(C_SIZE + ncount downto 0);
      end if;
      return res_v;
   end function rotate;

   -- Rotate a fraction either right or left. Interpret the fraction as an unsigned number.

   pure function rotate_unsigned (arg : fraction_type; ncount : integer) return unsigned is
      variable res_v : fraction_type;
   begin
      if ncount > 0 then
         -- rotate right
         res_v                           := (others => '0');
         res_v(C_SIZE - ncount downto 0) := arg(C_SIZE downto ncount);
      else
         -- rotate left
         res_v                         := (others => '0');
         res_v(C_SIZE downto - ncount) := arg(C_SIZE + ncount downto 0);
      end if;
      return res_v;
   end function rotate_unsigned;

   -- Rotate a fraction left.

   pure function rotate_left (arg : fraction_type; ncount : integer) return unsigned is
      variable res_v : fraction_type;
   begin
      res_v                       := (others => '0');
      res_v(C_SIZE downto ncount) := arg(C_SIZE - ncount downto 0);
      return res_v;
   end function rotate_left;

   type rom_type is array (0 to C_ANGLE_NUM - 1) of fraction_type;

   pure function calc_angles return rom_type is
      variable res_v   : rom_type := (others => (others => '0'));
      variable angle_v : real;
   begin
      for i in 0 to C_ANGLE_NUM - 1 loop
         angle_v  := arctan(0.5 ** i) / (2.0 * arctan(1.0)); -- In units of pi/2
         res_v(i) := real2fraction(angle_v);
         if G_DEBUG then
            report "C_ANGLES(" & to_string(i) & ") = " & to_string(angle_v, 11) & " = 0x" & to_hstring(res_v(i));
         end if;
      end loop;
      return res_v;
   end function calc_angles;

   constant C_ANGLES : rom_type           := calc_angles;

begin

   assert (C_ANGLE_NUM - 1) mod G_STEPS = 0
      report "G_STEPS must divide 32"
      severity failure;

   -- The range reduction: The multiplication by 2/pi, and the shift by the
   -- exponent. These are combinational, and are stored in REDUCE_ST.
   reduce_prod  <= (arg_mant or X"80000000") * C_TWO_OVER_PI;
   reduce_sign  <= arg_mant(31);
   reduce_shift <= 130 - to_integer(arg_exp) when arg_exp > X"62" and arg_exp <= X"A3" else
                   C_SIZE;

   reduce_angle  <= rotate(reduce_prod(C_SIZE + 32 downto 32), reduce_shift);
   reduce_octant <= reduce_angle(C_SIZE - 1 downto C_SIZE - 3);

   s_ready_o <= '1' when state = IDLE_ST else
                '0';

   m_sin_exp_o  <= std_logic_vector(sin_exp);
   m_sin_mant_o <= std_logic_vector(sin_mant);
   m_cos_exp_o  <= std_logic_vector(cos_exp);
   m_cos_mant_o <= std_logic_vector(cos_mant);

   -- The normalization of x and y, i.e. their exponents, and the mantissas
   -- shifted to the left. This is combinational, and used in NORMALIZE_ST.
   normalize_proc : process (all)
   begin
      exp_x    <= X"81" - count_leading_zeros(x);
      exp_y    <= X"81" - count_leading_zeros(y);
      rotate_x <= rotate_left(x, count_leading_zeros(x));
      rotate_y <= rotate_left(y, count_leading_zeros(y));

      -- x must never be greater than 1
      if x(x'left) = '1' then
         rotate_x <= (x'left => '1', others => '0');
      end if;

      -- y must never be less than 0
      if y(y'left) = '1' then
         rotate_y <= (others => '0');
         exp_y    <= X"00";
      end if;
   end process normalize_proc;

   fsm_proc : process (clk_i)
      variable x_v     : fraction_type;
      variable y_v     : fraction_type;
      variable tmp_v   : fraction_type;
      variable angle_v : fraction_type;
      variable i_v     : natural range 0 to C_ANGLE_NUM - 1;
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' then
            m_valid_o <= '0';
         end if;

         case state is

            when IDLE_ST =>
               null;

            when REDUCE_ST =>
               octant <= reduce_octant;
               if reduce_octant(0) = '1' then
                  angle_v := "0" & (not reduce_angle(C_SIZE - 3 downto 0)) & "11";
               else
                  angle_v := "0" & reduce_angle(C_SIZE - 3 downto 0) & "00";
               end if;
               -- angle_v - 0.5, where 0.5 = C_ANGLES(0) is the top fractional bit
               angle <= (not angle_v(C_SIZE - 1)) & (not angle_v(C_SIZE - 1)) &
                        angle_v(C_SIZE - 2 downto 0);

               -- The first iteration (count = 0) always rotates forwards,
               -- since the angle is not negative. So it gives x = y = C_SCALE.
               x     <= C_SCALE;
               y     <= C_SCALE;
               count <= 0;
               state <= CALC_ST;

            when CALC_ST =>
               if G_DEBUG then
                  report "count = " & to_string(count);
                  report "angle = " & to_string(fraction2real(angle), 11) & " * pi/2";
                  report "x     = 0x" & to_hstring(x) & " = " & to_string(fraction2real(x), 11);
                  report "y     = 0x" & to_hstring(y) & " = " & to_string(fraction2real(y), 11);
               end if;

               -- G_STEPS iterations. Iteration i_v shifts by i_v bits. Since
               -- count only has C_CYCLES values, each of these shifts is a
               -- multiplexer with only C_CYCLES inputs.
               x_v     := x;
               y_v     := y;
               angle_v := angle;
               for j in 0 to G_STEPS - 1 loop
                  i_v := 1 + count * G_STEPS + j;
                  if angle_v(angle_v'left) = '0' then
                     tmp_v   := x_v - rotate(y_v, i_v);
                     y_v     := y_v + rotate_unsigned(x_v, i_v);
                     angle_v := angle_v - C_ANGLES(i_v);
                  else
                     tmp_v   := x_v + rotate(y_v, i_v);
                     y_v     := y_v - rotate_unsigned(x_v, i_v);
                     angle_v := angle_v + C_ANGLES(i_v);
                  end if;
                  x_v := tmp_v;
               end loop;
               x     <= x_v;
               y     <= y_v;
               angle <= angle_v;

               if count = C_CYCLES - 1 then
                  state <= NORMALIZE_ST;
               else
                  count <= count + 1;
               end if;

            when NORMALIZE_ST =>
               -- Wait until the output register is free
               if m_valid_o = '0' or m_ready_i = '1' then
                  if G_DEBUG then
                     report "octant = " & to_string(octant);
                     report "exp_x  = " & to_string(exp_x);
                     report "exp_y  = " & to_string(exp_y);
                  end if;

                  case octant is

                     when "000" =>
                        cos_mant     <= rotate_x(C_SIZE downto C_SIZE - 31);
                        sin_mant     <= rotate_y(C_SIZE downto C_SIZE - 31);
                        cos_exp      <= exp_x;
                        sin_exp      <= exp_y;
                        cos_mant(31) <= '0';
                        sin_mant(31) <= reduce_sign;

                     when "001" =>
                        cos_mant     <= rotate_y(C_SIZE downto C_SIZE - 31);
                        sin_mant     <= rotate_x(C_SIZE downto C_SIZE - 31);
                        cos_exp      <= exp_y;
                        sin_exp      <= exp_x;
                        cos_mant(31) <= '0';
                        sin_mant(31) <= reduce_sign;

                     when "010" =>
                        cos_mant     <= rotate_y(C_SIZE downto C_SIZE - 31);
                        sin_mant     <= rotate_x(C_SIZE downto C_SIZE - 31);
                        cos_exp      <= exp_y;
                        sin_exp      <= exp_x;
                        cos_mant(31) <= '1';
                        sin_mant(31) <= reduce_sign;

                     when "011" =>
                        cos_mant     <= rotate_x(C_SIZE downto C_SIZE - 31);
                        sin_mant     <= rotate_y(C_SIZE downto C_SIZE - 31);
                        cos_exp      <= exp_x;
                        sin_exp      <= exp_y;
                        cos_mant(31) <= '1';
                        sin_mant(31) <= reduce_sign;

                     when "100" =>
                        cos_mant     <= rotate_x(C_SIZE downto C_SIZE - 31);
                        sin_mant     <= rotate_y(C_SIZE downto C_SIZE - 31);
                        cos_exp      <= exp_x;
                        sin_exp      <= exp_y;
                        cos_mant(31) <= '1';
                        sin_mant(31) <= not reduce_sign;

                     when "101" =>
                        cos_mant     <= rotate_y(C_SIZE downto C_SIZE - 31);
                        sin_mant     <= rotate_x(C_SIZE downto C_SIZE - 31);
                        cos_exp      <= exp_y;
                        sin_exp      <= exp_x;
                        cos_mant(31) <= '1';
                        sin_mant(31) <= not reduce_sign;

                     when "110" =>
                        cos_mant     <= rotate_y(C_SIZE downto C_SIZE - 31);
                        sin_mant     <= rotate_x(C_SIZE downto C_SIZE - 31);
                        cos_exp      <= exp_y;
                        sin_exp      <= exp_x;
                        cos_mant(31) <= '0';
                        sin_mant(31) <= not reduce_sign;

                     when "111" =>
                        cos_mant     <= rotate_x(C_SIZE downto C_SIZE - 31);
                        sin_mant     <= rotate_y(C_SIZE downto C_SIZE - 31);
                        cos_exp      <= exp_x;
                        sin_exp      <= exp_y;
                        cos_mant(31) <= '0';
                        sin_mant(31) <= not reduce_sign;

                     when others =>
                        null;

                  end case;

                  m_valid_o <= '1';
                  state     <= IDLE_ST;
               end if;

         end case;

         -- This takes priority over the state machine above
         if s_valid_i = '1' and s_ready_o = '1' then
            if G_DEBUG then
               report "s_exp_i       = 0x" & to_hstring(s_exp_i);
               report "s_mant_i      = " &
                      to_string(fraction2real("0" & (unsigned(s_mant_i) or X"80000000") & "0000000"), 11);
               report "C_SCALE       = " & to_string(fraction2real(C_SCALE), 11);
               report "C_TWO_OVER_PI = " & to_string(fraction2real(C_TWO_OVER_PI), 11);
            end if;

            arg_exp  <= unsigned(s_exp_i);
            arg_mant <= unsigned(s_mant_i);
            state    <= REDUCE_ST;
         end if;

         if rst_i = '1' then
            m_valid_o <= '0';
            state     <= IDLE_ST;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;

