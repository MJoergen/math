library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_fast_divide is
end entity tb_fast_divide;

architecture simulation of tb_fast_divide is

   signal running    : std_logic := '1';
   signal clk        : std_logic := '1';
   signal n          : unsigned(31 downto 0);
   signal d          : unsigned(31 downto 0);
   signal q          : unsigned(63 downto 0);
   signal start_over : std_logic;
   signal busy       : std_logic;

   signal low_count  : natural := 0;
   signal high_count : natural := 0;

begin

   clk <= running and not clk after 5 ns;

   fast_divide_inst : entity work.fast_divide
      port map (
         clk_i        => clk,
         n_i          => n,
         d_i          => d,
         q_o          => q,
         start_over_i => start_over,
         busy_o       => busy
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

      procedure verify_division(arg_n : natural; arg_d : natural) is
         variable exp_q_high : unsigned(31 downto 0) := to_unsigned(arg_n / arg_d, 32);
         variable exp_q_low  : unsigned(31 downto 0) := real2unsigned(real(arg_n rem arg_d) / real(arg_d));
      begin

         n          <= to_unsigned(arg_n, 32);
         d          <= to_unsigned(arg_d, 32);
         start_over <= '1';
         wait until rising_edge(clk);
         start_over <= '0';
         wait until rising_edge(clk);
         assert busy = '1';
         wait until busy = '0';
         assert q(63 downto 32) = exp_q_high
            report "Calculating " & to_string(arg_n) & "/" & to_string(arg_d) &
               ". Got 0x" & to_hstring(q(63 downto 32)) & ", expected 0x" & to_hstring(exp_q_high);
         assert q(31 downto 0)  = exp_q_low
            report "Calculating " & to_string(arg_n) & "/" & to_string(arg_d) &
               ". Got 0x" & to_hstring(q(31 downto 0)) & ", expected 0x" & to_hstring(exp_q_low);

         if q(31 downto 0) < exp_q_low then
            low_count <= low_count + 1;
         end if;
         if q(31 downto 0) > exp_q_low then
            high_count <= high_count + 1;
         end if;
      end procedure verify_division;

      variable start_time : time;
      variable end_time   : time;

      constant MAX_D : natural := 100;
      constant MAX_N : natural := 100;
   begin
      wait for 100 ns;
      wait until rising_edge(clk);
      start_time := now;
      report "Test started";
      for di in 1 to MAX_D loop
         for ni in 1 to MAX_N loop
            verify_division(ni, di);
         end loop;
      end loop;
      end_time := now;
      report "Test finished, " &
         to_string(real((end_time-start_time) / 10 ns) / real(MAX_D*MAX_N)) &
         " clock cycles per division";
      report "low_count=" & to_string(low_count);
      report "high_count=" & to_string(high_count);
      wait until rising_edge(clk);
      running <= '0';
   end process;

end architecture simulation;

