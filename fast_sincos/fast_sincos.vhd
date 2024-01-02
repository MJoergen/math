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

   type state_type is (IDLE_ST, PREPARE_ST, CALC_ST);
   signal state : state_type := IDLE_ST;

   -- x and y take on values in the range 0 to 1.7. So they are encoded as
   -- unsigned fixed point 1.33.
   -- angle takes on values in the range -0.8 to 0.8. So that is encoded
   -- signed fixed point 1.33.
   signal x     : unsigned(33 downto 0);
   signal y     : unsigned(33 downto 0);
   signal angle :   signed(33 downto 0);
   signal diff  :   signed(33 downto 0);

   constant C_INIT_X : unsigned(33 downto 0) := "1" & X"00000000" & "0"; -- Real value 1.0
   constant C_INIT_Y : unsigned(33 downto 0) := "0" & X"00000000" & "0"; -- Real value 0.0

   constant C_ANGLE_NUM : natural := 3;

   type rom_type is array (0 to C_ANGLE_NUM-1) of signed(33 downto 0);

   pure function real2unsigned(arg : real) return unsigned is
      variable tmp : real;
      variable res : unsigned(33 downto 0);
   begin
      res(33 downto 29) := to_unsigned(integer(arg*(2.0**4)), 5);
      tmp := arg*(2.0**4) - real(integer(arg*(2.0**4)));
      res(28 downto 0) := to_unsigned(integer(tmp*(2.0**29)), 29);
      return res;
   end function real2unsigned;

   pure function real2signed(arg : real) return signed is
      variable tmp : real;
      variable res : signed(33 downto 0);
   begin
      res(33 downto 29) := to_signed(integer(arg*(2.0**4)), 5);
      tmp := arg*(2.0**4) - real(integer(arg*(2.0**4)));
      res(28 downto 0) := to_signed(integer(tmp*(2.0**29)), 29);
      return res;
   end function real2signed;

   pure function unsigned2real(arg : unsigned) return real is
   begin
      return (real(to_integer(arg(33 downto 29))) +
              real(to_integer(arg(28 downto 0))) / (2.0**29)) / (2.0**4);
   end function unsigned2real;

   pure function signed2real(arg : signed) return real is
   begin
      return (real(to_integer(arg(33 downto 29))) +
              real(to_integer(arg(28 downto 0))) / (2.0**29)) / (2.0**4);
   end function signed2real;

   pure function calc_angles return rom_type is
      variable res_v   : rom_type := (others => (others => '0'));
      variable angle_v : real;
   begin
      for i in 0 to C_ANGLE_NUM-1 loop
         angle_v  := 0.5*arctan(1.0 / (2.0**i))/arctan(1.0); -- In units of pi/2
         res_v(i) := real2signed(angle_v);
         report "C_ANGLES(" & to_string(i) & ") = " & to_hstring(res_v(i));
      end loop;
      return res_v;
   end function calc_angles;

   pure function calc_scaling return unsigned is
      variable res_v   : real := 1.0;
      variable angle_v : real;
   begin
      for i in 0 to C_ANGLE_NUM-1 loop
         res_v := res_v * sqrt(1.0 + 1.0 / (4.0**i));
      end loop;
      report "scaling = " & to_string(res_v);
      return real2unsigned(res_v/2.0);
   end function calc_scaling;

   constant C_ANGLES : rom_type := calc_angles;
   constant C_SCALE  : unsigned(33 downto 0) := calc_scaling;

   pure function rotate_right(arg : unsigned(33 downto 0); count : natural) return unsigned is
      variable res : unsigned(33 downto 0);
   begin
      res := (others => arg(33));
      res(33-count downto 0) := arg(33 downto count);
      if count > 0 then
         if arg(count-1) = '1' then
            res := res + 1;
         end if;
      end if;
      return res;
   end function rotate_right;

   pure function rotate_right(arg : signed(33 downto 0); count : natural) return signed is
      variable res : signed(33 downto 0);
   begin
      res := (others => arg(33));
      res(33-count downto 0) := arg(33 downto count);
      if count > 0 then
         if arg(count-1) = '1' then
            res := res + 1;
         end if;
      end if;
      return res;
   end function rotate_right;

   signal count : natural range 0 to C_ANGLE_NUM-1;

begin

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
               diff  <= C_ANGLES(0);
               state <= CALC_ST;

            when CALC_ST =>
               if count = C_ANGLE_NUM-1 then
                  cos_mant_o <= x(31 downto 0);
                  sin_mant_o <= y(31 downto 0);
                  ready_o    <= '1';
                  state      <= IDLE_ST;
               else
                  if angle > 0 then
                     angle <= angle - diff;
                     x     <= x - rotate_right(y, count);
                     y     <= y + rotate_right(x, count);
                  else
                     angle <= angle + diff;
                     x     <= x + rotate_right(y, count);
                     y     <= y - rotate_right(x, count);
                  end if;
                  count <= count + 1;
                  diff  <= C_ANGLES(count+1);
               end if;
         end case;

         if start_i = '1' then
            x       <= C_INIT_X; -- C_SCALE
            y       <= C_INIT_Y;
            angle <= (others => '0');
            angle(32) <= '1';
            if arg_exp_i > X"60" and arg_exp_i < X"80" then
               angle <= rotate_right(signed(arg_mant_i) & "00", to_integer(X"80" - arg_exp_i));
            end if;
            ready_o <= '0';
            state   <= PREPARE_ST;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;

