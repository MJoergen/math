library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- Testbench for the sine and cosine.
--
-- It calculates the sine and cosine of 121 angles from 0 to pi/4, and checks
-- that the absolute error is less than 2^(-30). It prints the largest absolute
-- error of each, and the angles where they occur.
--
-- In each clock cycle, VALID and READY are asserted randomly with the
-- probabilities G_VALID_PCT and G_READY_PCT. At the end, the average number of
-- clock cycles per calculation is printed.

entity tb_c64_sincos is
   generic (
      G_VALID_PCT : natural := 70;  -- Probability (in percent) of asserting VALID
      G_READY_PCT : natural := 70   -- Probability (in percent) of asserting READY
   );
end entity tb_c64_sincos;

architecture simulation of tb_c64_sincos is

   constant C_CLK_PERIOD : time    := 10 ns;
   constant C_PI         : real    := 3.141592653589793;
   constant C_DEBUG      : boolean := false;
   constant C_NUM_TESTS  : natural := 121;
   constant C_MAX_ERROR  : real    := 2.0 ** (-30);

   -- The i'th test angle
   pure function get_angle (
      i : natural
   ) return real is
   begin
      return (real(i) / 480.0) * C_PI;
   end function get_angle;

   type c64_float_type is record
      exp  : std_logic_vector( 7 downto 0);
      mant : std_logic_vector(31 downto 0);
   end record c64_float_type;

   pure function to_hstring (arg : c64_float_type) return string is
   begin
      return to_hstring(arg.exp) & ":" & to_hstring(arg.mant);
   end function to_hstring;

   pure function real2c64float (arg : real) return c64_float_type is
      variable c64float_v : c64_float_type;
      variable sign_v     : std_logic;
      variable arg_pos_v  : real;
   begin
      if C_DEBUG then
         report "+real2c64float: arg=" & to_string(arg);
      end if;
      c64float_v.exp  := X"00";
      c64float_v.mant := X"00000000";
      if arg = 0.0 then
         return c64float_v;
      end if;
      if arg < 0.0 then
         arg_pos_v := -arg;
         sign_v    := '1';
      else
         arg_pos_v := arg;
         sign_v    := '0';
      end if;
      c64float_v.exp := std_logic_vector(to_unsigned(integer(floor(log2(arg_pos_v))) + 129, 8));
      arg_pos_v      := arg_pos_v / (2.0 ** (to_integer(unsigned(c64float_v.exp)) - 128));
      assert arg_pos_v >= 0.5 and arg_pos_v < 1.0;
      if arg_pos_v = 0.5 then
         c64float_v.mant := X"80000000";
      else
         c64float_v.mant := std_logic_vector(0 - to_unsigned(integer((1.0 - arg_pos_v) * (2.0 ** 32)), 32));
      end if;
      c64float_v.mant(31) := sign_v;
      if C_DEBUG then
         report "-real2c64float: res=" & to_hstring(c64float_v);
      end if;
      return c64float_v;
   end function real2c64float;

   pure function c64float2real (arg : c64_float_type) return real is
      variable res_v  : real := 0.0;
      variable sign_v : real := 1.0;
      variable mant_v : unsigned(31 downto 0);
   begin
      if C_DEBUG then
         report "+c64float2real: arg=" & to_hstring(arg);
      end if;
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
      if C_DEBUG then
         report "-c64float2real: res=" & to_string(res_v);
      end if;
      return res_v;
   end function c64float2real;


   signal clk     : std_logic := '1';
   signal rst     : std_logic := '1';
   signal running : std_logic := '1';

   signal s_valid : std_logic := '0';
   signal s_ready : std_logic;
   signal s_float : c64_float_type;
   signal m_valid : std_logic;
   signal m_ready : std_logic := '0';
   signal m_sin   : c64_float_type;
   signal m_cos   : c64_float_type;

