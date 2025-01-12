library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

entity normalizer is
   port (
      n_i   : in    std_logic_vector(31 downto 0); -- dividend
      d_i   : in    std_logic_vector(31 downto 0); -- divisor
      n_o   : out   std_logic_vector(31 downto 0); -- dividend
      d_o   : out   std_logic_vector(31 downto 0); -- divisor
      exp_o : out   integer range -31 to 32
   );
end entity normalizer;

architecture synthesis of normalizer is

   pure function count_leading_zeros (
      arg : std_logic_vector(31 downto 0)
   ) return natural is
   begin
      --
      for i in 0 to 31 loop
         if arg(31 - i) = '1' then
            return i;
         end if;
      end loop;

      return 32;
   end function count_leading_zeros;

begin

   norm_proc : process (all)
      variable nz_v : natural range 0 to 32;
      variable dz_v : natural range 0 to 31;
   begin
      nz_v                := count_leading_zeros(n_i) - 3;
      dz_v                := count_leading_zeros(d_i) - 3;
      exp_o               <= nz_v - dz_v;
      n_o                 <= (others => '0');
      d_o                 <= (others => '0');
      n_o(31 downto nz_v) <= n_i(31 - nz_v downto 0);
      d_o(31 downto dz_v) <= d_i(31 - dz_v downto 0);
   end process norm_proc;

end architecture synthesis;

