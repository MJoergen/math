library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- This divides two numbers using the SRT algorithm (with radix 4).
-- It is inspired by this analysis: https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html
--
-- This is the top level. It divides two unsigned integers and returns a
-- fixed-point quotient with 32 integer bits and 32 fractional bits, rounded to
-- nearest.
--
-- The division proceeds in three stages, much like a floating point divider:
-- 1. normalizer : Shift n_i and d_i so they are both in the range [1, 2).
-- 2. div        : Divide the normalized values using SRT.
-- 3. shifter    : Shift the quotient back to undo the normalization.
-- Finally, the result is rounded.
--
-- Limitations (see normalizer.vhd):
-- * n_i and d_i must be less than 2^29. This is checked with an assertion
--   when a division is started.
--
-- Division by zero: If d_i is zero, then div_by_zero_o is set, and q_o is all
-- ones (the largest value). Otherwise div_by_zero_o is cleared.
--
-- Usage: Pulse start_over_i for one clock cycle. The inputs n_i and d_i are
-- only sampled in that cycle. The result is valid on q_o and div_by_zero_o
-- when busy_o returns low. A division takes 37 clock cycles (3 clock cycles
-- for a division by zero).

entity srt_float is
   generic (
      G_DEBUG : boolean := false
   );
   port (
      clk_i         : in    std_logic;
      n_i           : in    std_logic_vector(31 downto 0); -- dividend
      d_i           : in    std_logic_vector(31 downto 0); -- divisor
      q_o           : out   std_logic_vector(63 downto 0); -- quotient (32.32 fixed point)
      div_by_zero_o : out   std_logic;                     -- d_i was zero
      start_over_i  : in    std_logic;
      busy_o        : out   std_logic
   );
end entity srt_float;

architecture synthesis of srt_float is

   signal norm_n   : std_logic_vector(31 downto 0) := (others => '0');
   signal norm_d   : std_logic_vector(31 downto 0) := X"10000000";
   signal norm_exp : integer range -29 to 29;

   -- The quotient from div, with 2 integer bits and 66 fractional bits
   signal div_start : std_logic;
   signal div_q     : std_logic_vector(67 downto 0);
   signal div_busy  : std_logic;

   -- Whether the current division is a division by zero
   signal div_by_zero : std_logic                  := '0';

   -- The un-normalized quotient, with 32 integer bits and 36 fractional bits.
   -- The 4 extra fractional bits are used for rounding.
   signal shifter_q : std_logic_vector(67 downto 0);
   signal shifted   : std_logic_vector(67 downto 0);

   -- Number of positions to shift div_q right. The quotient from div has 66
   -- fractional bits, and we want 36 fractional bits, so the shift is 30 plus
   -- the normalization exponent.
   signal exp : natural range 1 to 59              := 30;

   type   state_type is (IDLE_ST, BUSY_ST, ROUND_ST);
   signal state : state_type                       := IDLE_ST;

begin

   busy_o <= '1' when state /= IDLE_ST else '0';

   -- Check the inputs when a division is started. These are concurrent
   -- assertions, so they are checked as soon as start_over_i is asserted,
   -- before the assertions inside div.
   assert start_over_i /= '1' or n_i(31 downto 29) = "000"
      report "srt_float: Dividend 0x" & to_hstring(n_i) & " is too large. Must be less than 2^29."
      severity error;

   assert start_over_i /= '1' or d_i(31 downto 29) = "000"
      report "srt_float: Divisor 0x" & to_hstring(d_i) & " is too large. Must be less than 2^29."
      severity error;

   srt_float_proc : process (clk_i)
      variable res_v   : std_logic_vector(67 downto 0);
      -- Half of the LSB of q_o. Adding this before truncating the 4 extra
      -- fractional bits rounds to nearest.
      constant C_ROUND : std_logic_vector(67 downto 0) := X"00000000000000008";
   begin
      if rising_edge(clk_i) then

         case state is

            when IDLE_ST =>
               null;

            when BUSY_ST =>
               -- Wait for div to finish
               if div_busy = '0' then
                  shifted <= shifter_q;
                  state   <= ROUND_ST;
               end if;

            when ROUND_ST =>
               res_v := shifted + C_ROUND;
               if div_by_zero = '1' then
                  q_o <= (others => '1');
               else
                  q_o <= res_v(67 downto 4);
               end if;
               div_by_zero_o <= div_by_zero;
               state         <= IDLE_ST;

         end case;

         -- Start a new division. The div instance is started in the same
         -- clock cycle (unless d_i is zero), see div_start below.
         if start_over_i then
            exp   <= 30 + norm_exp;
            if d_i = 0 then
               div_by_zero <= '1';
            else
               div_by_zero <= '0';
            end if;
            state <= BUSY_ST;
         end if;
      end if;
   end process srt_float_proc;

   -- Don't start div for a division by zero, since the divisor can then not be
   -- normalized. BUSY_ST then only waits until div is idle, which it normally
   -- is already, so it ends after one clock cycle. The result from div is
   -- ignored, since q_o is set to all ones.
   div_start <= start_over_i when d_i /= 0 else
                '0';

   normalizer_inst : entity work.normalizer
      port map (
         n_i   => n_i,
         d_i   => d_i,
         n_o   => norm_n,
         d_o   => norm_d,
         exp_o => norm_exp
      ); -- normalizer_inst

   div_inst : entity work.div
      generic map (
         G_SIZE  => 32,
         G_DEBUG => G_DEBUG
      )
      port map (
         clk_i   => clk_i,
         start_i => div_start,
         n_i     => norm_n,
         d_i     => norm_d,
         q_o     => div_q,
         busy_o  => div_busy
      ); -- div_inst

   shifter_inst : entity work.shifter
      port map (
         p_i   => div_q,
         exp_i => exp,
         q_o   => shifter_q
      ); -- shifter_inst

end architecture synthesis;
