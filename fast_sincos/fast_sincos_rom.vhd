library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
   use work.fast_sincos_pkg.all;

entity fast_sincos_rom is
   generic (
      G_ANGLE_NUM : natural
   );
   port (
      addr_i : in  natural range 0 to G_ANGLE_NUM-1;
      data_o : out fraction_type
   );
end entity fast_sincos_rom;

architecture synthesis of fast_sincos_rom is

   type rom_type is array (0 to G_ANGLE_NUM-1) of fraction_type;

   pure function calc_angles return rom_type is
      variable res_v   : rom_type := (others => (others => '0'));
      variable angle_v : real;
   begin
      for i in 0 to G_ANGLE_NUM-1 loop
         angle_v  := arctan(0.5**i)/ (2.0*arctan(1.0)); -- In units of pi/2
         res_v(i) := real2fraction(angle_v);
         report "C_ANGLES(" & to_string(i) & ") = " & to_string(angle_v, 11) & " = 0x" & to_hstring(res_v(i));
      end loop;
      return res_v;
   end function calc_angles;

   signal C_ANGLES : rom_type := calc_angles;

begin

   data_o <= C_ANGLES(addr_i);

end architecture synthesis;

