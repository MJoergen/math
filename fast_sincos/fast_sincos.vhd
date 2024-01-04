library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

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

entity fast_sincos is
   port (
      clk_i      : in  std_logic;
      ready_o    : out std_logic := '1';         -- Asserted when output is ready.
      start_i    : in  std_logic;                -- Assert to restart calculation.
      arg_exp_i  : in  unsigned( 7 downto 0);    -- Exponent
      arg_mant_i : in  unsigned(31 downto 0);    -- Mantissa
      sin_exp_o  : out unsigned( 7 downto 0);    -- Exponent
      sin_mant_o : out unsigned(31 downto 0);    -- Mantissa
      cos_exp_o  : out unsigned( 7 downto 0);    -- Exponent
      cos_mant_o : out unsigned(31 downto 0)     -- Mantissa
   );
end entity fast_sincos;

architecture synthesis of fast_sincos is

   pure function real2unsigned(arg : real) return unsigned is
      variable tmp : real;
      variable res : unsigned(33 downto 0);
   begin
      res(33 downto 29) := to_unsigned(integer(arg*(2.0**4)), 5);
      tmp := arg*(2.0**4) - real(integer(arg*(2.0**4)));
      res(28 downto 0) := to_unsigned(integer(tmp*(2.0**29)), 29);
      return res;
   end function real2unsigned;

   pure function unsigned2real(arg : unsigned) return real is
   begin
      return (real(to_integer(arg(33 downto 29))) +
              real(to_integer(arg(28 downto 0))) / (2.0**29)) / (2.0**4);
   end function unsigned2real;

   pure function calc_scaling(count : natural) return unsigned is
      variable res_v   : real := 1.0;
      variable angle_v : real;
   begin
      for i in 0 to count-1 loop
         res_v := res_v * sqrt(1.0 + 1.0 / (4.0**i));
      end loop;
--      report "scaling = " & to_string(res_v);
      return real2unsigned(res_v/2.0);
   end function calc_scaling;


   constant C_ANGLE_NUM   : natural := 5;
   constant C_SCALE       : unsigned(33 downto 0) := calc_scaling(C_ANGLE_NUM);
   constant C_TWO_OVER_PI : unsigned(33 downto 0) := real2unsigned(0.6366197723675814);

   type state_type is (IDLE_ST, PREPARE_ST, PREPARE2_ST, CALC_ST);
   signal state : state_type := IDLE_ST;

   -- x and y take on values in the range 0 to 1.7. So they are encoded as
   -- unsigned fixed point 1.33.
   -- angle takes on values in the range -0.8 to 0.8. So that is encoded
   -- signed fixed point 1.33.
   signal start       : std_logic;                -- Assert to restart calculation.
   signal arg_exp     : unsigned( 7 downto 0);    -- Exponent
   signal arg_mant    : unsigned(31 downto 0);    -- Mantissa
   signal sign        : std_logic;
   signal x           : unsigned(33 downto 0) := (others => '0');
   signal y           : unsigned(33 downto 0) := (others => '0');
   signal angle       :   signed(33 downto 0);
   signal angle_d     :   signed(33 downto 0);
   signal count       : natural range 0 to C_ANGLE_NUM-1;
   signal diff        :   signed(33 downto 0);
   signal x_rot       : unsigned(33 downto 0);
   signal y_rot       : unsigned(33 downto 0);
   signal mant_rot    : unsigned(33 downto 0);
   signal do_sub      : std_logic;
   signal new_angle   :   signed(33 downto 0);
   signal new_x       :   signed(33 downto 0);
   signal new_y       :   signed(33 downto 0);
   signal angle_shift : natural range 0 to C_ANGLE_NUM-1;

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
         G_ANGLE_NUM => C_ANGLE_NUM
      )
      port map (
         in_i    => x,
         shift_i => count,
         out_o   => x_rot
      );

   fast_sincos_rotate_y_inst : entity work.fast_sincos_rotate
      generic map (
         G_ANGLE_NUM => C_ANGLE_NUM
      )
      port map (
         in_i    => y,
         shift_i => count,
         out_o   => y_rot
      );

   fast_sincos_rotate_angle_inst : entity work.fast_sincos_rotate
      generic map (
         G_ANGLE_NUM => 33
      )
      port map (
         in_i    => unsigned(angle),
         shift_i => angle_shift,
         out_o   => mant_rot
      );

   fast_sincos_addsub_x_inst : entity work.fast_sincos_addsub
      port map (
         a_i      => signed(x),
         b_i      => signed(y_rot),
         do_sub_i => do_sub,
         out_o    => new_x
      );

   fast_sincos_addsub_y_inst : entity work.fast_sincos_addsub
      port map (
         a_i      => signed(y),
         b_i      => signed(x_rot),
         do_sub_i => not do_sub,
         out_o    => new_y
      );

   fast_sincos_addsub_angle_inst : entity work.fast_sincos_addsub
      port map (
         a_i      => signed(angle),
         b_i      => signed(diff),
         do_sub_i => do_sub,
         out_o    => new_angle
      );

   do_sub <= '1' when angle >= 0 else '0';

   fsm_proc : process (clk_i)
      variable tmp : unsigned(65 downto 0);
   begin
      if rising_edge(clk_i) then
         start    <= start_i;
         if start_i = '1' then
            arg_exp  <= arg_exp_i;
            arg_mant <= arg_mant_i;
            ready_o  <= '0';
         end if;

         report "x=" & to_string(unsigned2real(x)) &
              ", y=" & to_string(unsigned2real(y));

         case state is
            when IDLE_ST =>
               null;

            when PREPARE_ST =>
               angle <= angle_d;
               angle_shift <= to_integer(X"80" - arg_exp);
               state <= PREPARE2_ST;

            when PREPARE2_ST =>
               angle <= signed(mant_rot);
               count <= count + 1;
               state <= CALC_ST;

            when CALC_ST =>
               if count = C_ANGLE_NUM-1 or angle = 0 then
                  cos_mant_o <= x(31 downto 0);
                  sin_mant_o <= y(31 downto 0);
                  cos_exp_o  <= X"80";
                  sin_exp_o  <= X"80";
                  ready_o    <= '1';
                  state      <= IDLE_ST;
               else
                  angle <= new_angle;
                  x     <= unsigned(new_x);
                  y     <= unsigned(new_y);
                  count <= count + 1;
               end if;
         end case;

         if start = '1' then
            -- Step 1: Store the sign
            sign  <= arg_mant(31);

            -- Step 2: Take absolute value and multiply by 2/pi
            tmp := (arg_mant or X"80000000") * C_TWO_OVER_PI;
            angle_d <= signed(tmp(65 downto 32));
            x       <= C_SCALE;
            y       <= (others => '0');
            count   <= 0;
            state   <= PREPARE_ST;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;

