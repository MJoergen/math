library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fast_sincos_rotate is
   generic (
      G_SHIFT_RANGE : natural;
      G_SIZE        : natural
   );
   port (
      in_i       : in  unsigned(G_SIZE-1 downto 0);
      shift_i    : in  natural range 0 to G_SHIFT_RANGE-1;
      out_o      : out unsigned(G_SIZE-1 downto 0)
   );
end entity fast_sincos_rotate;

architecture synthesis of fast_sincos_rotate is

   pure function rotate_right(arg : unsigned(G_SIZE-1 downto 0); count : natural) return
   unsigned is
      variable res : unsigned(G_SIZE-1 downto 0);
   begin
      res := (others => arg(G_SIZE-1));
      res(G_SIZE-1-count downto 0) := arg(G_SIZE-1 downto count);
--      if count > 0 then
--         if arg(count-1) = '1' then
--            res := res + 1;
--         end if;
--      end if;
      return res;
   end function rotate_right;

begin

   out_o <= rotate_right(in_i, shift_i);

end architecture synthesis;

