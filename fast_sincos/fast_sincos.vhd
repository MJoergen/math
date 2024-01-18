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
   constant C_ANGLE_NUM  : natural                       := 3;

   -- This calculates the scaling used in the CORDIC algorithm

   pure function calc_scaling return fraction_type is
      variable res_v : real := 1.0;
   begin
      for i in 0 to C_ANGLE_NUM - 1 loop
         res_v := res_v * (1.0 + 1.0 / (4.0 ** i));
      end loop;

      return real2fraction(sqrt(res_v) / 2.0);
   end function calc_scaling;



   constant C_SCALE       : fraction_type                := calc_scaling;
   constant C_TWO_OVER_PI : fraction_type                := real2fraction(0.6366197723675814);

   type     state_type is (IDLE_ST, SCALE_ST, SCALE2_ST, FRACTION_ST, FRACTION2_ST, CALC_ST);
   signal   state : state_type                           := IDLE_ST;

   -- x and y take on values in the range 0 to 1.7. So they are encoded as
   -- unsigned fixed point 1.C_SIZE-1.
   -- angle takes on values in the range -0.8 to 0.8. So that is encoded
   -- signed fixed point 1.C_SIZE-1.
   signal   arg_exp  : unsigned( 7 downto 0)             := (others => '0'); -- Exponent
   signal   arg_mant : unsigned(31 downto 0)             := (others => '0'); -- Mantissa

   signal   sign       : std_logic                       := '0';
   signal   mant_scale : fraction_type  := (others => '0');

   signal   mant_scale_d : fraction_type := (others => '0');
   signal   angle_shift  : integer range -32 to 32       := 0;
   signal   x            : fraction_type := (others => '0');
   signal   y            : fraction_type := (others => '0');
   signal   count        : natural range 0 to C_ANGLE_NUM - 1;

   signal   angle2 : fraction_type      := (others => '0');

   signal   quad  : unsigned(1 downto 0)                 := (others => '0');
   signal   angle : fraction_type        := (others => '0');

   signal   diff      : fraction_type;
   signal   x_rot     : fraction_type;
   signal   y_rot     : fraction_type;
   signal   do_sub    : std_logic;
   signal   new_angle : fraction_type      := (others => '0');
   signal   new_x     : fraction_type;
   signal   new_y     : fraction_type;

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
         clk_i  => clk_i,
         addr_i => count,
         data_o => diff
      );

   fast_sincos_rotate_x_inst : entity work.fast_sincos_rotate
      generic map (
         G_SIZE        => C_SIZE,
         G_SHIFT_RANGE => C_ANGLE_NUM
      )
      port map (
         in_i    => x,
         shift_i => count,
         out_o   => x_rot
      );

   fast_sincos_rotate_y_inst : entity work.fast_sincos_rotate
      generic map (
         G_SIZE        => C_SIZE,
         G_SHIFT_RANGE => C_ANGLE_NUM
      )
      port map (
         in_i    => y,
         shift_i => count,
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

   do_sub <= '1' when angle >= 0 else
             '0';

   fsm_proc : process (clk_i)
      variable tmp_v : unsigned(C_SIZE + 31 downto 0);
   begin
      if rising_edge(clk_i) then
         case state is

            when IDLE_ST =>
               null;

            when SCALE_ST =>
               -- Store the sign
               sign       <= arg_mant(31);

               -- Take absolute value and multiply by 2/pi
               tmp_v      := (arg_mant or x"80000000") * C_TWO_OVER_PI;
               mant_scale <= tmp_v(C_SIZE + 31 downto 32);
               state      <= SCALE2_ST;

            when SCALE2_ST =>
               mant_scale_d <= mant_scale; -- Pipeline the previous multiplier
               report "mant_scale = " & to_string(fraction2real(mant_scale), 11);
               angle_shift  <= 0;
               if arg_exp > x"62" and arg_exp <= x"A3" then
                  angle_shift <= 130 - to_integer(arg_exp);
               end if;

               x     <= C_SCALE;
               y     <= (others => '0');
               count <= 0;
               state <= FRACTION_ST;

            when FRACTION_ST =>
               angle2 <= rotate(mant_scale_d, angle_shift);
               state  <= FRACTION2_ST;

            when FRACTION2_ST =>
               report "angle2 = " & to_string(4.0*fraction2real(angle2), 11);
               quad  <= angle2(C_SIZE - 1 downto C_SIZE - 2);
               angle <= angle2(C_SIZE - 3 downto 0) & "00";
               count <= count + 1;
               state <= CALC_ST;

            when CALC_ST =>
               if count = C_ANGLE_NUM - 1 or angle = 0 then
                  cos_mant_o     <= x(31 downto 0);
                  sin_mant_o     <= y(31 downto 0);
                  cos_exp_o      <= x"80";
                  sin_exp_o      <= x"80";
                  ready_o        <= '1';
                  cos_mant_o(31) <= sign;
                  sin_mant_o(31) <= sign;
                  state          <= IDLE_ST;
               else
                  angle <= new_angle;
                  x     <= unsigned(new_x);
                  y     <= unsigned(new_y);
                  count <= count + 1;
               end if;

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