begin

   clk <= running and not clk after C_CLK_PERIOD / 2;
   rst <= '1', '0' after 10 * C_CLK_PERIOD;

   c64_sincos_inst : entity work.c64_sincos
      generic map (
         G_DEBUG => C_DEBUG
      )
      port map (
         clk_i        => clk,
         rst_i        => rst,
         s_valid_i    => s_valid,
         s_ready_o    => s_ready,
         s_exp_i      => s_float.exp,
         s_mant_i     => s_float.mant,
         m_valid_o    => m_valid,
         m_ready_i    => m_ready,
         m_sin_exp_o  => m_sin.exp,
         m_sin_mant_o => m_sin.mant,
         m_cos_exp_o  => m_cos.exp,
         m_cos_mant_o => m_cos.mant
      ); -- c64_sincos_inst

   stim_proc : process
      variable rnd_seed1_v : positive := 1;
      variable rnd_seed2_v : positive := 2;
      variable r_v         : real;
   begin
      s_valid <= '0';
      wait until rst = '0';
      wait until rising_edge(clk);

      for i in 0 to C_NUM_TESTS - 1 loop
         -- Random delay before asserting VALID
         uniform(rnd_seed1_v, rnd_seed2_v, r_v);
         while r_v * 100.0 >= real(G_VALID_PCT) loop
            s_valid <= '0';
            s_float <= (exp => (others => 'X'), mant => (others => 'X'));
            wait until rising_edge(clk);
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
         end loop;

         s_valid <= '1';
         s_float <= real2c64float(get_angle(i));
         wait until rising_edge(clk) and s_ready = '1';
      end loop;

      s_valid <= '0';
      s_float <= (exp => (others => 'X'), mant => (others => 'X'));
      wait;
   end process stim_proc;

   verify_proc : process
      variable rnd_seed1_v         : positive := 3;
      variable rnd_seed2_v         : positive := 4;
      variable r_v                 : real;
      variable real_arg_v          : real;
      variable diff_cos_v          : real;
      variable diff_sin_v          : real;
      variable max_error_cos_v     : real := 0.0;
      variable max_error_sin_v     : real := 0.0;
      variable max_error_cos_arg_v : real := 0.0;
      variable max_error_sin_arg_v : real := 0.0;
      variable start_time_v        : time;
   begin
      m_ready <= '0';
      wait until rst = '0';
      wait until rising_edge(clk);

      start_time_v := now;
      report "Test started";

      for i in 0 to C_NUM_TESTS - 1 loop
         -- Convert from real to C64 float and back to real, in order to get a
         -- real value that exactly matches the C64 floating point bit pattern.
         real_arg_v := c64float2real(real2c64float(get_angle(i)));
         if C_DEBUG then
            report "Testing " & to_string(real_arg_v, 11) & " = " &
                   to_string(real_arg_v / (2.0 * C_PI), 11) & " * 2pi";
         end if;

         -- Randomly assert READY, until a result is received
         loop
            uniform(rnd_seed1_v, rnd_seed2_v, r_v);
            m_ready <= '1' when r_v * 100.0 < real(G_READY_PCT) else '0';
            wait until rising_edge(clk);
            exit when m_valid = '1' and m_ready = '1';
         end loop;

         diff_cos_v := abs(c64float2real(m_cos) - cos(real_arg_v));
         diff_sin_v := abs(c64float2real(m_sin) - sin(real_arg_v));

         assert diff_cos_v < C_MAX_ERROR and diff_sin_v < C_MAX_ERROR
            report "Calculating sin and cos of " & to_string(real_arg_v, 11) &
                   ". Got sin=0x" & to_hstring(m_sin) & " and cos=0x" & to_hstring(m_cos);

         if diff_cos_v > max_error_cos_v then
            max_error_cos_v     := diff_cos_v;
            max_error_cos_arg_v := get_angle(i);
         end if;

         if diff_sin_v > max_error_sin_v then
            max_error_sin_v     := diff_sin_v;
            max_error_sin_arg_v := get_angle(i);
         end if;
      end loop;

      report "Test finished, " &
             to_string(real((now - start_time_v) / C_CLK_PERIOD) / real(C_NUM_TESTS)) &
             " clock cycles per calculation";
      report "log2(max_error_cos)=" & to_string(log(max_error_cos_v) / log(2.0), 2) &
             " at " & to_string(max_error_cos_arg_v, 11);
      report "log2(max_error_sin)=" & to_string(log(max_error_sin_v) / log(2.0), 2) &
             " at " & to_string(max_error_sin_arg_v, 11);
      m_ready <= '0';
      wait until rising_edge(clk);
      running <= '0';
      wait;
   end process verify_proc;

end architecture simulation;

