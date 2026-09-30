library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- Testbench for the pipelined square root.
--
-- It calculates the square root of G_NUM_TESTS inputs, and compares each
-- output with the exact square root, rounded down. It prints the input and the
-- output whenever the error is larger than any previous error, and stops if the
-- error is larger than C_MAX_DIFF.
--
-- The i'th input is 0x100000 + (i*G_STRIDE mod 0x300000). So with the default
-- values of G_NUM_TESTS and G_STRIDE, all 3*2^20 valid inputs are tested in
-- increasing order. A larger G_STRIDE makes consecutive inputs differ a lot, so
-- a lost or duplicated value gives a large error. G_STRIDE must not be
-- divisible by 2 or 3, if all inputs are to be tested.
--
-- In each clock cycle, VALID and READY are asserted randomly with the
-- probabilities G_VALID_PCT and G_READY_PCT. When both probabilities are 100%,
-- the throughput is verified as well: one result in every clock cycle.

entity tb_pipeline_sqrt is
   generic (
      G_EXTRA_BITS : natural;
      G_NUM_TESTS  : natural  := 3 * 2 ** 20;
      G_STRIDE     : positive := 1;
      G_VALID_PCT  : natural  := 100;  -- Probability (in percent) of asserting VALID
      G_READY_PCT  : natural  := 100   -- Probability (in percent) of asserting READY
   );
end entity tb_pipeline_sqrt;

architecture simulation of tb_pipeline_sqrt is

   constant C_CLK_PERIOD : time := 10 ns;

   -- The largest error allowed, for any value of G_EXTRA_BITS
   constant C_MAX_DIFF : natural := 16#20#;

   -- The i'th input, in fixed point 2.20
   pure function get_input (
      i : natural
   ) return std_logic_vector is
      constant C_FIRST : natural := 16#100000#;
      constant C_COUNT : natural := 16#300000#;
      variable idx_v   : natural;
   begin
      -- i*G_STRIDE mod C_COUNT. The product is calculated with 44 bits, since
      -- it may not fit in an integer.
      idx_v := to_integer((to_unsigned(i mod C_COUNT, 22) * to_unsigned(G_STRIDE mod C_COUNT, 22)) mod C_COUNT);
      return std_logic_vector(to_unsigned(C_FIRST + idx_v, 22));
   end function get_input;

   signal clk     : std_logic := '1';
   signal rst     : std_logic := '1';
   signal running : std_logic := '1';

   signal s_valid : std_logic := '0';
   signal s_ready : std_logic;
   signal s_data  : std_logic_vector(21 downto 0);   -- Fixed point 2.20
   signal m_valid : std_logic;
   signal m_ready : std_logic := '0';
   signal m_data  : std_logic_vector(21 downto 0);   -- Fixed point 0.22

begin

   clk <= running and not clk after C_CLK_PERIOD / 2;
   rst <= '1', '0' after 10 * C_CLK_PERIOD;

   pipeline_sqrt_inst : entity work.pipeline_sqrt
      generic map (
         G_EXTRA_BITS => G_EXTRA_BITS
      )
      port map (
         clk_i     => clk,
         rst_i     => rst,
         s_valid_i => s_valid,
         s_ready_o => s_ready,
         s_data_i  => s_data,
         m_valid_o => m_valid,
         m_ready_i => m_ready,
         m_data_o  => m_data
      ); -- pipeline_sqrt_inst

   stim_proc : process
      variable rnd_seed1_v : positive := 1;
      variable rnd_seed2_v : positive := 2;
      variable r_v         : real;
   begin
      s_valid <= '0';
      wait until rst = '0';
      wait until rising_edge(clk);

      for i in 0 to G_NUM_TESTS - 1 loop
         -- Random delay before asserting VALID
         if G_VALID_PCT < 100 then
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
            while r_v * 100.0 >= real(G_VALID_PCT) loop
               s_valid <= '0';
               s_data  <= (others => 'X');
               wait until rising_edge(clk);
               uniform(rnd_seed1_v, rnd_seed2_v, r_v);
            end loop;
         end if;

         s_valid <= '1';
         s_data  <= get_input(i);
         wait until rising_edge(clk) and s_ready = '1';
      end loop;

      s_valid <= '0';
      s_data  <= (others => 'X');
      wait;
   end process stim_proc;

   verify_proc : process
      variable rnd_seed1_v    : positive := 3;
      variable rnd_seed2_v    : positive := 4;
      variable r_v            : real;
      variable data_in_v      : std_logic_vector(21 downto 0);
      variable y_v            : real;
      variable exp_data_out_v : std_logic_vector(21 downto 0);
      variable diff_v         : natural;
      variable max_diff_v     : natural := 0;
      variable last_v         : time;
   begin
      m_ready <= '0';
      wait until rst = '0';

      for i in 0 to G_NUM_TESTS - 1 loop
         data_in_v      := get_input(i);
         y_v            := real(to_integer(unsigned(data_in_v))) / (2.0 ** 20);
         exp_data_out_v := std_logic_vector(to_unsigned(integer(floor((sqrt(y_v) - 1.0) * (2.0 ** 22))), 22));

         -- Randomly assert READY, until a result is received
         loop
            if G_READY_PCT < 100 then
               uniform(rnd_seed1_v, rnd_seed2_v, r_v);
               m_ready <= '1' when r_v * 100.0 < real(G_READY_PCT) else '0';
            else
               m_ready <= '1';
            end if;
            wait until rising_edge(clk);
            exit when m_valid = '1' and m_ready = '1';
         end loop;

         diff_v := abs(to_integer(unsigned(m_data)) - to_integer(unsigned(exp_data_out_v)));
         if diff_v > max_diff_v then
            max_diff_v := diff_v;
            report "data_in:" & to_hstring(data_in_v) & ", data_out:" & to_hstring(m_data) &
                   ", exp_data_out:" & to_hstring(exp_data_out_v);
         end if;

         assert diff_v <= C_MAX_DIFF
            report "Error too large: data_in:" & to_hstring(data_in_v) & ", data_out:" &
                   to_hstring(m_data) & ", exp_data_out:" & to_hstring(exp_data_out_v)
            severity failure;

         -- Without any stalls, a new result must be produced in every clock
         -- cycle
         if G_VALID_PCT >= 100 and G_READY_PCT >= 100 and i > 0 then
            assert now - last_v = C_CLK_PERIOD
               report "Throughput: " & to_string((now - last_v) / C_CLK_PERIOD) &
                      " clock cycles between results, expected 1"
               severity failure;
         end if;
         last_v := now;
      end loop;

      m_ready <= '0';
      wait until rising_edge(clk);
      report "Test finished: " & to_string(G_NUM_TESTS) & " inputs with G_EXTRA_BITS=" &
             to_string(G_EXTRA_BITS) & ", maximum error 0x" &
             to_hstring(to_unsigned(max_diff_v, 24));
      running <= '0';
      wait;
   end process verify_proc;

end architecture simulation;

