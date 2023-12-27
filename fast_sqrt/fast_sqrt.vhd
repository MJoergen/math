library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This module takes a normalized number val_i and returns the
-- square root as a normalized number res_o.
-- In this context normalized means MSB is '1' with a fixed point before the MSB.
--
-- Example:
-- The input 0x80000000 (representing the decimal value 0.5)
-- gives the output 0xB504F334 (representing the decimal value 0.707106781).
--
-- The algorithm is taken from
-- https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2).

entity fast_sqrt is
   port (
      clk_i   : in  std_logic;
      start_i : in  std_logic;
      val_i   : in  unsigned(31 downto 0);
      res_o   : out unsigned(31 downto 0);
      busy_o  : out std_logic
   );
end entity fast_sqrt;

architecture synthesis of fast_sqrt is

   type state_type is (IDLE_ST, CALC_ST);
   signal state : state_type := IDLE_ST;

   signal val : unsigned(31 downto 0);
   signal res : unsigned(31 downto 0);

begin

   busy_o <= '0' when state = IDLE_ST else '1';
   res_o  <= res;

   fsm_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then

         case state is
            when IDLE_ST =>
               -- Calculation is finished
               null;

            when CALC_ST =>
               state <= IDLE_ST;
         end case;

         if start_i = '1' then
            assert val_i(31) = '1'; -- Number must be normalized

            val    <= val_i;
            res    <= (others => '0');
            res(0) <= '1';
            state  <= CALC_ST;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;

