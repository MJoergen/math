library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

entity pla is
   generic (
      G_DEBUG : boolean
   );
   port (
      n_i : in    std_logic_vector(31 downto 0); -- dividend
      d_i : in    std_logic_vector(31 downto 0); -- divisor
      q_o : out   integer range -2 to 2
   );
end entity pla;

architecture synthesis of pla is

   pure function get_q (
      arg_n : std_logic_vector;
      arg_d : std_logic_vector
   ) return integer is
      variable neg_n_v  : std_logic_vector(arg_n'range);
      variable half_d_v : std_logic_vector(arg_d'range);
      variable res_v    : integer range -2 to 2;
   begin
      assert arg_d(arg_d'left downto arg_d'left-3) = "0001";

      half_d_v := "0" & arg_d(arg_d'left downto 1);
      neg_n_v  := (not arg_n) + 1;

      if arg_n(arg_n'left) = '0' then
         if arg_n < half_d_v then
            res_v := 0;
         elsif arg_n <= arg_d + half_d_v then
            res_v := 1;
         else
            res_v := 2;
         end if;
      else
         if neg_n_v < half_d_v then
            res_v := 0;
         elsif neg_n_v <= arg_d + half_d_v then
            res_v := -1;
         else
            res_v := -2;
         end if;
      end if;

      return res_v;
   end function get_q;

   type   ram_type is array (natural range <>) of std_logic_vector(1 downto 0);

   pure function init_ram return ram_type is
      variable ram_v : ram_type(0 to 2047) := (others => (others => '0'));
      variable n_v   : std_logic_vector(7 downto 0);
      variable d_v   : std_logic_vector(7 downto 0);
   begin
      --
      for i in 0 to 2047 loop
         n_v      := to_stdlogicvector(i / 16, 7) & "0";
         d_v      := "0001" & to_stdlogicvector(i mod 16, 4);
         ram_v(i) := to_stdlogicvector(abs(get_q(n_v, d_v)), 2);
      end loop;

      return ram_v;
   end function init_ram;

   signal pla_ram : ram_type(0 to 2047)        := init_ram;
   -- Vivado will not implement this using LUTRAM,
   -- despite being instructed to do so.
   -- attribute ram_style : string;
   -- attribute ram_style of pla_ram : signal is "distributed";

   signal pla_addr : std_logic_vector(10 downto 0);
   signal pla_data : std_logic_vector(1 downto 0);

begin

   pla_addr_proc : process (all)
      variable n_v   : natural range 0 to 2 ** 7 - 1;
      variable d_v   : natural range 0 to 2 ** 4 - 1;
      variable idx_v : natural range 0 to 2047;
   begin
      n_v      := to_integer(n_i(31 downto 25));
      d_v      := to_integer(d_i(27 downto 24));
      idx_v    := n_v * 16 + d_v;
      pla_addr <= to_stdlogicvector(idx_v, 11);

      if G_DEBUG then
         report "n_v=" & to_string(n_v) &
                ", d_v=" & to_string(d_v) &
                " => idx_v=" & to_string(to_stdlogicvector(idx_v, 11));
      end if;
   end process pla_addr_proc;

   ram_proc : process (all)
   begin
      pla_data <= pla_ram(to_integer(pla_addr));
   end process ram_proc;

   q_v_proc : process (all)
      variable q_v : integer;
   begin
      q_v := to_integer(pla_data);
      if n_i(31) = '1' then
         q_v := -q_v;
      end if;

      if G_DEBUG then
         report "q_v=" & to_string(q_v);
      end if;
      q_o <= q_v;
   end process q_v_proc;

end architecture synthesis;

