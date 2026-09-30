library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;
   use ieee.math_real.all;

-- This is a testbench for srt.
--
-- It first tests a number of edge cases: Invalid inputs (division by zero, and
-- inputs of 2^29 or more), a zero dividend, the largest valid inputs
-- (2^29 - 1), and all combinations of powers of two, which exercise every
-- possible normalization shift.
--
-- Then it performs all divisions n/d with 1 <= n, d <= 100, and finally a
-- number of pseudo-random divisions. The random inputs have a random number of
-- bits (up to 29), so they cover the whole range of valid inputs, including
-- every normalization shift and all bit patterns of the quotient.
--
-- The divider itself (srt_core.vhd) is formally verified for all inputs, so
-- this testbench mainly verifies srt around it: normalization, rounding,
-- invalid inputs, and the handshake.
--
-- The inputs are sent by stim_proc, and the results are verified by
-- check_proc. Between them, queue holds the inputs of the divisions whose
-- results have not been verified yet. So a new division can start while the
-- previous result is still waiting on the output. The edge cases and the
-- divisions with n, d <= 100 are sent back to back, with m_ready always high. The
-- random divisions have random gaps between the inputs, and random
-- backpressure on the output. The backpressure is often longer than a
-- division, so the next result must also wait inside srt. axi_proc verifies
-- that the output does not change until it is taken.
--
-- Each result is compared against the expected value. The integer part is
-- calculated using integer division, and the fractional part using binary
-- long division.
--
-- At the end it reports the average number of clock cycles per division, and
-- how many results had a fractional part that was too low or too high.
--
-- The generic G_PLA selects the quotient digit table, see srt_core.vhd. For
-- instance, "make sim PLA=pentium" runs the testbench with the original
-- Pentium table. Then the divider has the Pentium's FDIV bug (see
-- https://en.wikipedia.org/wiki/Pentium_FDIV_bug), and the testbench
-- verifies that 4195835/3145727 gives the Pentium's wrong result.
-- The other divisions are still correct, since the bug is so rare.

entity tb_srt is
   generic (
      G_PLA : string := "srt"
   );
end entity tb_srt;

architecture simulation of tb_srt is

   signal running : std_logic := '1';
   signal clk     : std_logic := '1';

   signal s_valid   : std_logic := '0';
   signal s_ready   : std_logic;
   signal s_n       : std_logic_vector(31 downto 0) := (others => '0');
   signal s_d       : std_logic_vector(31 downto 0) := (others => '0');
   signal m_valid   : std_logic;
   signal m_ready   : std_logic := '1';
   signal m_q       : std_logic_vector(63 downto 0);
   signal m_invalid : std_logic;

   -- Whether ready_proc drives m_ready randomly, instead of always high
   signal backpressure : boolean   := false;

   -- Number of results verified by check_proc
   signal num_verified : natural   := 0;

   signal low_count  : natural   := 0;
   signal high_count : natural   := 0;

   -- A queue of the inputs (n & d) of the divisions that have been started,
   -- but whose results have not been verified yet
   type queue_type is protected
      procedure push (arg : std_logic_vector(63 downto 0));
      impure function pop return std_logic_vector;
   end protected queue_type;

   type queue_type is protected body
      type     array_type is array (0 to 15) of std_logic_vector(63 downto 0);
      variable data_v  : array_type;
      variable first_v : natural range 0 to 15 := 0;
      variable count_v : natural range 0 to 16 := 0;

      procedure push (arg : std_logic_vector(63 downto 0)) is
      begin
         assert count_v < 16
            report "queue is full"
            severity failure;
         data_v((first_v + count_v) mod 16) := arg;
         count_v                            := count_v + 1;
      end procedure push;

      impure function pop return std_logic_vector is
         variable res_v : std_logic_vector(63 downto 0);
      begin
         assert count_v > 0
            report "Got a result, but no division was started"
            severity failure;
         res_v   := data_v(first_v);
         first_v := (first_v + 1) mod 16;
         count_v := count_v - 1;
         return res_v;
      end function pop;

   end protected body queue_type;

   shared variable queue_v : queue_type;

