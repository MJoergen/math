library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

library work;
   use work.fast_sincos_pkg.all;

-- This module takes a floating point number (exp_i, mant_i) and returns the
-- sine and cosing as a floating point number (exp_o, mant_o).
--
-- It takes a total of 34 clock cycles to perform the calculation.
-- It calculates one extra bit in order to perform the correct rounding.
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
-- Step 1 is to store the current sign bit, and use the absolute value
-- Step 2 is to multiply by 1/(2*pi), and keep only the fractional part.
-- Example: arg = 13pi/6
-- 13pi/6 = 6.806784083
-- In C64 floating format that is 83:59D12CDA.
-- We divide by (2pi) to get 13/12 = 1.08C_SIZE-1C_SIZE-1C_SIZE-1, which is encoded as 81:0AAAAAAA.

entity fast_sincos is
   port (
      clk_i      : in    std_logic;
      ready_o    : out   std_logic             := '1';             -- Asserted when output is ready.
      start_i    : in    std_logic;                                -- Assert to restart calculation.
      arg_exp_i  : in    unsigned( 7 downto 0);                    -- Exponent
      arg_mant_i : in    unsigned(31 downto 0);                    -- Mantissa
      sin_exp_o  : out   unsigned( 7 downto 0) := (others => '0'); -- Exponent
      sin_mant_o : out   unsigned(31 downto 0) := (others => '0'); -- Mantissa
      cos_exp_o  : out   unsigned( 7 downto 0) := (others => '0'); -- Exponent
      cos_mant_o : out   unsigned(31 downto 0) := (others => '0')  -- Mantissa
   );
end entity fast_sincos;

architecture synthesis of fast_sincos is

   -- C_ANGLE_NUM is the number of CORDIC iterations.
   constant C_ANGLE_NUM  : natural                       := 35;

   -- This calculates the scaling used in the CORDIC algorithm

   pure function calc_scaling return fraction_type is
      variable res_v : real := 1.0;
   begin
      for i in 0 to C_ANGLE_NUM - 1 loop
         res_v := res_v * (1.0 + 1.0 / (4.0 ** i));
      end loop;
      res_v := 1.0 / sqrt(res_v);

      return real2fraction(res_v);
   end function calc_scaling;



   constant C_SCALE       : fraction_type                := calc_scaling;
   constant C_TWO_OVER_PI : fraction_type                := real2fraction(0.6366197723675814);

   type     state_type is (IDLE_ST, SCALE_ST, SCALE2_ST, FRACTION_ST, FRACTION2_ST,
   CALC_ST, NORMALIZE_ST);
   signal   state : state_type                           := IDLE_ST;

   -- x and y take on values in the range 0 to 1.7. So they are encoded as
   -- unsigned fixed point 1.C_SIZE-1.
   -- angle takes on values in the range -0.8 to 0.8. So that is encoded
   -- signed fixed point 1.C_SIZE-1.
   signal   arg_exp  : unsigned( 7 downto 0)             := (others => '0'); -- Exponent
   signal   arg_mant : unsigned(31 downto 0)             := (others => '0'); -- Mantissa

   signal   scale_sign : std_logic                       := '0';
   signal   scale_mant : fraction_type  := (others => '0');

   signal   scale2_mant : fraction_type := (others => '0');
   signal   scale2_shift  : integer range -32 to 32       := 0;

   signal   fraction_angle : fraction_type      := (others => '0');

   signal   x            : fraction_type := (others => '0');
   signal   y            : fraction_type := (others => '0');
   signal   count        : natural range 0 to C_ANGLE_NUM;
   signal   fraction2_quad  : unsigned(1 downto 0)                 := (others => '0');
   signal   angle : fraction_type        := (others => '0');

   signal   diff      : fraction_type;
   signal   x_rot     : fraction_type;
   signal   y_rot     : fraction_type;
   signal   do_sub    : std_logic;
   signal   new_angle : fraction_type      := (others => '0');
   signal   new_x     : fraction_type;
   signal   new_y     : fraction_type;

   signal   calc_leading_x : natural range 0 to fraction_type'length;
   signal   calc_leading_y : natural range 0 to fraction_type'length;

   pure function count_leading_zeros(arg : fraction_type) return natural is
   begin
      for i in arg'left downto arg'right loop
         if arg(i) /= '0' then
            return arg'left - i;
         end if;
      end loop;
      return arg'length;
   end function count_leading_zeros;

   pure function rotate (arg : fraction_type; ncount : integer) return
   unsigned is
      variable res_v : fraction_type;
   begin
      if ncount > 0 then
         -- rotate right
         res_v                               := (others => '0');
         res_v(C_SIZE - 1 - ncount downto 0) := arg(C_SIZE - 1 downto ncount);
      else
         -- rotate left
         res_v                             := (others => '0');
         res_v(C_SIZE - 1 downto - ncount) := arg(C_SIZE - 1 + ncount downto 0);
      end if;
      return res_v;
   end function rotate;

