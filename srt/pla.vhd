library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- This is the quotient digit selection table of the SRT divider, corresponding
-- to the PLA in the Pentium processor.
--
-- The table is indexed by only 11 bits, just like in the Pentium:
-- * The top 7 bits of the partial remainder n (sign, 3 integer bits, and
--   3 fractional bits). So n is truncated to a multiple of 1/8.
-- * The 4 bits of the divisor d just after the leading "0001". So d is
--   truncated to a multiple of 1/16.
-- The table therefore has 2^11 = 2048 entries. Each entry stores |q|, and the
-- sign of q is taken from the sign of n.
--
-- The input format is the same as in div.vhd: two's complement with 4 integer
-- bits including the sign, and d must be normalized (1 <= d < 2).
--
-- This is a purely combinatorial block.

entity pla is
   generic (
      G_SIZE  : natural;
      G_DEBUG : boolean
   );
   port (
      n_i : in    std_logic_vector(G_SIZE-1 downto 0); -- dividend
      d_i : in    std_logic_vector(G_SIZE-1 downto 0); -- divisor
      q_o : out   integer range -2 to 2
   );
end entity pla;

architecture synthesis of pla is

   -- Select the quotient digit by rounding n/d to the nearest integer, i.e.
   --   |n| <  d/2        => |q| = 0
   --   |n| <= d + d/2    => |q| = 1
   --   otherwise         => |q| = 2
   -- This is only used when generating the table, so it can afford to use
   -- full comparators.
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

   type   rom_type is array (natural range <>) of std_logic_vector(1 downto 0);

   -- Build the table by evaluating get_q for each entry. The index is
   -- n(7 bits) & d(4 bits). Here n and d are reconstructed as 8-bit values in
   -- the same format as the inputs (4 integer bits and 4 fractional bits).
   pure function init_rom return rom_type is
      variable rom_v : rom_type(0 to 2047) := (others => (others => '0'));
      variable n_v   : std_logic_vector(7 downto 0);
      variable d_v   : std_logic_vector(7 downto 0);
   begin
      --
      for i in 0 to 2047 loop
         n_v      := to_stdlogicvector(i / 16, 7) & "0";
         d_v      := "0001" & to_stdlogicvector(i mod 16, 4);
         rom_v(i) := to_stdlogicvector(abs(get_q(n_v, d_v)), 2);
      end loop;

      return rom_v;
   end function init_rom;

   -- Note: Vivado does not implement this table using LUTRAM, even when
   -- instructed to do so with the "ram_style" attribute.
   constant pla_rom : rom_type(0 to 2047)        := init_rom;

   signal pla_addr : std_logic_vector(10 downto 0);
   signal pla_data : std_logic_vector(1 downto 0);

begin

   -- Extract the table index from the top bits of n and d
   pla_addr_proc : process (all)
      variable n_v   : natural range 0 to 2 ** 7 - 1;
      variable d_v   : natural range 0 to 2 ** 4 - 1;
      variable idx_v : natural range 0 to 2047;
   begin
      n_v      := to_integer(n_i(G_SIZE-1 downto G_SIZE-7));
      d_v      := to_integer(d_i(G_SIZE-5 downto G_SIZE-8));
      idx_v    := n_v * 16 + d_v;
      pla_addr <= to_stdlogicvector(idx_v, 11);

      if G_DEBUG then
         report "n_v=" & to_string(n_v) &
                ", d_v=" & to_string(d_v) &
                " => idx_v=" & to_string(to_stdlogicvector(idx_v, 11));
      end if;
   end process pla_addr_proc;

   rom_proc : process (all)
   begin
      pla_data <= pla_rom(to_integer(pla_addr));
   end process rom_proc;

   -- Apply the sign of n to the quotient digit
   q_v_proc : process (all)
      variable q_v : integer;
   begin
      q_v := to_integer(pla_data);
      if n_i(G_SIZE-1) = '1' then
         q_v := -q_v;
      end if;

      if G_DEBUG then
         report "q_v=" & to_string(q_v);
      end if;
      q_o <= q_v;
   end process q_v_proc;

end architecture synthesis;

