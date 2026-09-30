library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- Testbench for the divider.
--
-- It first divides by zero twice, which must give all ones, and then divides
-- all pairs of numerator and divisor from 1 to 100. Each quotient is compared
-- with the exact quotient, with the fraction rounded to nearest. The integer
-- part must be exact. The last bit of the fraction is not always exact, so
-- these mismatches are reported (with severity warning), and the numbers of
-- results that are too low and too high are printed at the end.
--
-- In each clock cycle, VALID and READY are asserted randomly with the
-- probabilities G_VALID_PCT and G_READY_PCT. At the end, the average number of
-- clock cycles per division is printed.

entity tb_fast_divide is
   generic (
      G_VALID_PCT : natural := 70;  -- Probability (in percent) of asserting VALID
      G_READY_PCT : natural := 70   -- Probability (in percent) of asserting READY
   );
end entity tb_fast_divide;

architecture simulation of tb_fast_divide is

   constant C_CLK_PERIOD : time    := 10 ns;
   constant C_MAX_D      : natural := 100;
   constant C_MAX_N      : natural := 100;
   constant C_NUM_ZERO   : natural := 2;
   constant C_NUM_TESTS  : natural := C_NUM_ZERO + C_MAX_D * C_MAX_N;

   -- The i'th pair of numerator and divisor
   procedure get_inputs (
      i : natural;
      n : out natural;
      d : out natural
   ) is
   begin
      if i < C_NUM_ZERO then
         n := 1 + i * (C_MAX_N - 1);
         d := 0;
      else
         n := (i - C_NUM_ZERO) mod C_MAX_N + 1;
         d := (i - C_NUM_ZERO) / C_MAX_N + 1;
      end if;
   end procedure get_inputs;

   pure function real2unsigned (
      arg : real
   ) return unsigned is
   begin
      if arg = 0.5 then
         return X"80000000";
      elsif arg < 0.5 then
         return to_unsigned(integer(arg * (2.0 ** 32)), 32);
      else
         return 0 - to_unsigned(integer((1.0 - arg) * (2.0 ** 32)), 32);
      end if;
   end function real2unsigned;

   signal clk     : std_logic := '1';
   signal rst     : std_logic := '1';
   signal running : std_logic := '1';

   signal s_valid : std_logic := '0';
   signal s_ready : std_logic;
   signal s_n     : std_logic_vector(31 downto 0);
   signal s_d     : std_logic_vector(31 downto 0);
   signal m_valid : std_logic;
   signal m_ready : std_logic := '0';
   signal m_q     : std_logic_vector(63 downto 0);

begin

   clk <= running and not clk after C_CLK_PERIOD / 2;
   rst <= '1', '0' after 10 * C_CLK_PERIOD;

   fast_divide_inst : entity work.fast_divide
      port map (
         clk_i     => clk,
         rst_i     => rst,
         s_valid_i => s_valid,
         s_ready_o => s_ready,
         s_n_i     => s_n,
         s_d_i     => s_d,
         m_valid_o => m_valid,
         m_ready_i => m_ready,
         m_q_o     => m_q
      ); -- fast_divide_inst

   stim_proc : process
      variable rnd_seed1_v : positive := 1;
      variable rnd_seed2_v : positive := 2;
      variable r_v         : real;
      variable n_v         : natural;
      variable d_v         : natural;
   begin
      s_valid <= '0';
      wait until rst = '0';
      wait until rising_edge(clk);

      for i in 0 to C_NUM_TESTS - 1 loop
         get_inputs(i, n_v, d_v);

         -- Random delay before asserting VALID
         uniform(rnd_seed1_v, rnd_seed2_v, r_v);
         while r_v * 100.0 >= real(G_VALID_PCT) loop
            s_valid <= '0';
            s_n     <= (others => 'X');
            s_d     <= (others => 'X');
            wait until rising_edge(clk);
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
         end loop;

         s_valid <= '1';
         s_n     <= std_logic_vector(to_unsigned(n_v, 32));
         s_d     <= std_logic_vector(to_unsigned(d_v, 32));
         wait until rising_edge(clk) and s_ready = '1';
      end loop;

      s_valid <= '0';
      s_n     <= (others => 'X');
      s_d     <= (others => 'X');
      wait;
   end process stim_proc;

   verify_proc : process
      variable rnd_seed1_v  : positive := 3;
      variable rnd_seed2_v  : positive := 4;
      variable r_v          : real;
      variable n_v          : natural;
      variable d_v          : natural;
      variable exp_high_v   : unsigned(31 downto 0);
      variable exp_low_v    : unsigned(31 downto 0);
      variable start_time_v : time;
      variable low_count_v  : natural := 0;
      variable high_count_v : natural := 0;
   begin
      m_ready <= '0';
      wait until rst = '0';
      wait until rising_edge(clk);

      start_time_v := now;
      report "Test started";

      for i in 0 to C_NUM_TESTS - 1 loop
         get_inputs(i, n_v, d_v);

         -- Randomly assert READY, until a result is received
         loop
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
            m_ready <= '1' when r_v * 100.0 < real(G_READY_PCT) else '0';
            wait until rising_edge(clk);
            exit when m_valid = '1' and m_ready = '1';
         end loop;

         if d_v = 0 then
            assert m_q = (m_q'range => '1')
               report "Calculating " & to_string(n_v) & "/0" &
                      ". Got 0x" & to_hstring(m_q) & ", expected all ones";
         else
            exp_high_v := to_unsigned(n_v / d_v, 32);
            exp_low_v  := real2unsigned(real(n_v rem d_v) / real(d_v));

            assert unsigned(m_q(63 downto 32)) = exp_high_v
               report "Calculating " & to_string(n_v) & "/" & to_string(d_v) &
                      ". Got 0x" & to_hstring(m_q(63 downto 32)) & ", expected 0x" & to_hstring(exp_high_v);
            assert unsigned(m_q(31 downto 0)) = exp_low_v
               report "Calculating " & to_string(n_v) & "/" & to_string(d_v) &
                      ". Got 0x" & to_hstring(m_q(31 downto 0)) & ", expected 0x" & to_hstring(exp_low_v)
               severity warning;

            if unsigned(m_q(31 downto 0)) < exp_low_v then
               low_count_v := low_count_v + 1;
            end if;
            if unsigned(m_q(31 downto 0)) > exp_low_v then
               high_count_v := high_count_v + 1;
            end if;
         end if;
      end loop;

      report "Test finished, " &
             to_string(real((now - start_time_v) / C_CLK_PERIOD) / real(C_NUM_TESTS)) &
             " clock cycles per division";
      report "low_count=" & to_string(low_count_v);
      report "high_count=" & to_string(high_count_v);
      m_ready <= '0';
      wait until rising_edge(clk);
      running <= '0';
      wait;
   end process verify_proc;

end architecture simulation;

