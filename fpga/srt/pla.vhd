library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- This is the quotient digit selection table of the SRT divider, corresponding
-- to the PLA (programmable logic array, see
-- https://en.wikipedia.org/wiki/Programmable_logic_array) in the Pentium
-- processor.
--
-- The table is indexed by only 11 bits, just like in the Pentium:
-- * The top 7 bits of the partial remainder n (sign, 3 integer bits, and
--   3 fractional bits). So n is truncated to a multiple of 1/8.
-- * The 4 bits of the divisor d just after the leading "0001". So d is
--   truncated to a multiple of 1/16.
-- The table therefore has 2^11 = 2048 entries. Each entry stores |q| (as an
-- unsigned number, so 2 is "10"), and the sign of q is taken from the sign of
-- n.
--
-- Why so few bits are enough is explained in ALGORITHM.md. For the theory,
-- see D. E. Atkins, "Higher-Radix Division Using Estimates of the Divisor and
-- Partial Remainders", IEEE Transactions on Computers, 1968:
-- http://degiorgi.math.hr/aaa_sem/Div/925-934.pdf
--
-- The input format is the same as in srt_core.vhd: two's complement with 4
-- integer bits including the sign, and d must be normalized (1 <= d < 2).
--
-- srt_core.vhd keeps the partial remainder in carry-save form (a sum and a
-- carry), like the Pentium. Only the top 7 bits of the sum and the carry are
-- added for the table lookup, so the table may see n one row too low. So each
-- entry must hold a digit that is valid not just for its own row of n, but
-- also for the row above. The digit is therefore selected by rounding n/d to
-- the nearest integer at the centre of this region, i.e. at the centre of two
-- rows of n and one column of d. See get_q, and ALGORITHM.md. The table also
-- works if n is calculated exactly.
--
-- The divisor does not change during a division, i.e. a division only uses one
-- column of the table. Since get_q rounds (n + 1/8)/d, where n is the value the
-- table sees, |q| only depends on |n + 1/8| within a column:
--    |q| = 0   for             |n + 1/8| < t0 + 1/8
--    |q| = 1   for   t0 + 1/8 <= |n + 1/8| < t1 + 1/8
--    |q| = 2   for   t1 + 1/8 <= |n + 1/8|
-- where the thresholds t0 and t1 (multiples of 1/8) are the smallest n >= 0
-- where |q| >= 1 and |q| >= 2 in the column, see "Selecting the digit with
-- two comparisons" in ALGORITHM.md. So when a division starts, srt_core.vhd
-- stores the thresholds of the column (get_col), and in each iteration the
-- entity pla below compares n against them (get_mag). This is much faster
-- than a lookup in the table, because the lookup depends on 11 bits, but the
-- comparisons only depend on the 7 bits of n. The entity pla checks that this
-- gives exactly the same digits as the table, for all 2048 entries.
--
-- The magnitude |q| is returned as two bits (mag_type): bit 0 is |q| >= 1,
-- and bit 1 is |q| >= 2. So |q| = 0, 1, 2 is "00", "01", "11". Note that this
-- differs from the table, where 2 is "10". The two bits are the two
-- comparisons, and they select the multiple of d directly.

package pla_pkg is

   type rom_type is array (natural range <>) of std_logic_vector(1 downto 0);

   -- The table, indexed by n(7 bits) & d(4 bits). Each entry stores |q| as an
   -- unsigned number, i.e. "00", "01", or "10".
   constant C_PLA_ROM : rom_type(0 to 2047);

   -- The thresholds of one column: t1 & t0, in units of 1/8
   subtype col_type is std_logic_vector(11 downto 0);

   -- Return the thresholds of the column for the 4 bits of d just after the
   -- leading "0001"
   pure function get_col (
      d4 : std_logic_vector(3 downto 0)
   ) return col_type;

   -- The magnitude of the quotient digit: "00", "01", or "11", see above
   subtype mag_type is std_logic_vector(1 downto 0);

   -- Select the magnitude of the quotient digit for the top 7 bits of n,
   -- using the thresholds of the column. The sign of the digit is the sign of
   -- n.
   pure function get_mag (
      n7  : std_logic_vector(6 downto 0);
      col : col_type
   ) return mag_type;

   -- Convert the sign of n and the magnitude to the quotient digit
   pure function get_digit (
      neg : std_logic;
      mag : mag_type
   ) return integer;

end package pla_pkg;

package body pla_pkg is

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
   -- The sign of q is the sign of n, see get_digit.
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

   constant C_PLA_ROM : rom_type(0 to 2047) := init_rom;

   type col_table_type is array (0 to 15) of col_type;

   -- Find the thresholds of each column: the smallest n >= 0 where the table
   -- holds |q| >= 1 and |q| >= 2.
   pure function init_cols return col_table_type is
      variable cols_v : col_table_type;
      variable t0_v   : natural range 0 to 63;
      variable t1_v   : natural range 0 to 63;
   begin
      --
      for d in 0 to 15 loop
         t0_v := 63;
         t1_v := 63;

         for n in 63 downto 0 loop
            if C_PLA_ROM(n * 16 + d) /= "00" then
               t0_v := n;
            end if;
            if C_PLA_ROM(n * 16 + d) = "10" then
               t1_v := n;
            end if;
         end loop;

         cols_v(d) := to_stdlogicvector(t1_v, 6) & to_stdlogicvector(t0_v, 6);
      end loop;

      return cols_v;
   end function init_cols;

   constant C_COLS : col_table_type := init_cols;

   pure function get_col (
      d4 : std_logic_vector(3 downto 0)
   ) return col_type is
   begin
      return C_COLS(to_integer(d4));
   end function get_col;

   pure function get_mag (
      n7  : std_logic_vector(6 downto 0);
      col : col_type
   ) return mag_type is
      variable u_v  : std_logic_vector(5 downto 0);
      variable s1_v : std_logic_vector(6 downto 0);
      variable s2_v : std_logic_vector(6 downto 0);
   begin
      -- For n >= 0 this is n, and for n < 0 it is -n - 1/8 (the one's
      -- complement). So |n + 1/8| = u_v + not sign, in units of 1/8.
      u_v := n7(5 downto 0) xor (5 downto 0 => n7(6));

      -- |n + 1/8| >= t + 1/8 is the same as u_v + not sign + (63 - t) >= 64,
      -- i.e. the carry out of a 6-bit addition, with the inverted sign as
      -- carry in. So each comparison is a single short carry chain.
      s1_v := ("0" & u_v) + ("0" & not col(5 downto 0)) + not n7(6);
      s2_v := ("0" & u_v) + ("0" & not col(11 downto 6)) + not n7(6);

      return s2_v(6) & s1_v(6);
   end function get_mag;

   pure function get_digit (
      neg : std_logic;
      mag : mag_type
   ) return integer is
      variable mag_v : integer range 0 to 2;
   begin
      if mag(1) = '1' then
         mag_v := 2;
      elsif mag(0) = '1' then
         mag_v := 1;
      else
         mag_v := 0;
      end if;

      if neg = '1' then
         return -mag_v;
      else
         return mag_v;
      end if;
   end function get_digit;

end package body pla_pkg;

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

library work;
   use work.pla_pkg.all;

-- Select the magnitude of the quotient digit for the partial remainder n_i,
-- using the thresholds col_i of the column of the table for the current
-- divisor. The sign of the digit is the sign of n_i.
--
-- This is a purely combinatorial block.

entity pla is
   generic (
      G_SIZE  : natural;
      G_DEBUG : boolean
   );
   port (
      n_i   : in  std_logic_vector(G_SIZE-1 downto 0); -- partial remainder
      col_i : in  col_type;                            -- see get_col
      mag_o : out mag_type                             -- see get_mag
   );
end entity pla;

architecture synthesis of pla is

   -- Check that the thresholds give the same digits as the table, for all
   -- 2048 entries. The magnitude must be "00", "01", or "11".
   pure function check_cols return boolean is
      variable n7_v  : std_logic_vector(6 downto 0);
      variable mag_v : mag_type;
   begin
      --
      for i in 0 to 2047 loop
         n7_v  := to_stdlogicvector(i / 16, 7);
         mag_v := get_mag(n7_v, get_col(to_stdlogicvector(i mod 16, 4)));
         if mag_v = "10" or get_digit('0', mag_v) /= to_integer(C_PLA_ROM(i)) then
            return false;
         end if;
      end loop;

      return true;
   end function check_cols;

   constant C_COLS_OK : boolean := check_cols;

begin

   f_cols : assert C_COLS_OK
      report "The thresholds of the columns do not match the table"
      severity failure;

   mag_proc : process (all)
      variable mag_v : mag_type;
   begin
      mag_v := get_mag(n_i(G_SIZE-1 downto G_SIZE-7), col_i);

      if G_DEBUG then
         report "n=" & to_string(n_i(G_SIZE-1 downto G_SIZE-7)) &
                ", col=" & to_hstring(col_i) &
                ", mag_v=" & to_string(mag_v);
      end if;
      mag_o <= mag_v;
   end process mag_proc;

end architecture synthesis;

