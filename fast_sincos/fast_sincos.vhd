library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- The following defines the type fraction_type,
-- and the helper functions real2fraction and fraction2real.

library work;
   use work.fast_sincos_pkg.all;

-- This module takes a C64 floating point number (exp_i, mant_i) and returns the
-- sine and cosine as a C64 floating point number (exp_o, mant_o).
--
-- It takes a total of 42 clock cycles to perform the calculation.
-- It calculates four extra bits in order to reduce rounding error.
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
-- Step 3 is to apply the Cordic algorithm.
-- Step 4 is to construct the output result using the octant.
-- Step 5 is to normalize (i.e. to calculate the exponent).

entity fast_sincos is
   generic (
      G_DEBUG : boolean := false
   );
   port (
      clk_i      : in    std_logic;
      ready_o    : out   std_logic := '1'; -- Asserted when output is ready.
      start_i    : in    std_logic;        -- Assert to restart calculation.
      arg_exp_i  : in    unsigned( 7 downto 0);
      arg_mant_i : in    unsigned(31 downto 0);
      sin_exp_o  : out   unsigned( 7 downto 0);
      sin_mant_o : out   unsigned(31 downto 0);
      cos_exp_o  : out   unsigned( 7 downto 0);
      cos_mant_o : out   unsigned(31 downto 0)
   );
end entity fast_sincos;