begin

   clk <= running and not clk after 5 ns;

   srt_inst : entity work.srt
      generic map (
         G_PLA => G_PLA
      )
      port map (
         clk_i       => clk,
         s_valid_i   => s_valid,
         s_ready_o   => s_ready,
         s_n_i       => s_n,
         s_d_i       => s_d,
         m_valid_o   => m_valid,
         m_ready_i   => m_ready,
         m_q_o       => m_q,
         m_invalid_o => m_invalid
      ); -- srt_inst

   stim_proc : process

      -- Number of divisions started, and how many of them were started while
      -- the previous result was waiting on the output
      variable num_started_v : natural := 0;
      variable num_overlap_v : natural := 0;

      -- Start a division. The inputs are given as vectors, since a natural
      -- can not hold values of 2^31 or more. s_valid is cleared again at the
      -- end, but if another division is started right away, it stays high.
      procedure start_division(arg_n : std_logic_vector(31 downto 0);
                               arg_d : std_logic_vector(31 downto 0)) is
      begin
         s_n           <= arg_n;
         s_d           <= arg_d;
         s_valid       <= '1';
         wait until rising_edge(clk) and s_ready = '1';
         queue_v.push(arg_n & arg_d);
         num_started_v := num_started_v + 1;
         if m_valid = '1' and m_ready = '0' then
            num_overlap_v := num_overlap_v + 1;
         end if;
         s_valid <= '0';
      end procedure start_division;

      procedure start_division(arg_n : natural; arg_d : natural) is
      begin
         start_division(to_stdlogicvector(arg_n, 32), to_stdlogicvector(arg_d, 32));
      end procedure start_division;

      variable start_time_v : time;
      variable end_time_v   : time;

      constant C_MAX_D : natural := 100;
      constant C_MAX_N : natural := 100;

      -- The largest input value supported by srt
      constant C_MAX : natural := 2 ** 29 - 1;

      -- The number of random divisions, and the random seeds (fixed, so the
      -- test is reproducible)
      constant C_NUM_RANDOM : natural := 20000;
      variable seed1_v      : positive := 1;
      variable seed2_v      : positive := 42;
      variable n_v          : natural;
      variable d_v          : natural;
      variable gap_v        : real;

      -- Return a random value 0 <= x < 2^e, where the number of bits e is
      -- itself random, between 0 and 29. So small and large values are both
      -- likely.
      impure function random_value return natural is
         variable r_v    : real;
         variable bits_v : natural range 0 to 29;
      begin
         uniform(seed1_v, seed2_v, r_v);
         bits_v := natural(floor(r_v * 30.0));
         uniform(seed1_v, seed2_v, r_v);
         return natural(floor(r_v * 2.0 ** bits_v));
      end function random_value;
   begin
      wait for 100 ns;
      wait until rising_edge(clk);

      report "Using the quotient digit table """ & G_PLA & """";
      report "Testing edge cases";

      -- Invalid inputs: Division by zero, and inputs of 2^29 or more. The next
      -- division checks that m_invalid is cleared again.
      start_division(X"00000000", X"00000000");
      start_division(X"00000001", X"00000000");
      start_division(X"1FFFFFFF", X"00000000");
      start_division(X"20000000", X"00000001");
      start_division(X"00000001", X"20000000");
      start_division(X"FFFFFFFF", X"00000003");
      start_division(X"FFFFFFFF", X"FFFFFFFF");
      start_division(X"FFFFFFFF", X"00000000");

      -- Zero dividend
      start_division(0, 1);
      start_division(0, 7);
      start_division(0, C_MAX);

      -- Largest inputs
      start_division(C_MAX, 1);
      start_division(C_MAX, 3);
      start_division(C_MAX, C_MAX);
      start_division(C_MAX - 1, C_MAX);
      start_division(1, C_MAX);
      start_division(123456789, 1000);

      -- The division that exposed the Pentium's FDIV bug, see check_proc
      start_division(4195835, 3145727);

      -- Every normalization shift, with the smallest and largest mantissas
      for i in 0 to 28 loop
         for j in 0 to 28 loop
            start_division(2 ** i, 2 ** j);
            start_division(2 ** (i + 1) - 1, 2 ** j);
            start_division(2 ** i, 2 ** (j + 1) - 1);
            start_division(2 ** (i + 1) - 1, 2 ** (j + 1) - 1);
         end loop;
      end loop;

      report "Testing all divisions n/d with 1 <= n, d <= " & to_string(C_MAX_N);
      start_time_v := now;
      for di in 1 to C_MAX_D loop
         for ni in 1 to C_MAX_N loop
            start_division(ni, di);
         end loop;
      end loop;
      end_time_v := now;
      report to_string(real((end_time_v-start_time_v) / 10 ns) / real(C_MAX_D*C_MAX_N)) &
             " clock cycles per division";

      report "Testing " & to_string(C_NUM_RANDOM) & " random divisions";
      backpressure <= true;
      for i in 1 to C_NUM_RANDOM loop
         n_v := random_value;
         d_v := random_value;
         if d_v = 0 then
            d_v := 1;
         end if;
         start_division(n_v, d_v);

         -- Sometimes wait up to 64 clock cycles, with s_valid low. Longer
         -- than a division, so srt sometimes waits for the next input.
         uniform(seed1_v, seed2_v, gap_v);
         if gap_v < 0.25 then
            for j in 0 to natural(floor(gap_v * 256.0)) loop
               wait until rising_edge(clk);
            end loop;
         end if;
      end loop;

      -- Wait for the remaining results
      while num_verified < num_started_v loop
         wait until rising_edge(clk);
      end loop;

      report to_string(num_overlap_v) &
             " divisions were started while the previous result was waiting";
      assert num_overlap_v > 0
         report "No division was started while the previous result was waiting";

      report "Test finished";
      report "low_count=" & to_string(low_count);
      report "high_count=" & to_string(high_count);
      wait until rising_edge(clk);
      running <= '0';
      wait;
   end process stim_proc;

   -- Take each result in a clock cycle where m_ready is high. With
   -- backpressure, m_ready is only high in one of 40 clock cycles, so a
   -- result often waits longer than a division takes.
   ready_proc : process
      variable seed1_v : positive := 7;
      variable seed2_v : positive := 99;
      variable r_v     : real;
   begin
      wait until rising_edge(clk);
      if backpressure then
         uniform(seed1_v, seed2_v, r_v);
         if r_v < 0.025 then
            m_ready <= '1';
         else
            m_ready <= '0';
         end if;
      else
         m_ready <= '1';
      end if;
   end process ready_proc;

   -- Verify each result when it is taken, against the inputs from the queue
   check_proc : process

      -- Calculate the fractional part of arg_n/arg_d as a 32-bit value, rounded
      -- to nearest. This uses binary long division with one extra bit for
      -- rounding, so it is exact. (Using the type real is not precise enough
      -- for large divisors.)
      -- Since arg_d < 2^29, the value 2*rem_v fits in an integer, the result
      -- is never exactly halfway between two values, and rounding up never
      -- overflows into the integer part.
      pure function get_frac(arg_n : natural; arg_d : natural) return std_logic_vector is
         variable rem_v  : natural;
         variable frac_v : std_logic_vector(32 downto 0);
      begin
         rem_v := arg_n rem arg_d;
         for i in 32 downto 0 loop
            rem_v := 2 * rem_v;
            if rem_v >= arg_d then
               frac_v(i) := '1';
               rem_v     := rem_v - arg_d;
            else
               frac_v(i) := '0';
            end if;
         end loop;
         frac_v := frac_v + 1;
         return frac_v(32 downto 1);
      end function get_frac;

      -- "n/d" in decimal, for valid inputs
      pure function division_string(arg_n : std_logic_vector; arg_d : std_logic_vector) return string is
      begin
         return to_string(to_integer(arg_n)) & "/" & to_string(to_integer(arg_d));
      end function division_string;

      -- The Pentium's wrong result for 4195835/3145727, the division that
      -- exposed its FDIV bug. With the original Pentium table, this divider
      -- has the same bug: it gives the same wrong result as the Pentium, and
      -- as the model ("./srt.py 4195835 3145727 --pla pentium").
      constant C_FDIV_N     : natural := 4195835;
      constant C_FDIV_D     : natural := 3145727;
      constant C_FDIV_WRONG : std_logic_vector(63 downto 0) := X"00000001556FEC72";

      variable nd_v         : std_logic_vector(63 downto 0);
      variable n_v          : std_logic_vector(31 downto 0);
      variable d_v          : std_logic_vector(31 downto 0);
      variable exp_q_high_v : std_logic_vector(31 downto 0);
      variable exp_q_low_v  : std_logic_vector(31 downto 0);
   begin
      wait until rising_edge(clk) and m_valid = '1' and m_ready = '1';
      nd_v := queue_v.pop;
      n_v  := nd_v(63 downto 32);
      d_v  := nd_v(31 downto 0);
      report "verify: n=0x" & to_hstring(n_v) & ", d=0x" & to_hstring(d_v);

      if n_v(31 downto 29) /= "000" or d_v(31 downto 29) /= "000" or d_v = 0 then
         -- Invalid inputs: The result must be all ones, and m_invalid set
         assert m_q = X"FFFFFFFFFFFFFFFF"
            report "Calculating 0x" & to_hstring(n_v) & "/0x" & to_hstring(d_v) &
                   ". Got 0x" & to_hstring(m_q) & ", expected 0xFFFFFFFFFFFFFFFF";
         assert m_invalid = '1'
            report "Calculating 0x" & to_hstring(n_v) & "/0x" & to_hstring(d_v) &
                   ". m_invalid_o is not set";

      elsif G_PLA = "pentium" and to_integer(n_v) = C_FDIV_N and to_integer(d_v) = C_FDIV_D then
         assert m_q = C_FDIV_WRONG
            report "FDIV: Calculating 4195835/3145727. Got 0x" & to_hstring(m_q) &
                   ", expected the Pentium's wrong result 0x" & to_hstring(C_FDIV_WRONG);

      else
         exp_q_high_v := to_stdlogicvector(to_integer(n_v) / to_integer(d_v), 32);
         exp_q_low_v  := get_frac(to_integer(n_v), to_integer(d_v));
         assert m_q(63 downto 32) = exp_q_high_v
            report "HIGH: Calculating " & division_string(n_v, d_v) &
                   ". Got 0x" & to_hstring(m_q(63 downto 32)) & ", expected 0x" & to_hstring(exp_q_high_v);
         assert m_q(31 downto 0) = exp_q_low_v
            report "LOW: Calculating " & division_string(n_v, d_v) &
                   ". Got 0x" & to_hstring(m_q(31 downto 0)) & ", expected 0x" & to_hstring(exp_q_low_v);
         assert m_invalid = '0'
            report "Calculating " & division_string(n_v, d_v) & ". m_invalid_o is set";

         -- Count the rounding errors (only relevant if the asserts above are
         -- not fatal)
         if m_q(31 downto 0) < exp_q_low_v then
            low_count <= low_count + 1;
         end if;
         if m_q(31 downto 0) > exp_q_low_v then
            high_count <= high_count + 1;
         end if;
      end if;

      num_verified <= num_verified + 1;
   end process check_proc;

   -- Verify the handshake on the output: Once m_valid is high, it stays high,
   -- and m_q and m_invalid stay unchanged, until the result is taken
   axi_proc : process (clk)
      variable waiting_v : boolean := false;
      variable q_v       : std_logic_vector(63 downto 0);
      variable invalid_v : std_logic;
   begin
      if rising_edge(clk) then
         if waiting_v then
            assert m_valid = '1' and m_q = q_v and m_invalid = invalid_v
               report "The result changed before it was taken";
         end if;
         waiting_v := m_valid = '1' and m_ready = '0';
         q_v       := m_q;
         invalid_v := m_invalid;
      end if;
   end process axi_proc;

end architecture simulation;
