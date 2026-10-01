library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- Testbench for the tangent CORDIC.
-- Feeds G_NUM_TESTS angles uniformly distributed in [0.0, pi/4[, plus a few fixed
-- corner cases (zero, and angles just below pi/4). The VALID and READY signals are
-- asserted randomly with probabilities G_VALID_PCT and G_READY_PCT.
--
-- The expected result is calculated with the Taylor series (see ref_tan), and the
-- tolerance (see C_TOLERANCE) follows from the error analysis in ALGORITHM.md.

entity tb_tan_cordic is
   generic (
      G_ITERATIONS : positive := 6;
      G_FRAC_BITS  : positive := 24;
      G_STEPS      : positive := 4;
      G_NUM_TESTS  : positive := 1000;
      G_VALID_PCT  : natural  := 70;  -- Probability (in percent) of asserting VALID
      G_READY_PCT  : natural  := 70   -- Probability (in percent) of asserting READY
   );
end entity tb_tan_cordic;

architecture simulation of tb_tan_cordic is

   constant C_CLK_PERIOD : time := 10 ns;

   -- The largest error, from "Accuracy and the number of iterations" in
   -- ALGORITHM.md: Two units of the last bit (from rounding the angle to
   -- G_FRAC_BITS bits, and from truncating the quotient), and the error of the
   -- Pade approximation, z^5/45 with z < 2^(1-G_ITERATIONS), times 2 (the
   -- largest slope of tan). The tolerance is twice this.
   constant C_TOLERANCE : real := 2.0 * (2.0 ** (1 - G_FRAC_BITS) +
                                         2.0 * 2.0 ** (-5 * (G_ITERATIONS - 1)) / 45.0);

   -- The tangent, from the Taylor series of the sine and the cosine. The tan
   -- of ieee.math_real is not accurate enough as a reference: GHDL calculates
   -- it with CORDIC (with 28 iterations), so its error is about 2^(-28).
   pure function ref_tan (
      arg : real
   ) return real is
      variable sin_term_v : real := arg;
      variable sin_v      : real := arg;
      variable cos_term_v : real := 1.0;
      variable cos_v      : real := 1.0;
   begin
      for n in 1 to 30 loop
         sin_term_v := -sin_term_v * arg * arg / real((2 * n) * (2 * n + 1));
         sin_v      := sin_v + sin_term_v;
         cos_term_v := -cos_term_v * arg * arg / real((2 * n - 1) * (2 * n));
         cos_v      := cos_v + cos_term_v;
      end loop;
      return sin_v / cos_v;
   end function ref_tan;

   -- Conversions between a real in [0.0, 1.0[ and the fixed-point format with
   -- G_FRAC_BITS fractional bits. These go one bit at a time, since an integer
   -- only holds 31 bits, too few for G_FRAC_BITS = 32. A real holds 52 bits.
   pure function to_fixed (
      arg : real
   ) return std_logic_vector is
      variable val_v : real := round(arg * 2.0 ** G_FRAC_BITS);
      variable res_v : std_logic_vector(G_FRAC_BITS - 1 downto 0);
   begin
      for i in G_FRAC_BITS - 1 downto 0 loop
         if val_v >= 2.0 ** i then
            res_v(i) := '1';
            val_v    := val_v - 2.0 ** i;
         else
            res_v(i) := '0';
         end if;
      end loop;
      return res_v;
   end function to_fixed;

   pure function from_fixed (
      arg : std_logic_vector
   ) return real is
      variable res_v : real := 0.0;
   begin
      for i in arg'range loop
         if arg(i) = '1' then
            res_v := res_v + 2.0 ** (i - G_FRAC_BITS);
         end if;
      end loop;
      return res_v;
   end function from_fixed;

   signal clk     : std_logic := '1';
   signal rst     : std_logic := '1';
   signal running : std_logic := '1';

   signal s_valid : std_logic := '0';
   signal s_ready : std_logic;
   signal s_angle : std_logic_vector(G_FRAC_BITS - 1 downto 0);
   signal m_valid : std_logic;
   signal m_ready : std_logic := '0';
   signal m_tan   : std_logic_vector(G_FRAC_BITS - 1 downto 0);

   -- Generate the i'th test angle, in radians, in the range [0.0, pi/4[.
   -- The random generator state is passed in, so that the stimulus and verification
   -- processes can independently generate the same sequence of angles.
   procedure get_angle (
      i       : natural;
      seed1_v : inout positive;
      seed2_v : inout positive;
      angle_v : out real
   ) is
      variable r_v : real;
   begin
      case i is

         when 0 =>
            angle_v := 0.0;

         when 1 =>
            angle_v := (math_pi / 4.0) * (1.0 - 2.0 ** (-20));

         when 2 =>
            angle_v := 2.0 ** (-30);

         when others =>
            uniform(seed1_v, seed2_v, r_v);
            angle_v := r_v * (math_pi / 4.0);

      end case;
   end procedure get_angle;

begin

   clk <= running and not clk after C_CLK_PERIOD / 2;
   rst <= '1', '0' after 10 * C_CLK_PERIOD;

   tan_cordic_inst : entity work.tan_cordic
      generic map (
         G_ITERATIONS => G_ITERATIONS,
         G_FRAC_BITS  => G_FRAC_BITS,
         G_STEPS      => G_STEPS
      )
      port map (
         clk_i     => clk,
         rst_i     => rst,
         s_valid_i => s_valid,
         s_ready_o => s_ready,
         s_angle_i => s_angle,
         m_valid_o => m_valid,
         m_ready_i => m_ready,
         m_tan_o   => m_tan
      );

   stim_proc : process
      variable seed1_v     : positive := 42;
      variable seed2_v     : positive := 43;
      variable rnd_seed1_v : positive := 1;
      variable rnd_seed2_v : positive := 2;
      variable r_v         : real;
      variable angle_v     : real;
   begin
      s_valid <= '0';
      wait until rst = '0';
      wait until rising_edge(clk);

      for i in 0 to G_NUM_TESTS - 1 loop
         get_angle(i, seed1_v, seed2_v, angle_v);

         -- Random delay before asserting VALID
         uniform(rnd_seed1_v, rnd_seed2_v, r_v);
         while r_v * 100.0 >= real(G_VALID_PCT) loop
            s_valid <= '0';
            s_angle <= (others => 'X');
            wait until rising_edge(clk);
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
         end loop;

         s_valid <= '1';
         s_angle <= to_fixed(angle_v);
         wait until rising_edge(clk) and s_ready = '1';
      end loop;

      s_valid <= '0';
      s_angle <= (others => 'X');
      wait;
   end process stim_proc;

   verify_proc : process
      variable seed1_v     : positive := 42;
      variable seed2_v     : positive := 43;
      variable rnd_seed1_v : positive := 3;
      variable rnd_seed2_v : positive := 4;
      variable r_v         : real;
      variable angle_v     : real;
      variable exp_v       : real;
      variable got_v       : real;
      variable err_v       : real;
   begin
      m_ready <= '0';
      wait until rst = '0';

      for i in 0 to G_NUM_TESTS - 1 loop
         get_angle(i, seed1_v, seed2_v, angle_v);
         exp_v := ref_tan(angle_v);

         -- Randomly assert READY, until a result is received
         loop
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
            m_ready <= '1' when r_v * 100.0 < real(G_READY_PCT) else '0';
            wait until rising_edge(clk);
            exit when m_valid = '1' and m_ready = '1';
         end loop;

         got_v := from_fixed(m_tan);
         err_v := abs(got_v - exp_v);

         assert err_v < C_TOLERANCE
            report "Mismatch: angle=" & to_string(angle_v, 10) &
                   " expected=" & to_string(exp_v, 10) &
                   " got=" & to_string(got_v, 10) &
                   " err=" & to_string(err_v, 10) &
                   " tolerance=" & to_string(C_TOLERANCE, 10)
            severity failure;
      end loop;

      m_ready <= '0';
      wait until rising_edge(clk);
      report "Test finished: " & to_string(G_NUM_TESTS) & " tests passed with G_ITERATIONS=" &
             to_string(G_ITERATIONS) & " and G_FRAC_BITS=" & to_string(G_FRAC_BITS);
      running <= '0';
      wait;
   end process verify_proc;

end architecture simulation;
