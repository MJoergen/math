library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

entity tb_fast_sqrt2 is
end entity tb_fast_sqrt2;

architecture simulation of tb_fast_sqrt2 is

   type float_type is record
      exp  : unsigned( 7 downto 0);
      mant : unsigned(31 downto 0);
   end record float_type;

   signal running   : std_logic := '1';
   signal clk       : std_logic := '1';
   signal start     : std_logic;
   signal ready     : std_logic;
   signal err       : std_logic;
   signal float_in  : float_type;
   signal float_out : float_type;
   signal count     : natural := 0;

   signal low_count  : natural := 0;
   signal high_count : natural := 0;

begin

   clk <= running and not clk after 5 ns;

   fast_sqrt2_inst : entity work.fast_sqrt2
      port map (
         clk_i   => clk,
         start_i => start,
         ready_o => ready,
         error_o => err,
         exp_i   => float_in.exp,
         mant_i  => float_in.mant,
         exp_o   => float_out.exp,
         mant_o  => float_out.mant
      ); -- fast_sqrt2_inst

   test_proc : process
      pure function to_hstring(arg : float_type) return string is
      begin
         return to_hstring(arg.exp) & ":" & to_hstring(arg.mant);
      end function to_hstring;

      pure function real2float(arg : real) return float_type is
         variable float_v   : float_type;
         variable sign_v    : std_logic;
         variable arg_pos_v : real;
      begin
         -- report "+real2float: arg=" & to_string(arg);
         float_v.exp  := X"00";
         float_v.mant := X"00000000";
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
         float_v.exp := to_unsigned(integer(floor(log2(arg_pos_v)))+129, 8);
         arg_pos_v   := arg_pos_v / (2.0**(to_integer(float_v.exp)-128));
         assert arg_pos_v >= 0.5 and arg_pos_v < 1.0;
         if arg_pos_v = 0.5 then
            float_v.mant := X"80000000";
         else
            float_v.mant := 0-to_unsigned(integer((1.0-arg_pos_v)*(2.0**32)), 32);
         end if;
         float_v.mant(31) := sign_v;
         -- report "-real2float: res=" & to_hstring(float_v);
         return float_v;
      end function real2float;

      pure function float2real(arg : float_type) return real is
         variable res_v  : real := 0.0;
         variable sign_v : real := 1.0;
         variable mant_v : unsigned(31 downto 0);
      begin
         -- report "+float2real: arg=" & to_hstring(arg);
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
            res_v := 1.0-real(to_integer(0-mant_v))/(2.0**32);
         end if;
         res_v := sign_v * res_v * (2.0**(to_integer(arg.exp)-128));
         -- report "-float2real: res=" & to_string(res_v);
         return res_v;
      end function float2real;

      procedure verify_sqrt(real_val : real) is
         variable float_val_v     : float_type;
         variable exp_real_res_v  : real;
         variable exp_float_res_v : float_type;
      begin

         float_val_v := real2float(real_val);
         assert float_val_v = real2float(float2real(float_val_v));

         float_in <= float_val_v;
         start    <= '1';
         count    <= count + 1;
         wait until rising_edge(clk);
         start    <= '0';
         wait until rising_edge(clk);
         if real_val = 0.0 then
            assert ready = '1';
            assert err = '0';
            assert float_out.exp = X"00";
         elsif real_val >= 0.0 then
            exp_real_res_v  := sqrt(float2real(float_val_v));
            exp_float_res_v := real2float(exp_real_res_v);
            assert ready = '0';
            wait until ready = '1';
            assert err = '0';
            assert float_out = exp_float_res_v
               report "Calculating sqrt(" & to_string(real_val) & ") = " & to_string(exp_real_res_v) &
                      ", i.e. " & to_hstring(float_val_v) & " -> " & to_hstring(exp_float_res_v) &
                      ". Got 0x" & to_hstring(float_out);
            if float2real(float_out) < float2real(exp_float_res_v) then
               low_count <= low_count + 1;
            end if;
            if float2real(float_out) > float2real(exp_float_res_v) then
               high_count <= high_count + 1;
            end if;
         else
            assert ready = '1';
            assert err = '1';
         end if;
      end procedure verify_sqrt;

      variable start_time_v : time;
      variable end_time_v   : time;

      constant C_MAX_VAL : natural := 1000;
      variable arg_v     : real;

   begin
      wait for 100 ns;
      wait until rising_edge(clk);
      start_time_v := now;
      report "Test started";
      verify_sqrt(0.0);
      verify_sqrt(1.0);
      verify_sqrt(2.0);
      verify_sqrt(3.0);
      verify_sqrt(4.0);
      verify_sqrt(0.5);
      verify_sqrt(-1.0);
      for vali in C_MAX_VAL/16 to 16*C_MAX_VAL-1 loop
         arg_v := real(vali)/(2.0*real(C_MAX_VAL));
         verify_sqrt(arg_v);
      end loop;
      end_time_v := now;
      report "Test finished, " &
             to_string(real((end_time_v-start_time_v) / 10 ns) / real(count)) &
             " clock cycles per calculation";
      report "low_count=" & to_string(low_count);
      report "high_count=" & to_string(high_count);
      wait until rising_edge(clk);
      running    <= '0';
   end process test_proc;

end architecture simulation;

