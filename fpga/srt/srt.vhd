library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- This divides two numbers using the SRT algorithm (with radix 4), see
-- https://en.wikipedia.org/wiki/Division_algorithm#SRT_division
-- and ALGORITHM.md. It is inspired by Ken Shirriff's analysis of the Pentium
-- division bug: https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html
--
-- This is the top level. It divides two unsigned integers and returns a
-- fixed-point quotient with 32 integer bits and 32 fractional bits, rounded to
-- nearest.
--
-- The division proceeds in three stages, much like a floating point divider:
-- 1. normalizer : Shift s_n_i and s_d_i so they are both in the range [1, 2).
-- 2. srt_core   : Divide the normalized values using SRT.
-- 3. shifter    : Shift the quotient back to undo the normalization.
-- Finally, the result is rounded.
--
-- Inputs out of range: s_n_i and s_d_i must both be less than 2^29 (see
-- normalizer.vhd), and s_d_i must not be zero. Otherwise m_invalid_o is set,
-- and m_q_o is all ones (the largest value). For inputs in range, m_invalid_o
-- is cleared.
--
-- Usage: Both ports use AXI-style handshaking (see
-- https://en.wikipedia.org/wiki/Advanced_eXtensible_Interface),
-- i.e. a value is transferred in a clock cycle where both valid and ready are
-- high.
-- * Input: Set s_valid_i together with the dividend s_n_i and the divisor
--   s_d_i, and keep them unchanged until s_ready_o is high.
-- * Output: m_valid_o is set together with the quotient m_q_o and
--   m_invalid_o. They stay unchanged until m_ready_i is high.
-- The result is valid 37 clock cycles after the input transfer (2 clock
-- cycles for inputs out of range), unless the previous result is still waiting on
-- the output. A new division can start while the previous result is waiting
-- on the output, so with m_ready_i high, a division can start every 37 clock
-- cycles.

entity srt is
   generic (
      G_DEBUG : boolean := false;
      G_PLA   : string  := "srt"     -- The quotient digit table, see srt_core.vhd
   );
   port (
      clk_i       : in    std_logic;

      -- Input
      s_valid_i   : in    std_logic;
      s_ready_o   : out   std_logic;
      s_n_i       : in    std_logic_vector(31 downto 0); -- dividend
      s_d_i       : in    std_logic_vector(31 downto 0); -- divisor

      -- Output
      m_valid_o   : out   std_logic;
      m_ready_i   : in    std_logic;
      m_q_o       : out   std_logic_vector(63 downto 0); -- quotient (32.32 fixed point)
      m_invalid_o : out   std_logic                      -- inputs were out of range
   );
end entity srt;

architecture synthesis of srt is

   signal norm_n   : std_logic_vector(31 downto 0) := (others => '0');
   signal norm_d   : std_logic_vector(31 downto 0) := X"10000000";
   signal norm_exp : integer range -29 to 29;

   -- The handshake with srt_core. The quotient from srt_core has 2 integer
   -- bits and 66 fractional bits.
   signal core_s_valid : std_logic;
   signal core_s_ready : std_logic;
   signal core_m_valid : std_logic;
   signal core_m_ready : std_logic;
   signal core_q       : std_logic_vector(67 downto 0);

   -- Whether the inputs are in range, and whether the inputs of the current
   -- division were out of range
   signal inputs_valid : boolean;
   signal invalid      : std_logic                 := '0';

   -- The un-normalized quotient, with 32 integer bits and 36 fractional bits.
   -- The 4 extra fractional bits are used for rounding.
   signal shifter_q : std_logic_vector(67 downto 0);
   signal shifted   : std_logic_vector(67 downto 0);

   -- Number of positions to shift core_q right. The quotient from srt_core has
   -- 66 fractional bits, and we want 36 fractional bits, so the shift is 30
   -- plus the normalization exponent.
   signal exp : natural range 1 to 59              := 30;

   -- The state of the current division. The result on the output is tracked
   -- separately (m_valid), so the next division can start while the previous
   -- result is waiting on the output.
   type   state_type is (IDLE_ST, BUSY_ST, ROUND_ST);
   signal state   : state_type                     := IDLE_ST;
   signal m_valid : std_logic                      := '0';

begin

   -- srt_core is always ready when state is IDLE_ST, since its result has
   -- already been taken. So checking core_s_ready is redundant, but it makes
   -- sure that no input is lost if this ever changes.
   s_ready_o <= '1' when state = IDLE_ST and core_s_ready = '1' else
                '0';
   m_valid_o <= m_valid;

   -- Both inputs must be less than 2^29, and the divisor must not be zero
   inputs_valid <= s_n_i(31 downto 29) = "000" and s_d_i(31 downto 29) = "000" and s_d_i /= 0;

   srt_proc : process (clk_i)
      variable res_v   : std_logic_vector(67 downto 0);
      -- Half of the LSB of m_q_o. Adding this before truncating the 4 extra
      -- fractional bits rounds to nearest.
      constant C_ROUND : std_logic_vector(67 downto 0) := X"00000000000000008";
   begin
      if rising_edge(clk_i) then
         -- The result has been taken
         if m_ready_i = '1' then
            m_valid <= '0';
         end if;

         case state is

            when IDLE_ST =>
               null;

            when BUSY_ST =>
               -- Wait for the result from srt_core. It is taken in the same
               -- clock cycle, see core_m_ready below.
               if core_m_valid = '1' then
                  shifted <= shifter_q;
                  state   <= ROUND_ST;
               end if;

            when ROUND_ST =>
               -- Wait until the previous result has been taken
               if m_valid = '0' or m_ready_i = '1' then
                  res_v := shifted + C_ROUND;
                  if invalid = '1' then
                     m_q_o <= (others => '1');
                  else
                     m_q_o <= res_v(67 downto 4);
                  end if;
                  m_invalid_o <= invalid;
                  m_valid     <= '1';
                  state       <= IDLE_ST;
               end if;

         end case;

         -- Start a new division. The srt_core instance is started in the same
         -- clock cycle (unless the inputs are out of range), see core_s_valid
         -- below. For inputs out of range, the result from srt_core is not
         -- needed, since m_q_o is set to all ones.
         if s_valid_i = '1' and s_ready_o = '1' then
            exp <= 30 + norm_exp;
            if inputs_valid then
               invalid <= '0';
               state   <= BUSY_ST;
            else
               invalid <= '1';
               state   <= ROUND_ST;
            end if;
         end if;
      end if;
   end process srt_proc;

   -- Don't start srt_core for inputs out of range, since they cannot be
   -- normalized
   core_s_valid <= s_valid_i when state = IDLE_ST and inputs_valid else
                   '0';
   core_m_ready <= '1' when state = BUSY_ST else
                   '0';

   normalizer_inst : entity work.normalizer
      port map (
         n_i   => s_n_i,
         d_i   => s_d_i,
         n_o   => norm_n,
         d_o   => norm_d,
         exp_o => norm_exp
      ); -- normalizer_inst

   srt_core_inst : entity work.srt_core
      generic map (
         G_SIZE  => 32,
         G_DEBUG => G_DEBUG,
         G_PLA   => G_PLA
      )
      port map (
         clk_i     => clk_i,
         s_valid_i => core_s_valid,
         s_ready_o => core_s_ready,
         s_n_i     => norm_n,
         s_d_i     => norm_d,
         m_valid_o => core_m_valid,
         m_ready_i => core_m_ready,
         m_q_o     => core_q
      ); -- srt_core_inst

   shifter_inst : entity work.shifter
      port map (
         p_i   => core_q,
         exp_i => exp,
         q_o   => shifter_q
      ); -- shifter_inst

end architecture synthesis;
