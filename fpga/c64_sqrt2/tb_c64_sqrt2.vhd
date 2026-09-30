library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- Testbench for the square root.
--
-- It calculates the square root of 0, 1, 2, 3, 4, 0.5, and -1 (which gives an
-- error), and of 15938 values from 0.031 to 8. Each result is compared with the
-- exact square root, rounded to nearest. The last bit of the mantissa is not
-- always exact, so the mismatches are reported (with severity warning), and
-- the numbers of results that are too low and too high are printed at the end.
--
-- In each clock cycle, VALID and READY are asserted randomly with the
-- probabilities G_VALID_PCT and G_READY_PCT. At the end, the average number of
-- clock cycles per calculation is printed.

entity tb_c64_sqrt2 is
   generic (
      G_VALID_PCT : natural := 70;  -- Probability (in percent) of asserting VALID
      G_READY_PCT : natural := 70   -- Probability (in percent) of asserting READY
   );
end entity tb_c64_sqrt2;

architecture simulation of tb_c64_sqrt2 is

   constant C_CLK_PERIOD : time := 10 ns;

   type float_type is record
      exp  : std_logic_vector( 7 downto 0);
      mant : std_logic_vector(31 downto 0);
   end record float_type;

   constant C_ZERO : float_type := (exp => X"00", mant => X"00000000");

   -- The test values: First a few fixed values, and then values from
   -- C_MAX_VAL/16 to 16*C_MAX_VAL-1, divided by 2*C_MAX_VAL.
   constant C_MAX_VAL   : natural := 1000;
   constant C_NUM_FIXED : natural := 7;
   constant C_NUM_TESTS : natural := C_NUM_FIXED + 16 * C_MAX_VAL - C_MAX_VAL / 16;

   type real_array_type is array (natural range <>) of real;

   constant C_FIXED : real_array_type(0 to C_NUM_FIXED - 1) := (0.0, 1.0, 2.0, 3.0, 4.0, 0.5, -1.0);

   pure function get_value (
      i : natural
   ) return real is
   begin
      if i < C_NUM_FIXED then
         return C_FIXED(i);
      else
         return real(C_MAX_VAL / 16 + i - C_NUM_FIXED) / (2.0 * real(C_MAX_VAL));
      end if;
   end function get_value;

   pure function to_hstring (
      arg : float_type
   ) return string is
   begin
      return to_hstring(arg.exp) & ":" & to_hstring(arg.mant);
   end function to_hstring;

   pure function real2float (
      arg : real
   ) return float_type is
      variable float_v   : float_type;
      variable sign_v    : std_logic;
      variable arg_pos_v : real;
   begin
      float_v := C_ZERO;
      if arg = 0.0 then
         return float_v;
      end if;
      if arg < 0.0 then
         arg_pos_v := -arg;
         sign_v    := '1';
      else
         arg_pos_v := arg;
         sign_v    := '0';
      end if;
      float_v.exp := std_logic_vector(to_unsigned(integer(floor(log2(arg_pos_v))) + 129, 8));
      arg_pos_v   := arg_pos_v / (2.0 ** (to_integer(unsigned(float_v.exp)) - 128));
      assert arg_pos_v >= 0.5 and arg_pos_v < 1.0;
      if arg_pos_v = 0.5 then
         float_v.mant := X"80000000";
      else
         float_v.mant := std_logic_vector(0 - to_unsigned(integer((1.0 - arg_pos_v) * (2.0 ** 32)), 32));
      end if;
      float_v.mant(31) := sign_v;
      return float_v;
   end function real2float;

   pure function float2real (
      arg : float_type
   ) return real is
      variable res_v  : real := 0.0;
      variable sign_v : real := 1.0;
      variable mant_v : unsigned(31 downto 0);
   begin
      if arg.exp = X"00" then
         return res_v;
      end if;
      mant_v := unsigned(arg.mant);
      if arg.mant(31) = '1' then
         sign_v := -1.0;
      else
         mant_v(31) := '1';
      end if;
      if mant_v = X"80000000" then
         res_v := 0.5;
      else
         res_v := 1.0 - real(to_integer(0 - mant_v)) / (2.0 ** 32);
      end if;
      res_v := sign_v * res_v * (2.0 ** (to_integer(unsigned(arg.exp)) - 128));
      return res_v;
   end function float2real;

   signal clk     : std_logic := '1';
   signal rst     : std_logic := '1';
   signal running : std_logic := '1';

   signal s_valid : std_logic := '0';
   signal s_ready : std_logic;
   signal s_float : float_type;
   signal m_valid : std_logic;
   signal m_ready : std_logic := '0';
   signal m_float : float_type;
   signal m_error : std_logic;

