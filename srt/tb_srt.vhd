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
-- Each result is compared against the expected value. The integer part is
-- calculated using integer division, and the fractional part using binary
-- long division.
--
-- At the end it reports the average number of clock cycles per division, and
-- how many results had a fractional part that was too low or too high.
--
-- The generic G_PLA selects the quotient digit table, see srt_core.vhd. For
-- instance, "make sim PLA=pentium" runs the testbench with the original
-- Pentium table. Then the divider has the Pentium's FDIV bug, and the
-- testbench verifies that 4195835/3145727 gives the Pentium's wrong result.
-- The other divisions are still correct, since the bug is so rare.

entity tb_srt is
   generic (
      G_PLA : string := "srt"
   );
end entity tb_srt;

architecture simulation of tb_srt is

   signal running     : std_logic := '1';
   signal clk         : std_logic := '1';
   signal n           : std_logic_vector(31 downto 0);
   signal d           : std_logic_vector(31 downto 0);
   signal q           : std_logic_vector(63 downto 0);
   signal invalid     : std_logic;
   signal start_over  : std_logic;
   signal busy        : std_logic;

   signal low_count   : natural := 0;
   signal high_count  : natural := 0;

begin

   clk <= running and not clk after 5 ns;

   srt_inst : entity work.srt
      generic map (
         G_PLA => G_PLA
      )
      port map (
         clk_i         => clk,
         n_i           => n,
         d_i           => d,
         q_o           => q,
         invalid_o     => invalid,
         start_over_i  => start_over,
         busy_o        => busy
      );

   test_proc : process

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

      -- Start a single division, wait for the result, and verify it.
      procedure verify_division(arg_n : natural; arg_d : natural) is
         variable exp_q_high : std_logic_vector(31 downto 0) := to_stdlogicvector(arg_n / arg_d, 32);
         variable exp_q_low  : std_logic_vector(31 downto 0) := get_frac(arg_n, arg_d);
      begin
         report "verify: n=" & to_string(arg_n) & ", d=" & to_string(arg_d);

         n          <= to_stdlogicvector(arg_n, 32);
         d          <= to_stdlogicvector(arg_d, 32);
         start_over <= '1';
         wait until rising_edge(clk);
         start_over <= '0';
         wait until rising_edge(clk);
         assert busy = '1';
         wait until busy = '0';
         assert q(63 downto 32) = exp_q_high
            report "HIGH: Calculating " & to_string(arg_n) & "/" & to_string(arg_d) &
               ". Got 0x" & to_hstring(q(63 downto 32)) & ", expected 0x" & to_hstring(exp_q_high);
         assert q(31 downto 0)  = exp_q_low
            report "LOW: Calculating " & to_string(arg_n) & "/" & to_string(arg_d) &
               ". Got 0x" & to_hstring(q(31 downto 0)) & ", expected 0x" & to_hstring(exp_q_low);
         assert invalid = '0'
            report "Calculating " & to_string(arg_n) & "/" & to_string(arg_d) &
               ". invalid_o is set";

         -- Count the rounding errors (only relevant if the asserts above are
         -- not fatal)
         if q(31 downto 0) < exp_q_low then
            low_count <= low_count + 1;
         end if;
         if q(31 downto 0) > exp_q_low then
            high_count <= high_count + 1;
         end if;
      end procedure verify_division;

      -- Start a division with invalid inputs, and verify that the result is
      -- all ones, and that invalid_o is set. The inputs are given as vectors,
      -- since a natural can not hold values of 2^31 or more.
      procedure verify_invalid(arg_n : std_logic_vector(31 downto 0);
                               arg_d : std_logic_vector(31 downto 0)) is
      begin
         report "verify: n=0x" & to_hstring(arg_n) & ", d=0x" & to_hstring(arg_d);

         n          <= arg_n;
         d          <= arg_d;
         start_over <= '1';
         wait until rising_edge(clk);
         start_over <= '0';
         wait until rising_edge(clk);
         assert busy = '1';
         wait until busy = '0';
         assert q = X"FFFFFFFFFFFFFFFF"
            report "Calculating 0x" & to_hstring(arg_n) & "/0x" & to_hstring(arg_d) &
               ". Got 0x" & to_hstring(q) & ", expected 0xFFFFFFFFFFFFFFFF";
         assert invalid = '1'
            report "Calculating 0x" & to_hstring(arg_n) & "/0x" & to_hstring(arg_d) &
               ". invalid_o is not set";
      end procedure verify_invalid;

      -- Calculate 4195835/3145727, the division that exposed the Pentium's
      -- FDIV bug. With the original Pentium table, this divider has the same
      -- bug: it gives the same wrong result as the Pentium, and as the model
      -- ("./srt.py 4195835 3145727 --pla pentium"). Otherwise the result is
      -- correct.
      procedure verify_fdiv_bug is
         constant C_WRONG : std_logic_vector(63 downto 0) := X"00000001556FEC72";
      begin
         if G_PLA /= "pentium" then
            verify_division(4195835, 3145727);
            return;
         end if;

         report "verify: n=4195835, d=3145727 (FDIV bug)";
         n          <= to_stdlogicvector(4195835, 32);
         d          <= to_stdlogicvector(3145727, 32);
         start_over <= '1';
         wait until rising_edge(clk);
         start_over <= '0';
         wait until rising_edge(clk);
         assert busy = '1';
         wait until busy = '0';
         assert q = C_WRONG
            report "FDIV: Calculating 4195835/3145727. Got 0x" & to_hstring(q) &
               ", expected the Pentium's wrong result 0x" & to_hstring(C_WRONG);
      end procedure verify_fdiv_bug;

      variable start_time : time;
      variable end_time   : time;

      constant MAX_D : natural := 100;
      constant MAX_N : natural := 100;

      -- The largest input value supported by srt
      constant C_MAX : natural := 2 ** 29 - 1;

      -- The number of random divisions, and the random seeds (fixed, so the
      -- test is reproducible)
      constant C_NUM_RANDOM : natural := 20000;
      variable seed1_v      : positive := 1;
      variable seed2_v      : positive := 42;
      variable n_v          : natural;
      variable d_v          : natural;

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
      -- division checks that invalid_o is cleared again.
      verify_invalid(X"00000000", X"00000000");
      verify_invalid(X"00000001", X"00000000");
      verify_invalid(X"1FFFFFFF", X"00000000");
      verify_invalid(X"20000000", X"00000001");
      verify_invalid(X"00000001", X"20000000");
      verify_invalid(X"FFFFFFFF", X"00000003");
      verify_invalid(X"FFFFFFFF", X"FFFFFFFF");
      verify_invalid(X"FFFFFFFF", X"00000000");

      -- Zero dividend
      verify_division(0, 1);
      verify_division(0, 7);
      verify_division(0, C_MAX);

      -- Largest inputs
      verify_division(C_MAX, 1);
      verify_division(C_MAX, 3);
      verify_division(C_MAX, C_MAX);
      verify_division(C_MAX - 1, C_MAX);
      verify_division(1, C_MAX);
      verify_division(123456789, 1000);

      -- The division that exposed the Pentium's FDIV bug
      verify_fdiv_bug;

      -- Every normalization shift, with the smallest and largest mantissas
      for i in 0 to 28 loop
         for j in 0 to 28 loop
            verify_division(2 ** i, 2 ** j);
            verify_division(2 ** (i + 1) - 1, 2 ** j);
            verify_division(2 ** i, 2 ** (j + 1) - 1);
            verify_division(2 ** (i + 1) - 1, 2 ** (j + 1) - 1);
         end loop;
      end loop;

      report "Testing all divisions n/d with 1 <= n, d <= " & to_string(MAX_N);
      start_time := now;
      for di in 1 to MAX_D loop
         for ni in 1 to MAX_N loop
            verify_division(ni, di);
         end loop;
      end loop;
      end_time := now;
      report to_string(real((end_time-start_time) / 10 ns) / real(MAX_D*MAX_N)) &
         " clock cycles per division";

      report "Testing " & to_string(C_NUM_RANDOM) & " random divisions";
      for i in 1 to C_NUM_RANDOM loop
         n_v := random_value;
         d_v := random_value;
         if d_v = 0 then
            d_v := 1;
         end if;
         verify_division(n_v, d_v);
      end loop;

      report "Test finished";
      report "low_count=" & to_string(low_count);
      report "high_count=" & to_string(high_count);
      wait until rising_edge(clk);
      running <= '0';
   end process;

end architecture simulation;