begin

   fast_sincos_rom_inst : entity work.fast_sincos_rom
      generic map (
         G_ANGLE_NUM => C_ANGLE_NUM
      )
      port map (
         addr_i => count mod C_ANGLE_NUM,
         data_o => diff
      );

   fast_sincos_rotate_x_inst : entity work.fast_sincos_rotate
      generic map (
         G_SIZE        => C_SIZE,
         G_SHIFT_RANGE => C_ANGLE_NUM
      )
      port map (
         in_i    => x,
         shift_i => count mod C_ANGLE_NUM,
         out_o   => x_rot
      );

   fast_sincos_rotate_y_inst : entity work.fast_sincos_rotate
      generic map (
         G_SIZE        => C_SIZE,
         G_SHIFT_RANGE => C_ANGLE_NUM
      )
      port map (
         in_i    => y,
         shift_i => count mod C_ANGLE_NUM,
         out_o   => y_rot
      );

   fast_sincos_addsub_x_inst : entity work.fast_sincos_addsub
      generic map (
         G_SIZE => C_SIZE
      )
      port map (
         a_i      => x,
         b_i      => y_rot,
         do_sub_i => do_sub,
         out_o    => new_x
      );

   fast_sincos_addsub_y_inst : entity work.fast_sincos_addsub
      generic map (
         G_SIZE => C_SIZE
      )
      port map (
         a_i      => y,
         b_i      => x_rot,
         do_sub_i => not do_sub,
         out_o    => new_y
      );

   fast_sincos_addsub_angle_inst : entity work.fast_sincos_addsub
      generic map (
         G_SIZE => C_SIZE
      )
      port map (
         a_i      => angle,
         b_i      => diff,
         do_sub_i => do_sub,
         out_o    => new_angle
      );

   do_sub <= not angle(angle'left);

   fsm_proc : process (clk_i)
      variable tmp_v : unsigned(C_SIZE + 31 downto 0);
   begin
      if rising_edge(clk_i) then
         case state is

            when IDLE_ST =>
               null;

            when SCALE_ST =>
               -- Store the sign
               scale_sign <= arg_mant(31);

               -- Take absolute value and multiply by 2/pi
               tmp_v      := (arg_mant or x"80000000") * C_TWO_OVER_PI;
               scale_mant <= tmp_v(C_SIZE + 31 downto 32);
               state      <= SCALE2_ST;

            when SCALE2_ST =>
               scale2_mant <= scale_mant; -- Pipeline the previous multiplier
               report "scale_mant = " & to_string(fraction2real(scale_mant), 11);
               scale2_shift  <= 0;
               if arg_exp > x"62" and arg_exp <= x"A3" then
                  scale2_shift <= 130 - to_integer(arg_exp);
               end if;

               state <= FRACTION_ST;

            when FRACTION_ST =>
               fraction_angle <= rotate(scale2_mant, scale2_shift);

               -- Prepare first iteration
               x     <= C_SCALE;
               y     <= (others => '0');
               state <= FRACTION2_ST;

            when FRACTION2_ST =>
               report "fraction_angle = " & to_string(fraction2real(fraction_angle), 11) & " * 2pi";
               fraction2_quad  <= fraction_angle(C_SIZE - 1 downto C_SIZE - 2);
               angle <= fraction_angle(C_SIZE - 3 downto 0) & "00";
               count <= 0;
               state <= CALC_ST;

            when CALC_ST =>
               report "count  = " & to_string(count);
               report "angle  = " & to_string(fraction2real(angle), 11) & " * pi/2";
               report "x      = " & to_string(fraction2real(x), 11);
               report "y      = " & to_string(fraction2real(y), 11);
               report "x_rot  = " & to_string(fraction2real(x_rot), 11);
               report "y_rot  = " & to_string(fraction2real(y_rot), 11);
               report "diff   = " & to_string(fraction2real(diff), 11);
               report "do_sub = " & to_string(do_sub);
               if count = C_ANGLE_NUM-1 or angle = 0 then
                  calc_leading_x <= count_leading_zeros(x);
                  calc_leading_y <= count_leading_zeros(y);
                  state          <= NORMALIZE_ST;
               else
                  angle <= new_angle;
                  x     <= unsigned(new_x);
                  y     <= unsigned(new_y);
                  count <= count + 1;
               end if;

            when NORMALIZE_ST =>
               report "calc_leading_x  = " & to_string(calc_leading_x);
               report "calc_leading_y  = " & to_string(calc_leading_y);
               cos_mant_o     <= rotate(x, -calc_leading_x)(C_SIZE-1 downto C_SIZE-32);
               sin_mant_o     <= rotate(y, -calc_leading_y)(C_SIZE-1 downto C_SIZE-32);
               cos_exp_o      <= x"80" - calc_leading_x;
               sin_exp_o      <= x"80" - calc_leading_y;
               ready_o        <= '1';
               cos_mant_o(31) <= scale_sign;
               sin_mant_o(31) <= scale_sign;
               state          <= IDLE_ST;

         end case;

         if start_i = '1' then
            report "arg_exp_i     = 0x" & to_hstring(arg_exp_i);
            report "arg_mant_i    = " & to_string(fraction2real((arg_mant_i or X"80000000") & "0000"), 11);
            report "C_SCALE       = " & to_string(fraction2real(C_SCALE), 11);
            report "C_TWO_OVER_PI = " & to_string(fraction2real(C_TWO_OVER_PI), 11);

            arg_exp  <= arg_exp_i;
            arg_mant <= arg_mant_i;
            ready_o  <= '0';
            state    <= SCALE_ST;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;

