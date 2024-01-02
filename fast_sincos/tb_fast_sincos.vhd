library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_fast_sincos is
end entity tb_fast_sincos;

architecture simulation of tb_fast_sincos is

   type float_type is record
      exp  : unsigned( 7 downto 0);
      mant : unsigned(31 downto 0);
   end record float_type;

   signal running    : std_logic := '1';
   signal clk        : std_logic := '1';
   signal start      : std_logic;
   signal ready      : std_logic;
   signal float_in   : float_type;
   signal float_out  : float_type;
   signal count      : natural := 0;

begin

   clk <= running and not clk after 5 ns;

   fast_sincos_inst : entity work.fast_sincos
      port map (
         clk_i   => clk,
         start_i => start,
         ready_o => ready,
         exp_i   => float_in.exp,
         mant_i  => float_in.mant,
         exp_o   => float_out.exp,
         mant_o  => float_out.mant
      ); -- fast_sqrt_inst

   test_proc : process
      pure function to_hstring(arg : float_type) return string is
      begin
         return to_hstring(arg.exp) & ":" & to_hstring(arg.mant);
      end function to_hstring;

      pure function real2float(arg : real) return float_type is
         variable float : float_type;
         variable sign  : std_logic;
         variable arg_pos : real;
      begin
         --report "+real2float: arg=" & to_string(arg);
         float.exp  := X"00";
         float.mant := X"00000000";
         if arg = 0.0 then
            return float;
         end if;
         if arg < 0.0 then
            arg_pos := -arg;
            sign := '1';
         else
            arg_pos := arg;
            sign := '0';
         end if;
         float.exp := to_unsigned(integer(floor(log2(arg_pos)))+129, 8);
         arg_pos := arg_pos / (2.0**(to_integer(float.exp)-128));
         assert arg_pos >= 0.5 and arg_pos < 1.0;
         if arg_pos = 0.5 then
            float.mant := X"80000000";
         else
            float.mant := 0-to_unsigned(integer((1.0-arg_pos)*(2.0**32)), 32);
         end if;
         float.mant(31) := sign;
         --report "-real2float: res=" & to_hstring(float);
         return float;
      end function real2float;

      pure function float2real(arg : float_type) return real is
         variable res  : real := 0.0;
         variable sign : real := 1.0;
         variable mant : unsigned(31 downto 0);
      begin
         --report "+float2real: arg=" & to_hstring(arg);
         if arg.exp = X"00" then
            return res;
         end if;
         mant := arg.mant;
         if arg.mant(31) = '1' then
            sign := -1.0;
         else
            mant(31) := '1';
         end if;
         if mant = X"80000000" then
            res := 0.5;
         else
            res :=  1.0-real(to_integer(0-mant))/(2.0**32);
         end if;
         res := sign * res * (2.0**(to_integer(arg.exp)-128));
         --report "-float2real: res=" & to_string(res);
         return res;
      end function float2real;

      procedure verify_sincos(real_val : real) is
      begin
      end procedure verify_sincos;

      variable start_time : time;
      variable end_time   : time;

      constant MAX_VAL : natural := 1000;
      variable arg : real;

   begin
      wait for 100 ns;
      wait until rising_edge(clk);
      start_time := now;
      report "Test started";
      verify_sincos(0.0);
      verify_sincos(1.0);
      verify_sincos(2.0);
      verify_sincos(3.0);
      verify_sincos(4.0);
      verify_sincos(0.5);
      verify_sincos(-1.0);
      for vali in MAX_VAL/16 to 16*MAX_VAL-1 loop
         arg := real(vali)/(2.0*real(MAX_VAL));
         verify_sincos(arg);
      end loop;
      end_time := now;
      report "Test finished, " &
         to_string(real((end_time-start_time) / 10 ns) / real(count)) &
         " clock cycles per calculation";
      wait until rising_edge(clk);
      running <= '0';
   end process test_proc;

end architecture simulation;

