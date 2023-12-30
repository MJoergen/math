library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- This module takes a floating point number (exp_i, mant_i) and returns the
-- square root as a floating point number (exp_o, mant_o).
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
-- The algorithm is taken from
-- https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Goldschmidt%E2%80%99s_algorithm
-- A second form, using fused multiply-add operations, begins
-- y0 := approximation of 1/sqrt(s)
-- x0 := s*y0
-- h0 := y0/2
-- and iterates
-- rn := 0.5-xn*hn
-- x_(n+1) := xn + xn*rn
-- h_(n+1) := hn + hn*rn
-- until rn is sufficiently close to 0.
-- This converges to:
-- xn -> sqrt(s)
-- hn -> 0.5/sqrt(s)

entity fast_sqrt2 is
   port (
      clk_i   : in  std_logic;
      start_i : in  std_logic;                -- Assert to restart calculation.
      ready_o : out std_logic := '1';         -- Asserted when output is ready.
      error_o : out std_logic := '0';         -- Asserted when input is negative.
      exp_i   : in  unsigned( 7 downto 0);    -- Exponent
      mant_i  : in  unsigned(31 downto 0);    -- Mantissa
      exp_o   : out unsigned( 7 downto 0);    -- Exponent
      mant_o  : out unsigned(31 downto 0)     -- Mantissa
   );
end entity fast_sqrt2;

architecture synthesis of fast_sqrt2 is

   type float_type is record
      exp  : unsigned( 7 downto 0);
      mant : unsigned(31 downto 0);
   end record float_type;

   constant C_ROM_SIZE : natural := 8;
   constant C_GUARDS   : natural := 8;

   -- Input is interpreted as a real value between 0.25 and 1.0
   -- Output is 0.5/sqrt(input) and is interpreted as a real value
   -- between 0.5 and 1.0.
   pure function inv_sqrt(arg : unsigned(C_ROM_SIZE-1 downto 0)) return unsigned is
      variable arg_real : real;
      variable res_real : real;
      variable res      : unsigned(C_ROM_SIZE-1 downto 0);
   begin
      assert arg(C_ROM_SIZE-1 downto C_ROM_SIZE-2) /= "00";
      arg_real := real(to_integer(arg)+1)/(2.0 ** C_ROM_SIZE);
      res_real := 0.5/sqrt(arg_real);
      if res_real = 1.0 then
         res := (others => '1');
      else
         res := to_unsigned(integer(floor(res_real*(2.0 ** C_ROM_SIZE))), C_ROM_SIZE);
      end if;
      return res;
   end function inv_sqrt;

   signal x : unsigned(31+C_GUARDS downto 0);
   signal y : unsigned(31+C_GUARDS downto 0);
   signal h : unsigned(31+C_GUARDS downto 0);
   signal r : unsigned(31+C_GUARDS downto 0);

   type state_type is (IDLE_ST, INIT_ST, CALC_R_ST, CALC_XH_ST);
   signal state : state_type := IDLE_ST;

   type rom_type is array (natural range 0 to 2**C_ROM_SIZE-1) of unsigned(C_ROM_SIZE-1 downto 0);

   pure function init_inv_sqrt return rom_type is
      variable res : rom_type := (others => (others => '0'));
   begin
      for i in 2**C_ROM_SIZE/4 to 2**C_ROM_SIZE-1 loop
         res(i) := inv_sqrt(to_unsigned(i, C_ROM_SIZE));
         report "res(" & to_string(i) & ")=" & to_hstring(res(i));
      end loop;
      return res;
   end function init_inv_sqrt;

   constant C_INV_SQRT : rom_type := init_inv_sqrt;

   signal mant     : unsigned(31+C_GUARDS downto 0);
   signal dsp_r    : unsigned(31+C_GUARDS downto 0);
   signal dsp_x    : unsigned(31+C_GUARDS downto 0);
   signal dsp_h    : unsigned(31+C_GUARDS downto 0);
   signal dsp_init : unsigned(31+C_GUARDS downto 0);

   constant C_ZERO : unsigned(31+C_GUARDS downto 0) := (others =>'0');
   constant C_HALF : unsigned(31+C_GUARDS downto 0) := (31+C_GUARDS => '1', others =>'0');

begin

   dsp_init_inst : entity work.dsp
      generic map (
         G_SIZE => 32+C_GUARDS
      )
      port map (
         a_i   => mant,
         b_i   => y,
         c_i   => C_ZERO,
         res_o => dsp_init
      );

   dsp_r_inst : entity work.dsp
      generic map (
         G_SIZE => 32+C_GUARDS
      )
      port map (
         a_i   => x,
         b_i   => h,
         c_i   => C_HALF,
         res_o => dsp_r
      );

   dsp_x_inst : entity work.dsp
      generic map (
         G_SIZE => 32+C_GUARDS
      )
      port map (
         a_i   => x,
         b_i   => r,
         c_i   => x,
         res_o => dsp_x
      );

   dsp_h_inst : entity work.dsp
      generic map (
         G_SIZE => 32+C_GUARDS
      )
      port map (
         a_i   => h,
         b_i   => r,
         c_i   => h,
         res_o => dsp_h
      );

   sqrt_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case state is
            when IDLE_ST =>
               null;

            when INIT_ST =>
               x <= dsp_init(30+C_GUARDS downto 0) & "0";
               h <= y;
               state <= CALC_R_ST;

            when CALC_R_ST =>
               r <= 0-dsp_r;
               state <= CALC_XH_ST;

            when CALC_XH_ST =>
               x <= dsp_x;
               h <= dsp_h;
               state <= CALC_R_ST;
               if r(31+C_GUARDS downto (32+C_GUARDS)/2) = 0 then
                  if dsp_x(C_GUARDS-1) = '0' then
                     mant_o <= unsigned(dsp_x(31+C_GUARDS downto C_GUARDS));
                  else
                     mant_o <= unsigned(dsp_x(31+C_GUARDS downto C_GUARDS)) + 1;
                  end if;
                  if exp_i(0) = '0' then
                     exp_o <= ("0" & exp_i(7 downto 1)) + X"40";
                  else
                     exp_o <= ("0" & exp_i(7 downto 1)) + X"41";
                  end if;
                  ready_o <= '1';
                  mant_o(31) <= '0';
                  state  <= IDLE_ST;
               end if;
         end case;

         if start_i = '1' then
            error_o <= '0';
            if mant_i(31) = '1' then
               error_o <= '1';
            else
               y <= (others => '0');
               if exp_i(0) = '0' then
                  mant <= (others => '0');
                  mant(31+C_GUARDS downto C_GUARDS) <= mant_i or X"80000000";
                  y(31+C_GUARDS downto 32+C_GUARDS-C_ROM_SIZE) <= C_INV_SQRT(to_integer("1" & mant_i(30 downto 32-C_ROM_SIZE)));
               else
                  mant <= (others => '0');
                  mant(30+C_GUARDS downto C_GUARDS-1) <= mant_i or X"80000000";
                  y(31+C_GUARDS downto 32+C_GUARDS-C_ROM_SIZE) <= C_INV_SQRT(to_integer("01" & mant_i(30 downto 33-C_ROM_SIZE)));
               end if;
               if exp_i = X"00" then
                  exp_o <= X"00";
               else
                  state <= INIT_ST;
                  ready_o <= '0';
               end if;
            end if;
         end if;
      end if;
   end process sqrt_proc;

end architecture synthesis;

