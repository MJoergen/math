library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fast_sincos_rotate is
   generic (
      G_ANGLE_NUM : natural
   );
   port (
      in_i       : in  unsigned(33 downto 0);
      shift_i    : in  natural range 0 to G_ANGLE_NUM-1;
      out_o      : out unsigned(33 downto 0)
   );
end entity fast_sincos_rotate;

architecture synthesis of fast_sincos_rotate is

   pure function rotate_right(arg : unsigned(33 downto 0); count : natural) return
   unsigned is
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

begin

   out_o <= rotate_right(in_i, shift_i);

end architecture synthesis;

