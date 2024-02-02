library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

entity tb_fast_sincos is
end entity tb_fast_sincos;

architecture simulation of tb_fast_sincos is

   constant C_PI    : real                  := 3.141592653589793;
   constant C_DEBUG : boolean               := false;

   type     c64_float_type is record
      exp  : unsigned( 7 downto 0);
      mant : unsigned(31 downto 0);
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
      c64float_v.exp := to_unsigned(integer(floor(log2(arg_pos_v))) + 129, 8);
      arg_pos_v      := arg_pos_v / (2.0 ** (to_integer(c64float_v.exp) - 128));
      assert arg_pos_v >= 0.5 and arg_pos_v < 1.0;
      if arg_pos_v = 0.5 then
         c64float_v.mant := X"80000000";
      else
         c64float_v.mant := 0 - to_unsigned(integer((1.0 - arg_pos_v) * (2.0 ** 32)), 32);
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
      mant_v := arg.mant;
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
      res_v := sign_v * res_v * (2.0 ** (to_integer(arg.exp) - 128));
      if C_DEBUG then
         report "-c64float2real: res=" & to_string(res_v);
      end if;
      return res_v;
   end function c64float2real;


   signal   running             : std_logic := '1';
   signal   clk                 : std_logic := '1';
   signal   start               : std_logic;
   signal   ready               : std_logic;
   signal   c64float_in         : c64_float_type;
   signal   c64float_out_cos    : c64_float_type;
   signal   c64float_out_sin    : c64_float_type;
   signal   count               : natural;
   signal   max_error_cos       : real      := 0.0;
   signal   max_error_sin       : real      := 0.0;
   signal   max_error_cos_angle : real;
   signal   max_error_sin_angle : real;

begin

   clk <= running and not clk after 5 ns;

   fast_sincos_inst : entity work.fast_sincos
      generic map (
         G_DEBUG => C_DEBUG
      )
      port map (
         clk_i      => clk,
         start_i    => start,
         ready_o    => ready,
         arg_exp_i  => c64float_in.exp,
         arg_mant_i => c64float_in.mant,
         cos_exp_o  => c64float_out_cos.exp,
         cos_mant_o => c64float_out_cos.mant,
         sin_exp_o  => c64float_out_sin.exp,
         sin_mant_o => c64float_out_sin.mant
      ); -- fast_sincos_inst

   -- The main test procedure
   test_proc : process
      --

      -- Perform a single calculation of sine and cosine.

      procedure verify_sincos (real_val : real) is
         variable c64float_arg_v     : c64_float_type;
         variable real_arg_v         : real;
         variable c64float_exp_cos_v : c64_float_type;
         variable c64float_exp_sin_v : c64_float_type;
         variable diff_cos_v         : real;
         variable diff_sin_v         : real;
      begin
         count              <= count + 1;

         -- Convert from real to C64 float and back to real, in order to get a real
         -- value that exactly matches the C64 floating point bit pattern.
         c64float_arg_v     := real2c64float(real_val);
         real_arg_v         := c64float2real(c64float_arg_v);

         -- Now calculate the expected output values.
         c64float_exp_cos_v := real2c64float(cos(real_arg_v));
         c64float_exp_sin_v := real2c64float(sin(real_arg_v));
         report "Testing " & to_string(real_arg_v, 11) & " = " &
                to_string(real_arg_v / (2.0 * C_PI), 11) & " * 2pi";

         -- Initiate the calculation and wait for the result
         c64float_in        <= c64float_arg_v;
         start              <= '1';
         wait until rising_edge(clk);
         start              <= '0';
         wait until rising_edge(clk);
         while ready = '0' loop
            wait until rising_edge(clk);
         end loop;

         diff_cos_v := abs(c64float2real(c64float_out_cos) - cos(real_arg_v));
         diff_sin_v := abs(c64float2real(c64float_out_sin) - sin(real_arg_v));

         if diff_cos_v > max_error_cos then
            max_error_cos       <= diff_cos_v;
            max_error_cos_angle <= real_val;
         end if;

         if diff_sin_v > max_error_sin then
            max_error_sin       <= diff_sin_v;
            max_error_sin_angle <= real_val;
         end if;

         wait until rising_edge(clk);
         wait until rising_edge(clk);
      end procedure verify_sincos;

      variable start_time_v : time;
      variable end_time_v   : time;
      variable arg_v        : real;

   begin
      start        <= '0';
      count        <= 0;
      wait for 100 ns;
      wait until rising_edge(clk);
      start_time_v := now;
      report "Test started";
      for vali in 0 to 120 loop
         arg_v := (real(vali) / 480.0) * C_PI;
         verify_sincos(arg_v);
      end loop;
      end_time_v := now;
      report "Test finished, " &
             to_string(real((end_time_v - start_time_v) / 10 ns) / real(count)) &
             " clock cycles per calculation";
      report "log2(max_error_cos)=" & to_string(log(max_error_cos)/log(2.0), 2) & " at " & to_string(max_error_cos_angle, 11);
      report "log2(max_error_sin)=" & to_string(log(max_error_sin)/log(2.0), 2) & " at " & to_string(max_error_sin_angle, 11);
      wait until rising_edge(clk);
      running    <= '0';
   end process test_proc;

end architecture simulation;

