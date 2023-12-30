library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This calculates combinatorially: res = a*b+c
-- This will likely be mapped to DSPs.
-- Any pipeline registers must be added outside this entity.

entity dsp is
   generic (
      G_SIZE : natural
   );
   port (
      a_i   : in  unsigned(G_SIZE-1 downto 0);
      b_i   : in  unsigned(G_SIZE-1 downto 0);
      c_i   : in  unsigned(G_SIZE-1 downto 0);
      res_o : out unsigned(G_SIZE-1 downto 0)
   );
end entity dsp;

architecture synthesis of dsp is

begin

   process (all)
      variable res   : unsigned(2*G_SIZE-1 downto 0);
      variable tempc : unsigned(2*G_SIZE-1 downto 0);
   begin
      tempc := (others => '0');
      tempc(2*G_SIZE-1 downto G_SIZE) := c_i;
      res := a_i*b_i + tempc;
      res_o <= res(2*G_SIZE-1 downto G_SIZE);
   end process;

end architecture synthesis;

