library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- This normalizes the dividend and divisor before the division.
--
-- Each value is shifted left so that the top nibble becomes "0001". In the
-- number format used by div.vhd this corresponds to 1 <= n_o, d_o < 2.
--
-- The shift amounts are combined into exp_o, such that the true quotient is:
--    n_i/d_i = n_o/d_o * 2^(-exp_o)
--
-- Limitations:
-- * The top three bits of n_i and d_i must be zero, i.e. the values must be
--   less than 2^29. Larger values are not shifted, so the result is wrong,
--   but the simulation does not crash. srt_float checks this with an
--   assertion.
-- * If n_i is zero, then n_o is zero too. Likewise for d_i. srt_float handles
--   a zero divisor separately.
--
-- This is a purely combinatorial block.

entity normalizer is
   port (
      n_i   : in    std_logic_vector(31 downto 0); -- dividend
      d_i   : in    std_logic_vector(31 downto 0); -- divisor
      n_o   : out   std_logic_vector(31 downto 0); -- normalized dividend
      d_o   : out   std_logic_vector(31 downto 0); -- normalized divisor
      exp_o : out   integer range -29 to 29        -- shift of n minus shift of d
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
      variable nlz_v : natural range 0 to 32;
      variable dlz_v : natural range 0 to 32;
      variable nz_v  : natural range 0 to 29;
      variable dz_v  : natural range 0 to 29;
   begin
      nlz_v := count_leading_zeros(n_i);
      dlz_v := count_leading_zeros(d_i);

      -- Number of positions to shift left. This is clamped at zero, so values
      -- that are too large do not cause an error in simulation.
      if nlz_v >= 3 then
         nz_v := nlz_v - 3;
      else
         nz_v := 0;
      end if;
      if dlz_v >= 3 then
         dz_v := dlz_v - 3;
      else
         dz_v := 0;
      end if;

      exp_o               <= nz_v - dz_v;
      n_o                 <= (others => '0');
      d_o                 <= (others => '0');
      n_o(31 downto nz_v) <= n_i(31 - nz_v downto 0);
      d_o(31 downto dz_v) <= d_i(31 - dz_v downto 0);
   end process norm_proc;

end architecture synthesis;

