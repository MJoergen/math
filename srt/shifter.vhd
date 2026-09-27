library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-- This is a combinatorial logical right shift: q_o = p_i >> exp_i.
-- It is used to undo the normalization of the quotient.

entity shifter is
   port (
      p_i   : in    std_logic_vector(67 downto 0); -- value to shift
      exp_i : in    natural range 0 to 67;         -- number of positions
      q_o   : out   std_logic_vector(67 downto 0)  -- shifted value
   );
end entity shifter;

architecture synthesis of shifter is

begin

   shifter_proc : process (all)
   begin
      q_o <= std_logic_vector(shift_right(unsigned(p_i), exp_i));
   end process shifter_proc;

end architecture synthesis;

