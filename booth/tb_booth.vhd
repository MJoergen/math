library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- Testbench for the Booth multiplier.
-- If G_EXHAUSTIVE is true, all pairs of inputs are tested. Otherwise G_NUM_TESTS random pairs are tested.
-- The VALID and READY signals are asserted randomly with probabilities G_VALID_PCT and G_READY_PCT.
-- When both probabilities are 100%, the throughput is verified as well.

entity tb_booth is
   generic (
      G_DATA_SIZE  : positive := 4;
      G_EXHAUSTIVE : boolean  := true;
      G_NUM_TESTS  : natural  := 5000;
      G_VALID_PCT  : natural  := 70;  -- Probability (in percent) of asserting VALID
      G_READY_PCT  : natural  := 70   -- Probability (in percent) of asserting READY
   );
end entity tb_booth;

architecture simulation of tb_booth is

   constant C_CLK_PERIOD : time := 10 ns;

   pure function num_tests return natural is
   begin
      if G_EXHAUSTIVE then
         return 2 ** (2 * G_DATA_SIZE);
      else
         return G_NUM_TESTS;
      end if;
   end function num_tests;

   constant C_NUM_TESTS : natural := num_tests;

   signal   clk     : std_logic := '1';
   signal   rst     : std_logic := '1';
   signal   running : std_logic := '1';

   signal   s_valid : std_logic := '0';
   signal   s_ready : std_logic;
   signal   s_a     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
   signal   s_b     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
   signal   m_valid : std_logic;
   signal   m_ready : std_logic := '0';
   signal   m_res   : std_logic_vector(2 * G_DATA_SIZE - 1 downto 0);

   -- Generate the i'th pair of inputs.
   -- The random generator state is passed in, so that the stimulus and verification
   -- processes can independently generate the same sequence of inputs.
   procedure get_inputs (
      i         : natural;
      seed1     : inout positive;
      seed2     : inout positive;
      a         : out signed(G_DATA_SIZE - 1 downto 0);
      b         : out signed(G_DATA_SIZE - 1 downto 0)
   ) is
      variable r_v : real;

      impure function random_signed return signed is
         variable res_v : signed(G_DATA_SIZE - 1 downto 0);
      begin
         for j in res_v'range loop
            uniform(seed1, seed2, r_v);
            res_v(j) := '1' when r_v < 0.5 else '0';
         end loop;
         return res_v;
      end function random_signed;

   begin
      if G_EXHAUSTIVE then
         a := to_signed(i mod 2 ** G_DATA_SIZE - 2 ** (G_DATA_SIZE - 1), G_DATA_SIZE);
         b := to_signed(i / 2 ** G_DATA_SIZE - 2 ** (G_DATA_SIZE - 1), G_DATA_SIZE);
      else
         a := random_signed;
         b := random_signed;
      end if;
   end procedure get_inputs;

begin

   clk <= running and not clk after C_CLK_PERIOD / 2;
   rst <= '1', '0' after 10 * C_CLK_PERIOD;

   booth_inst : entity work.booth
      generic map (
         G_DATA_SIZE => G_DATA_SIZE
      )
      port map (
         clk_i     => clk,
         rst_i     => rst,
         s_valid_i => s_valid,
         s_ready_o => s_ready,
         s_a_i     => s_a,
         s_b_i     => s_b,
         m_valid_o => m_valid,
         m_ready_i => m_ready,
         m_res_o   => m_res
      );

   stim_proc : process
      variable seed1_v    : positive := 42;
      variable seed2_v    : positive := 43;
      variable rnd_seed1_v : positive := 1;
      variable rnd_seed2_v : positive := 2;
      variable r_v        : real;
      variable a_v        : signed(G_DATA_SIZE - 1 downto 0);
      variable b_v        : signed(G_DATA_SIZE - 1 downto 0);
   begin
      s_valid <= '0';
      wait until rst = '0';
      wait until rising_edge(clk);

      for i in 0 to C_NUM_TESTS - 1 loop
         get_inputs(i, seed1_v, seed2_v, a_v, b_v);

         -- Random delay before asserting VALID
         uniform(rnd_seed1_v, rnd_seed2_v, r_v);
         while r_v * 100.0 >= real(G_VALID_PCT) loop
            s_valid <= '0';
            s_a     <= (others => 'X');
            s_b     <= (others => 'X');
            wait until rising_edge(clk);
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
         end loop;

         s_valid <= '1';
         s_a     <= std_logic_vector(a_v);
         s_b     <= std_logic_vector(b_v);
         wait until rising_edge(clk) and s_ready = '1';
      end loop;

      s_valid <= '0';
      s_a     <= (others => 'X');
      s_b     <= (others => 'X');
      wait;
   end process stim_proc;

   verify_proc : process
      variable seed1_v     : positive := 42;
      variable seed2_v     : positive := 43;
      variable rnd_seed1_v : positive := 3;
      variable rnd_seed2_v : positive := 4;
      variable r_v         : real;
      variable a_v         : signed(G_DATA_SIZE - 1 downto 0);
      variable b_v         : signed(G_DATA_SIZE - 1 downto 0);
      variable exp_v       : signed(2 * G_DATA_SIZE - 1 downto 0);
      variable last_v      : time;
   begin
      m_ready <= '0';
      wait until rst = '0';

      for i in 0 to C_NUM_TESTS - 1 loop
         get_inputs(i, seed1_v, seed2_v, a_v, b_v);
         exp_v := a_v * b_v;

         -- Randomly assert READY, until a result is received
         loop
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
            m_ready <= '1' when r_v * 100.0 < real(G_READY_PCT) else '0';
            wait until rising_edge(clk);
            exit when m_valid = '1' and m_ready = '1';
         end loop;

         assert signed(m_res) = exp_v
            report "Mismatch: " & to_string(to_integer(a_v)) & " * " & to_string(to_integer(b_v)) &
                   " gave 0x" & to_hstring(m_res) & ", expected 0x" & to_hstring(exp_v)
            severity failure;

         -- Without any stalls, a new result must be produced every G_DATA_SIZE clock cycles
         if G_VALID_PCT >= 100 and G_READY_PCT >= 100 and G_DATA_SIZE >= 2 and i > 0 then
            assert now - last_v = G_DATA_SIZE * C_CLK_PERIOD
               report "Throughput: " & to_string((now - last_v) / C_CLK_PERIOD) &
                      " clock cycles between results, expected " & to_string(G_DATA_SIZE)
               severity failure;
         end if;
         last_v := now;
      end loop;

      m_ready <= '0';
      wait until rising_edge(clk);
      report "Test finished: " & to_string(C_NUM_TESTS) & " tests passed with G_DATA_SIZE=" &
             to_string(G_DATA_SIZE);
      running <= '0';
      wait;
   end process verify_proc;

end architecture simulation;

