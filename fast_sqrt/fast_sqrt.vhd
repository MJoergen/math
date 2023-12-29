library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This module takes a normalized number val_i and returns the
-- square root as a normalized number res_o.
-- In this context normalized means MSB is '1' with a fixed point before the MSB.
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
-- https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2).

entity fast_sqrt is
   port (
      clk_i   : in  std_logic;
      start_i : in  std_logic;                -- Assert to restart calculation.
      ready_o : out std_logic;                -- Asserted when output is ready.
      error_o : out std_logic := '0';         -- Asserted when input is negative.
      exp_i   : in  unsigned( 7 downto 0);    -- Exponent
      mant_i  : in  unsigned(31 downto 0);    -- Mantissa
      exp_o   : out unsigned( 7 downto 0);    -- Exponent
      mant_o  : out unsigned(31 downto 0)     -- Mantissa
   );
end entity fast_sqrt;

architecture synthesis of fast_sqrt is

   type state_type is (IDLE_ST, CALC_ST);
   signal state : state_type := IDLE_ST;

   signal val  : unsigned(65 downto 0);
   signal mant : unsigned(65 downto 0);
   signal mask : unsigned(65 downto 0);

begin

   ready_o <= '1' when state = IDLE_ST else '0';
   mant_o(30 downto 0)  <= mant(31 downto 1) when mant(0) = '0' else
             (mant(31 downto 1) + 1);
   mant_o(31) <= '0';
   exp_o <= ("0" & exp_i(7 downto 1)) + X"40" when exp_i(0) = '0' else
            ("0" & exp_i(7 downto 1)) + X"41";

   fsm_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then

         case state is
            when IDLE_ST =>
               -- Calculation is finished
               null;

            when CALC_ST =>
               if val >= (mant or mask) then
                  val <= val - (mant or mask);
                  mant <= ("0" & mant(65 downto 1)) or mask;
               else
                  mant <= ("0" & mant(65 downto 1));
               end if;
               mask   <= "00" & mask(65 downto 2);

               if mask(0) = '1' then
                  state <= IDLE_ST;
               end if;
         end case;

         if start_i = '1' then
            error_o <= '0';   -- Clear any previous errors.
            if mant_i(31) = '1' then
               error_o <= '1';   -- Error if number is negative.
            else
               if exp_i(0) = '0' then
                  val(65 downto 34) <= mant_i or X"80000000";
                  val(33 downto  0) <= (others => '0');
               else
                  val(65)           <= '0';
                  val(64 downto 33) <= mant_i or X"80000000";
                  val(32 downto  0) <= (others => '0');
               end if;
               mant     <= (others => '0');
               mask     <= (others => '0');
               mask(64) <= '1';
               state    <= CALC_ST;
            end if;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;

