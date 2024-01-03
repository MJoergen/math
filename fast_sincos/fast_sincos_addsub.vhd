library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fast_sincos_addsub is
   port (
      a_i      : in  signed(33 downto 0);
      b_i      : in  signed(33 downto 0);
      do_sub_i : in  std_logic;
      out_o    : out signed(33 downto 0)
   );
end entity fast_sincos_addsub;

architecture synthesis of fast_sincos_addsub is

begin

   out_o <= a_i - b_i when do_sub_i = '1' else a_i + b_i;

end architecture synthesis;

