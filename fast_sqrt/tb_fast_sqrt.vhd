library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_fast_sqrt is
end entity tb_fast_sqrt;

architecture simulation of tb_fast_sqrt is

   signal running : std_logic := '1';
   signal clk     : std_logic := '1';
   signal start   : std_logic;
   signal val     : unsigned(31 downto 0);
   signal res     : unsigned(31 downto 0);
   signal busy    : std_logic;

   signal low_count  : natural := 0;
   signal high_count : natural := 0;

begin

   clk <= running and not clk after 5 ns;

   fast_sqrt_inst : entity work.fast_sqrt
      port map (
         clk_i   => clk,
         start_i => start,
         val_i   => val,
         res_o   => res,
         busy_o  => busy
      );

   test_proc : process
      pure function real2unsigned(arg : real) return unsigned is
      begin
         if arg = 0.5 then
            return X"80000000";
         elsif arg < 0.5 then
            return to_unsigned(integer(arg*(2.0**32)), 32);
         else
            return 0-to_unsigned(integer((1.0-arg)*(2.0**32)), 32);
         end if;
      end function real2unsigned;

      pure function unsigned2real(arg : unsigned(31 downto 0)) return real is
      begin
         if arg = X"80000000" then
            return 0.5;
         elsif arg(31) = '0' then
            return real(to_integer(arg))/(2.0**32);
         else
            return 1.0-real(to_integer(0-arg))/(2.0**32);
         end if;
      end function unsigned2real;

      procedure verify_sqrt(real_val : real) is
         variable bit_val      : unsigned(31 downto 0);
         variable exp_real_res : real;
         variable exp_bit_res  : unsigned(31 downto 0);
      begin

         bit_val      := real2unsigned(real_val);
         exp_real_res := sqrt(unsigned2real(bit_val));
         exp_bit_res  := real2unsigned(exp_real_res);

         val <= bit_val;
         start <= '1';
         wait until rising_edge(clk);
         start <= '0';
         wait until rising_edge(clk);
         assert busy = '1';
         wait until busy = '0';
         assert res = exp_bit_res
            report "Calculating sqrt(" & to_string(real_val) & ") = " & to_string(exp_real_res) &
               ", i.e. " & to_hstring(bit_val) & " -> " & to_hstring(exp_bit_res) &
               ". Got 0x" & to_hstring(res);

         if res < exp_bit_res then
            low_count <= low_count + 1;
         end if;
         if res > exp_bit_res then
            high_count <= high_count + 1;
         end if;
      end procedure verify_sqrt;

      variable start_time : time;
      variable end_time   : time;

      constant MAX_VAL : natural := 1000;

   begin
      wait for 100 ns;
      wait until rising_edge(clk);
      start_time := now;
      report "Test started";
      for vali in 0 to MAX_VAL-1 loop
         verify_sqrt(real(vali)/(2.0*real(MAX_VAL)) + 0.5);
      end loop;
      end_time := now;
      report "Test finished, " &
         to_string(real((end_time-start_time) / 10 ns) / real(MAX_VAL)) &
         " clock cycles per division";
      report "low_count=" & to_string(low_count);
      report "high_count=" & to_string(high_count);
      wait until rising_edge(clk);
      running <= '0';
   end process test_proc;

end architecture simulation;

