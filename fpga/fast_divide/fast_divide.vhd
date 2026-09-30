library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fast_divide is
   generic (
      G_DEBUG : boolean := false
   );
   port (
      clk_i        : in  std_logic;
      n_i          : in  unsigned(31 downto 0);
      d_i          : in  unsigned(31 downto 0);
      q_o          : out unsigned(63 downto 0);
      start_over_i : in  std_logic;
      busy_o       : out std_logic := '0'
   );
end entity fast_divide;

architecture wattle_and_daub of fast_divide is

   type state_t is (IDLE_ST, STEP_ST, OUTPUT_ST);
   signal state : state_t := IDLE_ST;
   signal steps_remaining : integer range 0 to 5 := 0;

   signal dd : unsigned(35 downto 0) := to_unsigned(0,36);
   signal nn : unsigned(67 downto 0) := to_unsigned(0,68);

   pure function count_leading_zeros(arg : unsigned(31 downto 0)) return natural is
   begin
      for i in 0 to 31 loop
         if arg(31-i) = '1' then
            return i;
         end if;
      end loop;
      return 0;
   end function count_leading_zeros;

begin

   process (clk_i) is
      variable temp64 : unsigned( 73 downto 0) := to_unsigned(0,74);
      variable temp96 : unsigned(105 downto 0) := to_unsigned(0,106);
      variable f      : unsigned( 37 downto 0) := to_unsigned(0,38);
      variable leading_zeros : natural range 0 to 31;
      variable new_dd : unsigned( 35 downto 0);
      variable new_nn : unsigned( 67 downto 0);
   begin
      if rising_edge(clk_i) then
         if G_DEBUG then
            report "state is " & state_t'image(state);
         end if;
         -- only for vunit test
         -- report "q$" & to_hstring(q) & " = n$" & to_hstring(n) & " / d$" & to_hstring(d);
         case state is
            when IDLE_ST =>
               -- Deal with divide by zero
               if dd = to_unsigned(0,36) then
                  q_o <= (others => '1');
                  busy_o <= '0';
               end if;

            when STEP_ST =>
               if G_DEBUG then
                  report "nn=$" & to_hstring(nn(67 downto 36)) & "." & to_hstring(nn(35 downto 4)) & "." & to_hstring(nn(3 downto 0))
                  & " / $" & to_hstring(dd(35 downto 4)) & "." & to_hstring(dd(3 downto 0));
               end if;

               -- f = 2 - dd
               f := to_unsigned(0,38);
               f(37) := '1';
               f := f - dd;
               if G_DEBUG then
                  report "f = $" & to_hstring(f);
               end if;

               -- Now multiply both nn and dd by f
               temp96 := nn * f;
               nn <= temp96(103 downto 36);
               if G_DEBUG then
                  report "temp96=$" & to_hstring(temp96);
               end if;

               temp64 := dd * f;
               dd <= temp64(71 downto 36);
               if G_DEBUG then
                  report "temp64=$" & to_hstring(temp64);
               end if;

               -- Perform number of required steps, or abort early if we can
               if steps_remaining /= 0 and dd /= x"FFFFFFFFF" then
                  steps_remaining <= steps_remaining - 1;
               else
                  state <= OUTPUT_ST;
               end if;

            when OUTPUT_ST =>
               -- No idea why we need to add one, but we do to stop things like 4/2
               -- giving a result of 1.999999999
               temp64(67 downto  0) := nn;
               temp64(73 downto 68) := (others => '0');
               temp64 := temp64 + 7;
               if G_DEBUG then
                  report "temp64=$" & to_hstring(temp64);
               end if;
               busy_o <= '0';
               q_o <= temp64(67 downto 4);
               state <= IDLE_ST;

         end case;

         if start_over_i = '1' and d_i /= to_unsigned(0,32) then
            if G_DEBUG then
               report "Calculating $" & to_hstring(n_i) & " / $" & to_hstring(d_i);
            end if;

            leading_zeros := count_leading_zeros(d_i);
            new_dd := (others => '0');
            new_dd(35 downto 4+leading_zeros) := d_i(31-leading_zeros downto 0);
            new_nn := (others => '0');
            new_nn(35+leading_zeros downto 4+leading_zeros) := n_i;
            if G_DEBUG then
               report "Normalised to $" & to_hstring(new_nn(67 downto 36)) & "." &
               to_hstring(new_nn(35 downto 4)) & "." & to_hstring(new_nn(3 downto 0))
               & " / $" & to_hstring(new_dd(35 downto 4)) & "." & to_hstring(new_dd(3 downto 0));
            end if;
            dd <= new_dd;
            nn <= new_nn;
            state <= STEP_ST;

            steps_remaining <= 5;
            busy_o <= '1';
         elsif start_over_i = '1' then
            if G_DEBUG then
               report "Ignoring divide by zero";
            end if;
         end if;

      end if;
   end process;
end architecture wattle_and_daub;

