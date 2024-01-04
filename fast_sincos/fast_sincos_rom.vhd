library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity fast_sincos_rom is
   generic (
      G_ANGLE_NUM : natural
   );
   port (
      clk_i  : in  std_logic;
      addr_i : in  natural range 0 to G_ANGLE_NUM-1;
      data_o : out signed(33 downto 0)
   );
end entity fast_sincos_rom;

architecture synthesis of fast_sincos_rom is

   type rom_type is array (0 to G_ANGLE_NUM-1) of signed(33 downto 0);

   pure function real2signed(arg : real) return signed is
      variable tmp : real;
      variable res : signed(33 downto 0);
   begin
      res(33 downto 29) := to_signed(integer(arg*(2.0**4)), 5);
      tmp := arg*(2.0**4) - real(integer(arg*(2.0**4)));
      res(28 downto 0) := to_signed(integer(tmp*(2.0**29)), 29);
      return res;
   end function real2signed;

   pure function calc_angles return rom_type is
      variable res_v   : rom_type := (others => (others => '0'));
      variable angle_v : real;
   begin
      for i in 0 to G_ANGLE_NUM-1 loop
         angle_v  := 0.5*arctan(1.0 / (2.0**i))/arctan(1.0); -- In units of pi/2
         res_v(i) := real2signed(angle_v);
         report "C_ANGLES(" & to_string(i) & ") = " & to_hstring(res_v(i));
      end loop;
      return res_v;
   end function calc_angles;

   attribute ram_style : string;
   signal C_ANGLES : rom_type := calc_angles;
   attribute ram_style of C_ANGLES : signal is "distributed";

begin

   fsm_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         data_o <= C_ANGLES(addr_i);
      end if;
   end process fsm_proc;

end architecture synthesis;

