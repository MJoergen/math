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
-- We divide by (2pi) to get 13/12 = 1.08333333, which is encoded as 81:0AAAAAAA.

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
   constant C_ANGLE_NUM : natural         := 35;

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



   constant C_SCALE       : fraction_type := calc_scaling;
   constant C_TWO_OVER_PI : fraction_type := real2fraction(0.6366197723675814);

   type     state_type is (
      IDLE_ST, SCALE_ST, SCALE2_ST, CALC_ST, NORMALIZE_ST
   );
   signal   state : state_type            := IDLE_ST;

   -- x and y take on values in the range 0 to 1.7. So they are encoded as
   -- unsigned fixed point 1.C_SIZE-1.
   -- angle takes on values in the range -0.8 to 0.8. So that is encoded
   -- signed fixed point 1.C_SIZE-1.
   signal   arg_exp       : unsigned( 7 downto 0);           -- Exponent
   signal   arg_mant      : unsigned(31 downto 0);           -- Mantissa
   signal   arg_mant_prod : unsigned(C_SIZE + 32 downto 0);

   signal   arg_mant_prod_d : unsigned(C_SIZE + 32 downto 0);

   signal   scale_sign  : std_logic;
   signal   scale_shift : integer range -C_SIZE to C_SIZE;
   signal   scale_angle : fraction_type;

   signal   scale2_quad    : unsigned(1 downto 0);
   signal   scale2_reflect : std_logic;

   signal   x     : fraction_type;
   signal   y     : fraction_type;
   signal   count : natural range 0 to C_ANGLE_NUM;
   signal   angle : fraction_type;

   signal   diff      : fraction_type;
   signal   x_rot     : fraction_type;
   signal   y_rot     : fraction_type;
   signal   do_sub    : std_logic;
   signal   new_angle : fraction_type;
   signal   new_x     : fraction_type;
   signal   new_y     : fraction_type;

   signal   calc_leading_x : natural range 0 to fraction_type'length;
   signal   calc_leading_y : natural range 0 to fraction_type'length;

   pure function count_leading_zeros (arg : fraction_type) return natural is
   begin
      for i in arg'left downto arg'right loop
         if arg(i) /= '0' then
            return arg'left - i;
         end if;
      end loop;
      return arg'length;
   end function count_leading_zeros;

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

   type     rom_type is array (0 to C_ANGLE_NUM - 1) of fraction_type;

   pure function calc_angles return rom_type is
      variable res_v   : rom_type := (others => (others => '0'));
      variable angle_v : real;
   begin
      for i in 0 to C_ANGLE_NUM - 1 loop
         angle_v  := arctan(0.5 ** i) / (2.0 * arctan(1.0)); -- In units of pi/2
         res_v(i) := real2fraction(angle_v);
         report "C_ANGLES(" & to_string(i) & ") = " & to_string(angle_v, 11) & " = 0x" & to_hstring(res_v(i));
      end loop;
      return res_v;
   end function calc_angles;

   constant C_ANGLES : rom_type           := calc_angles;

