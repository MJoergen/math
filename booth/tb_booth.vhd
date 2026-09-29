library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- Testbench for the Booth multiplier.
--
-- G_RADIX selects the design: 4 for booth.vhd, and 2 for booth_radix2.vhd.
--
-- If G_EXHAUSTIVE is true, all pairs of inputs are tested. Otherwise
-- G_NUM_TESTS random pairs are tested.
--
-- In each clock cycle, VALID and READY are asserted randomly with the
-- probabilities G_VALID_PCT and G_READY_PCT. When both probabilities are 100%,
-- the throughput is verified as well: one product every ceil(G_DATA_SIZE/2)
-- clock cycles for radix 4 (for G_DATA_SIZE >= 3), and every G_DATA_SIZE
-- clock cycles for radix 2 (for G_DATA_SIZE >= 2).

entity tb_booth is
   generic (
      G_RADIX      : positive := 4;
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

   -- Expected number of clock cycles per result when there are no stalls, and
   -- the smallest G_DATA_SIZE where this holds
   pure function get_iters return natural is
   begin
      if G_RADIX = 2 then
         return G_DATA_SIZE;
      else
         return (G_DATA_SIZE + 1) / 2;
      end if;
   end function get_iters;

   pure function get_min_size return natural is
   begin
      if G_RADIX = 2 then
         return 2;
      else
         return 3;
      end if;
   end function get_min_size;

   constant C_ITERS     : natural := get_iters;
   constant C_MIN_SIZE  : natural := get_min_size;

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

   -- Generate the i'th pair of inputs. The random generator state is passed in,
   -- so that the stimulus and verification processes can independently generate
   -- the same sequence of inputs.
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

   dut_gen : if G_RADIX = 2 generate

      booth_radix2_inst : entity work.booth_radix2
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

   elsif G_RADIX = 4 generate

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

   else generate

      assert false
         report "tb_booth: G_RADIX must be 2 or 4"
         severity failure;

   end generate dut_gen;

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

         -- Without any stalls, a new result must be produced every C_ITERS
         -- clock cycles
         if G_VALID_PCT >= 100 and G_READY_PCT >= 100 and G_DATA_SIZE >= C_MIN_SIZE and i > 0 then
            assert now - last_v = C_ITERS * C_CLK_PERIOD
               report "Throughput: " & to_string((now - last_v) / C_CLK_PERIOD) &
                      " clock cycles between results, expected " & to_string(C_ITERS)
               severity failure;
         end if;
         last_v := now;
      end loop;

      m_ready <= '0';
      wait until rising_edge(clk);
      report "Test finished: " & to_string(C_NUM_TESTS) & " tests passed with G_RADIX=" &
             to_string(G_RADIX) & ", G_DATA_SIZE=" & to_string(G_DATA_SIZE);
      running <= '0';
      wait;
   end process verify_proc;

end architecture simulation;