begin

   clk <= running and not clk after C_CLK_PERIOD / 2;
   rst <= '1', '0' after 10 * C_CLK_PERIOD;

   c64_sqrt2_inst : entity work.c64_sqrt2
      port map (
         clk_i     => clk,
         rst_i     => rst,
         s_valid_i => s_valid,
         s_ready_o => s_ready,
         s_exp_i   => s_float.exp,
         s_mant_i  => s_float.mant,
         m_valid_o => m_valid,
         m_ready_i => m_ready,
         m_exp_o   => m_float.exp,
         m_mant_o  => m_float.mant,
         m_error_o => m_error
      ); -- c64_sqrt2_inst

   stim_proc : process
      variable rnd_seed1_v : positive := 1;
      variable rnd_seed2_v : positive := 2;
      variable r_v         : real;
      variable float_v     : float_type;
   begin
      s_valid <= '0';
      wait until rst = '0';
      wait until rising_edge(clk);

      for i in 0 to C_NUM_TESTS - 1 loop
         float_v := real2float(get_value(i));
         assert float_v = real2float(float2real(float_v));

         -- Random delay before asserting VALID
         uniform(rnd_seed1_v, rnd_seed2_v, r_v);
         while r_v * 100.0 >= real(G_VALID_PCT) loop
            s_valid <= '0';
            s_float <= (exp => (others => 'X'), mant => (others => 'X'));
            wait until rising_edge(clk);
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
         end loop;

         s_valid <= '1';
         s_float <= float_v;
         wait until rising_edge(clk) and s_ready = '1';
      end loop;

      s_valid <= '0';
      s_float <= (exp => (others => 'X'), mant => (others => 'X'));
      wait;
   end process stim_proc;

   verify_proc : process
      variable rnd_seed1_v  : positive := 3;
      variable rnd_seed2_v  : positive := 4;
      variable r_v          : real;
      variable val_v        : real;
      variable float_v      : float_type;
      variable exp_real_v   : real;
      variable exp_float_v  : float_type;
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
         val_v   := get_value(i);
         float_v := real2float(val_v);

         -- Randomly assert READY, until a result is received
         loop
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
            m_ready <= '1' when r_v * 100.0 < real(G_READY_PCT) else '0';
            wait until rising_edge(clk);
            exit when m_valid = '1' and m_ready = '1';
         end loop;

         if val_v < 0.0 then
            assert m_error = '1' and m_float = C_ZERO
               report "Calculating sqrt(" & to_string(val_v) & "). Expected an error, got 0x" &
                      to_hstring(m_float) & " and m_error=" & to_string(m_error);
         else
            exp_real_v  := sqrt(float2real(float_v));
            exp_float_v := real2float(exp_real_v);
            assert m_error = '0'
               report "Calculating sqrt(" & to_string(val_v) & "). Got m_error=1";
            assert m_float = exp_float_v
               report "Calculating sqrt(" & to_string(val_v) & ") = " & to_string(exp_real_v) &
                      ", i.e. " & to_hstring(float_v) & " -> " & to_hstring(exp_float_v) &
                      ". Got 0x" & to_hstring(m_float)
               severity warning;
            if float2real(m_float) < float2real(exp_float_v) then
               low_count_v := low_count_v + 1;
            end if;
            if float2real(m_float) > float2real(exp_float_v) then
               high_count_v := high_count_v + 1;
            end if;
         end if;
      end loop;

      report "Test finished, " &
             to_string(real((now - start_time_v) / C_CLK_PERIOD) / real(C_NUM_TESTS)) &
             " clock cycles per calculation";
      report "low_count=" & to_string(low_count_v);
      report "high_count=" & to_string(high_count_v);
      m_ready <= '0';
      wait until rising_edge(clk);
      running <= '0';
      wait;
   end process verify_proc;

end architecture simulation;