begin

   -- This instantiates a DSP
   arg_mant_prod <= (arg_mant or x"80000000") * C_TWO_OVER_PI;

   diff          <= C_ANGLES(count);

   x_rot         <= rotate_unsigned(x, count);
   y_rot         <= rotate(y, count);

   do_sub        <= not angle(angle'left);
   new_x         <= x - y_rot when do_sub = '1' else
                    x + y_rot;
   new_y         <= y - x_rot when do_sub = '0' else
                    y + x_rot;
   new_angle     <= angle - diff when do_sub = '1' else
                    angle + diff;

   scale_angle   <= rotate(arg_mant_prod_d(C_SIZE + 32 downto 32), scale_shift);

   fsm_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- This adds a register to the DSP output
         arg_mant_prod_d <= arg_mant_prod;

         case state is

            when IDLE_ST =>
               null;

            when SCALE_ST =>
               -- Store the sign
               scale_sign  <= arg_mant(31);
               scale_shift <= C_SIZE;
               if arg_exp > x"62" and arg_exp <= x"A3" then
                  scale_shift <= 130 - to_integer(arg_exp);
               end if;

               -- Take absolute value and multiply by 2/pi
               state <= SCALE2_ST;

            when SCALE2_ST =>
               report "scale_angle = " & to_string(fraction2real(scale_angle), 11) & " * 2pi";

               -- Prepare first iteration
               x              <= C_SCALE;
               y              <= (others => '0');
               count          <= 0;

               scale2_quad    <= scale_angle(C_SIZE - 1 downto C_SIZE - 2);
               scale2_reflect <= scale_angle(C_SIZE - 3);

               case scale_angle(C_SIZE - 3) is

                  when '0' =>
                     angle <= "0" & scale_angle(C_SIZE - 3 downto 0) & "00";

                  when '1' =>
                     angle <= "0" & (not scale_angle(C_SIZE - 3 downto 0)) & "11";

                  when others =>
                     null;

               end case;

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
               if count = C_ANGLE_NUM - 1 then
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
               report "scale2_quad    = " & to_string(scale2_quad);
               report "scale2_reflect = " & to_string(scale2_reflect);
               report "calc_leading_x = " & to_string(calc_leading_x);
               report "calc_leading_y = " & to_string(calc_leading_y);

               case scale2_quad & scale2_reflect is

                  when "000" =>
                     cos_mant_o     <= rotate(x, -calc_leading_x)(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate(y, -calc_leading_y)(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= x"81" - calc_leading_x;
                     sin_exp_o      <= x"81" - calc_leading_y;
                     cos_mant_o(31) <= '0';
                     sin_mant_o(31) <= scale_sign;

                  when "001" =>
                     cos_mant_o     <= rotate(y, -calc_leading_y)(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate(x, -calc_leading_x)(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= x"81" - calc_leading_y;
                     sin_exp_o      <= x"81" - calc_leading_x;
                     cos_mant_o(31) <= '0';
                     sin_mant_o(31) <= scale_sign;

                  when "010" =>
                     cos_mant_o     <= rotate(y, -calc_leading_y)(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate(x, -calc_leading_x)(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= x"81" - calc_leading_y;
                     sin_exp_o      <= x"81" - calc_leading_x;
                     cos_mant_o(31) <= '1';
                     sin_mant_o(31) <= scale_sign;

                  when "011" =>
                     cos_mant_o     <= rotate(x, -calc_leading_x)(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate(y, -calc_leading_y)(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= x"81" - calc_leading_x;
                     sin_exp_o      <= x"81" - calc_leading_y;
                     cos_mant_o(31) <= '1';
                     sin_mant_o(31) <= scale_sign;

                  when "100" =>
                     cos_mant_o     <= rotate(x, -calc_leading_x)(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate(y, -calc_leading_y)(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= x"81" - calc_leading_x;
                     sin_exp_o      <= x"81" - calc_leading_y;
                     cos_mant_o(31) <= '1';
                     sin_mant_o(31) <= not scale_sign;

                  when "101" =>
                     cos_mant_o     <= rotate(y, -calc_leading_y)(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate(x, -calc_leading_x)(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= x"81" - calc_leading_y;
                     sin_exp_o      <= x"81" - calc_leading_x;
                     cos_mant_o(31) <= '1';
                     sin_mant_o(31) <= not scale_sign;

                  when "110" =>
                     cos_mant_o     <= rotate(y, -calc_leading_y)(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate(x, -calc_leading_x)(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= x"81" - calc_leading_y;
                     sin_exp_o      <= x"81" - calc_leading_x;
                     cos_mant_o(31) <= '0';
                     sin_mant_o(31) <= not scale_sign;

                  when "111" =>
                     cos_mant_o     <= rotate(x, -calc_leading_x)(C_SIZE downto C_SIZE - 31);
                     sin_mant_o     <= rotate(y, -calc_leading_y)(C_SIZE downto C_SIZE - 31);
                     cos_exp_o      <= x"81" - calc_leading_x;
                     sin_exp_o      <= x"81" - calc_leading_y;
                     cos_mant_o(31) <= '0';
                     sin_mant_o(31) <= not scale_sign;

                  when others =>
                     null;

               end case;

               ready_o <= '1';
               state   <= IDLE_ST;

         end case;

         if start_i = '1' then
            report "arg_exp_i     = 0x" & to_hstring(arg_exp_i);
            report "arg_mant_i    = " & to_string(fraction2real("0" & (arg_mant_i or x"80000000") & "0000"), 11);
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