architecture synthesis of fast_sincos is

   -- C_ANGLE_NUM is the number of CORDIC iterations.
   constant C_ANGLE_NUM : natural         := 35;

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

   type     state_type is (
      STAGE1_ST, STAGE2_ST, CALC_ST, NORMALIZE_ST, DONE_ST
   );
   signal   state : state_type            := DONE_ST;

   signal   arg_exp  : unsigned( 7 downto 0);                -- Exponent
   signal   arg_mant : unsigned(31 downto 0);                -- Mantissa

   signal   stage1_arg_mant_prod : unsigned(C_SIZE + 32 downto 0);
   signal   stage1_sign          : std_logic;
   signal   stage1_shift         : integer range -C_SIZE to C_SIZE;
   signal   stage1_angle         : fraction_type;
   signal   stage1_octant        : unsigned(2 downto 0);

   signal   x     : fraction_type;
   signal   y     : fraction_type;
   signal   count : natural range 0 to C_ANGLE_NUM;
   signal   angle : fraction_type;

   signal   rotate_x : fraction_type;
   signal   rotate_y : fraction_type;
   signal   exp_x    : unsigned(7 downto 0);
   signal   exp_y    : unsigned(7 downto 0);

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

   type     rom_type is array (0 to C_ANGLE_NUM - 1) of fraction_type;

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

   stage1_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- This adds a register to the DSP output
         stage1_arg_mant_prod <= (arg_mant or x"80000000") * C_TWO_OVER_PI;

         -- Store the sign and amount to shift
         stage1_sign          <= arg_mant(31);
         stage1_shift         <= C_SIZE;
         if arg_exp > x"62" and arg_exp <= x"A3" then
            stage1_shift <= 130 - to_integer(arg_exp);
         end if;
      end if;
   end process stage1_proc;

   stage1_angle  <= rotate(stage1_arg_mant_prod(C_SIZE + 32 downto 32), stage1_shift);
   stage1_octant <= stage1_angle(C_SIZE - 1 downto C_SIZE - 3);

   fsm_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         exp_x    <= x"81" - count_leading_zeros(x);
         exp_y    <= x"81" - count_leading_zeros(y);
         rotate_x <= rotate_left(x, count_leading_zeros(x));
         rotate_y <= rotate_left(y, count_leading_zeros(y));

         case state is

            when STAGE1_ST =>
               -- Wait for stage 1 to complete
               state <= STAGE2_ST;

            when STAGE2_ST =>
               if stage1_octant(0) = '1' then
                  angle <= "0" & (not stage1_angle(C_SIZE - 3 downto 0)) & "11";
               else
                  angle <= "0" & stage1_angle(C_SIZE - 3 downto 0) & "00";
               end if;

               -- Prepare first iteration
               x     <= C_SCALE;
               y     <= (others => '0');
               count <= 0;
               state <= CALC_ST;

            when CALC_ST =>
               if G_DEBUG then
                  report "count = " & to_string(count);
                  report "angle = " & to_string(fraction2real(angle), 11) & " * pi/2";
                  report "x     = " & to_string(fraction2real(x), 11);
                  report "y     = " & to_string(fraction2real(y), 11);
               end if;

               if angle(angle'left) = '0' then
                  x     <= x - rotate(y, count);
                  y     <= y + rotate_unsigned(x, count);
                  angle <= angle - C_ANGLES(count);
               else
                  x     <= x + rotate(y, count);
                  y     <= y - rotate_unsigned(x, count);
                  angle <= angle + C_ANGLES(count);
               end if;

               if count = C_ANGLE_NUM - 1 then
                  state <= NORMALIZE_ST;
               else
                  count <= count + 1;
               end if;

            when NORMALIZE_ST =>
               if G_DEBUG then
                  report "octant = " & to_string(stage1_octant);
                  report "exp_x  = " & to_string(exp_x);
                  report "exp_y  = " & to_string(exp_y);
               end if;

               case stage1_octant is

                  when "000" =>
                     cos_mant_o     <= rotate_x(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate_y(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= exp_x;
                     sin_exp_o      <= exp_y;
                     cos_mant_o(31) <= '0';
                     sin_mant_o(31) <= stage1_sign;

                  when "001" =>
                     cos_mant_o     <= rotate_y(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate_x(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= exp_y;
                     sin_exp_o      <= exp_x;
                     cos_mant_o(31) <= '0';
                     sin_mant_o(31) <= stage1_sign;

                  when "010" =>
                     cos_mant_o     <= rotate_y(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate_x(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= exp_y;
                     sin_exp_o      <= exp_x;
                     cos_mant_o(31) <= '1';
                     sin_mant_o(31) <= stage1_sign;

                  when "011" =>
                     cos_mant_o     <= rotate_x(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate_y(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= exp_x;
                     sin_exp_o      <= exp_y;
                     cos_mant_o(31) <= '1';
                     sin_mant_o(31) <= stage1_sign;

                  when "100" =>
                     cos_mant_o     <= rotate_x(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate_y(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= exp_x;
                     sin_exp_o      <= exp_y;
                     cos_mant_o(31) <= '1';
                     sin_mant_o(31) <= not stage1_sign;

                  when "101" =>
                     cos_mant_o     <= rotate_y(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate_x(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= exp_y;
                     sin_exp_o      <= exp_x;
                     cos_mant_o(31) <= '1';
                     sin_mant_o(31) <= not stage1_sign;

                  when "110" =>
                     cos_mant_o     <= rotate_y(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate_x(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= exp_y;
                     sin_exp_o      <= exp_x;
                     cos_mant_o(31) <= '0';
                     sin_mant_o(31) <= not stage1_sign;

                  when "111" =>
                     cos_mant_o     <= rotate_x(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate_y(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= exp_x;
                     sin_exp_o      <= exp_y;
                     cos_mant_o(31) <= '0';
                     sin_mant_o(31) <= not stage1_sign;

                  when others =>
                     null;

               end case;

               ready_o <= '1';
               state   <= DONE_ST;

            when DONE_ST =>
               null;

         end case;

         if start_i = '1' then
            if G_DEBUG then
               report "arg_exp_i     = 0x" & to_hstring(arg_exp_i);
               report "arg_mant_i    = " & to_string(fraction2real("0" & (arg_mant_i or x"80000000") & "0000"), 11);
               report "C_SCALE       = " & to_string(fraction2real(C_SCALE), 11);
               report "C_TWO_OVER_PI = " & to_string(fraction2real(C_TWO_OVER_PI), 11);
            end if;

            arg_exp  <= arg_exp_i;
            arg_mant <= arg_mant_i;
            ready_o  <= '0';
            state    <= STAGE1_ST;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;

