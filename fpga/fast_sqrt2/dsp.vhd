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

   mult_add_proc : process (all)
      variable res_v   : unsigned(2*G_SIZE-1 downto 0);
      variable tempc_v : unsigned(2*G_SIZE-1 downto 0);
   begin
      tempc_v                           := (others => '0');
      tempc_v(2*G_SIZE-1 downto G_SIZE) := c_i;
      res_v                             := a_i*b_i + tempc_v;
      res_o                             <= res_v(2*G_SIZE-1 downto G_SIZE);
   end process mult_add_proc;

end architecture synthesis;

