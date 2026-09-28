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
-- div.vhd keeps the partial remainder in carry-save form (a sum and a carry),
-- like the Pentium. Only the top 7 bits of the sum and the carry are added
-- for the table lookup, so the table may see n one row too low. So each entry
-- must hold a digit that is valid not just for its own row of n, but also for
-- the row above. The digit is therefore selected by rounding n/d to the
-- nearest integer at the centre of this region, i.e. at the centre of two
-- rows of n and one column of d. See get_q, and ALGORITHM.md. The table also
-- works if n is calculated exactly.
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

   -- Select |q| for the table entry with the top 7 bits n7 of n (as a signed
   -- integer, i.e. n7/8 <= n < (n7+1)/8) and the 4 bits d4 of d after the
   -- leading one (i.e. 1 + d4/16 <= d < 1 + (d4+1)/16). This rounds n/d to the
   -- nearest integer at the centre of the region the entry must cover:
   --   n = n7/8 + 1/8     (the centre of this row and the row above)
   --   d = 1 + d4/16 + 1/32
   -- In units of 1/32 these are the integers n_v and d_v below. Since 2*|n_v|
   -- is even and d_v is odd, n/d is never exactly halfway between two digits.
   --   |n| < d/2         => |q| = 0
   --   |n| < d + d/2     => |q| = 1
   --   otherwise         => |q| = 2
   -- The sign of q is the sign of n, see q_v_proc.
   pure function get_q (
      n7 : integer range -64 to 63;
      d4 : natural range 0 to 15
   ) return natural is
      variable n_v : integer;
      variable d_v : natural;
   begin
      n_v := 4 * n7 + 4;
      d_v := 33 + 2 * d4;

      if 2 * abs(n_v) < d_v then
         return 0;
      elsif 2 * abs(n_v) < 3 * d_v then
         return 1;
      else
         return 2;
      end if;
   end function get_q;

   type   rom_type is array (natural range <>) of std_logic_vector(1 downto 0);

   -- Build the table by evaluating get_q for each entry. The index is
   -- n(7 bits) & d(4 bits).
   pure function init_rom return rom_type is
      variable rom_v : rom_type(0 to 2047) := (others => (others => '0'));
      variable n7_v  : integer range -64 to 127;
   begin
      --
      for i in 0 to 2047 loop
         n7_v := i / 16;
         if n7_v >= 64 then
            n7_v := n7_v - 128;                           -- Negative n
         end if;
         rom_v(i) := to_stdlogicvector(get_q(n7_v, i mod 16), 2);
      end loop;

      return rom_v;
   end function init_rom;

   -- Note: Vivado does not implement this table using LUTRAM, even when
   -- instructed to do so with the "ram_style" attribute.
   constant pla_rom : rom_type(0 to 2047)        := init_rom;

   signal pla_addr : std_logic_vector(10 downto 0);
   signal pla_data : std_logic_vector(1 downto 0);

begin

   -- The table index is the top 7 bits of n followed by the 4 bits of d just
   -- after the leading "0001".
   pla_addr_proc : process (all)
   begin
      pla_addr <= n_i(G_SIZE-1 downto G_SIZE-7) & d_i(G_SIZE-5 downto G_SIZE-8);

      if G_DEBUG then
         report "n=" & to_string(n_i(G_SIZE-1 downto G_SIZE-7)) &
                ", d=" & to_string(d_i(G_SIZE-5 downto G_SIZE-8));
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

