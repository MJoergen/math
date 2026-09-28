library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- This is a testbench for srt_float.
--
-- It first tests a number of edge cases: Division by zero, a zero dividend,
-- the largest allowed inputs (2^29 - 1), and all combinations of powers of
-- two, which exercise every possible normalization shift.
--
-- Then it performs all divisions n/d with 1 <= n, d <= 1000.
--
-- Each result is compared against the expected value. The integer part is
-- calculated using integer division, and the fractional part using binary
-- long division.
--
-- At the end it reports the average number of clock cycles per division, and
-- how many results had a fractional part that was too low or too high.

entity tb_srt is
end entity tb_srt;

architecture simulation of tb_srt is

   signal running     : std_logic := '1';
   signal clk         : std_logic := '1';
   signal n           : std_logic_vector(31 downto 0);
   signal d           : std_logic_vector(31 downto 0);
   signal q           : std_logic_vector(63 downto 0);
   signal div_by_zero : std_logic;
   signal start_over  : std_logic;
   signal busy        : std_logic;

   signal low_count   : natural := 0;
   signal high_count  : natural := 0;

begin

   clk <= running and not clk after 5 ns;

   srt_float_inst : entity work.srt_float
      port map (
         clk_i         => clk,
         n_i           => n,
         d_i           => d,
         q_o           => q,
         div_by_zero_o => div_by_zero,
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
         assert div_by_zero = '0'
            report "Calculating " & to_string(arg_n) & "/" & to_string(arg_d) &
               ". div_by_zero_o is set";

         -- Count the rounding errors (only relevant if the asserts above are
         -- not fatal)
         if q(31 downto 0) < exp_q_low then
            low_count <= low_count + 1;
         end if;
         if q(31 downto 0) > exp_q_low then
            high_count <= high_count + 1;
         end if;
      end procedure verify_division;

      -- Start a division by zero, and verify that the result is all ones, and
      -- that div_by_zero_o is set.
      procedure verify_division_by_zero(arg_n : natural) is
      begin
         report "verify: n=" & to_string(arg_n) & ", d=0";

         n          <= to_stdlogicvector(arg_n, 32);
         d          <= (others => '0');
         start_over <= '1';
         wait until rising_edge(clk);
         start_over <= '0';
         wait until rising_edge(clk);
         assert busy = '1';
         wait until busy = '0';
         assert q = X"FFFFFFFFFFFFFFFF"
            report "Calculating " & to_string(arg_n) & "/0. Got 0x" & to_hstring(q) &
               ", expected 0xFFFFFFFFFFFFFFFF";
         assert div_by_zero = '1'
            report "Calculating " & to_string(arg_n) & "/0. div_by_zero_o is not set";
      end procedure verify_division_by_zero;

      variable start_time : time;
      variable end_time   : time;

      constant MAX_D : natural := 1000;
      constant MAX_N : natural := 1000;

      -- The largest input value supported by srt_float
      constant C_MAX : natural := 2 ** 29 - 1;
   begin
      wait for 100 ns;
      wait until rising_edge(clk);

      report "Testing edge cases";

      -- Division by zero. The next division checks that div_by_zero_o is
      -- cleared again.
      verify_division_by_zero(0);
      verify_division_by_zero(1);
      verify_division_by_zero(C_MAX);

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

      -- Every normalization shift, with the smallest and largest mantissas
      for i in 0 to 28 loop
         for j in 0 to 28 loop
            verify_division(2 ** i, 2 ** j);
            verify_division(2 ** (i + 1) - 1, 2 ** j);
            verify_division(2 ** i, 2 ** (j + 1) - 1);
            verify_division(2 ** (i + 1) - 1, 2 ** (j + 1) - 1);
         end loop;
      end loop;

      start_time := now;
      report "Test started";
      for di in 1 to MAX_D loop
         for ni in 1 to MAX_N loop
            verify_division(ni, di);
         end loop;
      end loop;
      end_time := now;
      report "Test finished, " &
         to_string(real((end_time-start_time) / 10 ns) / real(MAX_D*MAX_N)) &
         " clock cycles per division";
      report "low_count=" & to_string(low_count);
      report "high_count=" & to_string(high_count);
      wait until rising_edge(clk);
      running <= '0';
   end process;

end architecture simulation;

