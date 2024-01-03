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

entity fast_sincos is
   port (
      clk_i      : in  std_logic;
      start_i    : in  std_logic;                -- Assert to restart calculation.
      ready_o    : out std_logic := '1';         -- Asserted when output is ready.
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


   constant C_INIT_X    : unsigned(33 downto 0) := "1" & X"00000000" & "0"; -- Real value 1.0
   constant C_INIT_Y    : unsigned(33 downto 0) := "0" & X"00000000" & "0"; -- Real value 0.0
   constant C_ANGLE_NUM : natural := 3;
   constant C_SCALE     : unsigned(33 downto 0) := calc_scaling(C_ANGLE_NUM);

   type state_type is (IDLE_ST, PREPARE_ST, CALC_ST);
   signal state : state_type := IDLE_ST;

   -- x and y take on values in the range 0 to 1.7. So they are encoded as
   -- unsigned fixed point 1.33.
   -- angle takes on values in the range -0.8 to 0.8. So that is encoded
   -- signed fixed point 1.33.
   signal x         : unsigned(33 downto 0);
   signal y         : unsigned(33 downto 0);
   signal angle     :   signed(33 downto 0);
   signal count     : natural range 0 to C_ANGLE_NUM-1;
   signal diff      :   signed(33 downto 0);
   signal x_rot     : unsigned(33 downto 0);
   signal y_rot     : unsigned(33 downto 0);
   signal mant_rot  : unsigned(33 downto 0);
   signal do_sub    : std_logic;
   signal new_angle :   signed(33 downto 0);
   signal new_x     :   signed(33 downto 0);
   signal new_y     :   signed(33 downto 0);

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
         in_i    => arg_mant_i & "00",
         shift_i => to_integer(X"80" - arg_exp_i),
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
   begin
      if rising_edge(clk_i) then
         report "x=" & to_string(unsigned2real(x)) &
              ", y=" & to_string(unsigned2real(y));

         case state is
            when IDLE_ST =>
               null;

            when PREPARE_ST =>
               count <= 0;
               state <= CALC_ST;

            when CALC_ST =>
               if count = C_ANGLE_NUM-1 then
                  cos_mant_o <= x(31 downto 0);
                  sin_mant_o <= y(31 downto 0);
                  ready_o    <= '1';
                  state      <= IDLE_ST;
               else
                  angle <= new_angle;
                  x     <= unsigned(new_x);
                  y     <= unsigned(new_y);
                  count <= count + 1;
               end if;
         end case;

         if start_i = '1' then
            x       <= C_INIT_X; -- C_SCALE
            y       <= C_INIT_Y;
            angle <= (others => '0');
            angle(32) <= '1';
            if arg_exp_i > X"60" and arg_exp_i < X"80" then
               angle <= signed(mant_rot);
            end if;
            ready_o <= '0';
            state   <= PREPARE_ST;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;

