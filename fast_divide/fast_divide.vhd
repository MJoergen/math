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

   type state_t is (IDLE_ST, NORMALISE_ST, STEP_ST, PREOUTPUT_ST, OUTPUT_ST);
   signal state : state_t := IDLE_ST;
   signal steps_remaining : integer range 0 to 5 := 0;

   signal dd : unsigned(35 downto 0) := to_unsigned(0,36);
   signal nn : unsigned(67 downto 0) := to_unsigned(0,68);

begin

   process (clk_i) is
      variable temp64 : unsigned( 73 downto 0) := to_unsigned(0,74);
      variable temp96 : unsigned(105 downto 0) := to_unsigned(0,106);
      variable f      : unsigned( 37 downto 0) := to_unsigned(0,38);
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

            when NORMALISE_ST =>
               if dd(35)='1' then
                  if G_DEBUG then
                     report "Normalised to $" & to_hstring(nn(67 downto 36)) & "." & to_hstring(nn(35 downto 4)) & "." & to_hstring(nn(3 downto 0))
                     & " / $" & to_hstring(dd(35 downto 4)) & "." & to_hstring(dd(3 downto 0));
                  end if;
                  state <= STEP_ST;
               else
                  -- Normalise in not more than 5 cycles
                  if dd(35 downto 20)= to_unsigned(0,16) then
                     dd(35 downto 20) <= dd(19 downto 4);
                     dd(19 downto 0) <= (others => '0');
                     nn(67 downto 20) <= nn(51 downto 4);
                     nn(19 downto 0) <= (others => '0');
                  elsif dd(35 downto 28)= to_unsigned(0,8) then
                     dd(35 downto 12) <= dd(27 downto 4);
                     dd(11 downto 0) <= (others => '0');
                     nn(67 downto 12) <= nn(59 downto 4);
                     nn(11 downto 0) <= (others => '0');
                  elsif dd(35 downto 32) = to_unsigned(0,4) then
                     dd(35 downto 8) <= dd(31 downto 4);
                     dd(7 downto 0) <= (others => '0');
                     nn(67 downto 8) <= nn(63 downto 4);
                     nn(7 downto 0) <= (others => '0');
                  elsif dd(35 downto 34) = to_unsigned(0,2) then
                     dd(35 downto 6) <= dd(33 downto 4);
                     dd(5 downto 0) <= (others => '0');
                     nn(67 downto 6) <= nn(65 downto 4);
                     nn(5 downto 0) <= (others => '0');
                  elsif dd(35)='0' then
                     dd(35 downto 5) <= dd(34 downto 4);
                     dd(4 downto 0) <= (others => '0');
                     nn(67 downto 5) <= nn(66 downto 4);
                     nn(4 downto 0) <= (others => '0');
                  end if;
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
                  state <= PREOUTPUT_ST;
               end if;

            when PREOUTPUT_ST =>
               -- No idea why we need to add one, but we do to stop things like 4/2
               -- giving a result of 1.999999999
               temp64(67 downto  0) := nn;
               temp64(73 downto 68) := (others => '0');
               temp64 := temp64 + 1;
               if G_DEBUG then
                  report "temp64=$" & to_hstring(temp64);
               end if;
               state <= OUTPUT_ST;

            when OUTPUT_ST =>
               busy_o <= '0';
               q_o <= temp64(67 downto 4);
               state <= IDLE_ST;

         end case;

         if start_over_i = '1' and d_i /= to_unsigned(0,32) then
            if G_DEBUG then
               report "Calculating $" & to_hstring(n_i) & " / $" & to_hstring(d_i);
            end if;
            dd(35 downto 4) <= d_i;
            dd( 3 downto 0) <= (others => '0');
            nn(35 downto 4) <= n_i;
            nn( 3 downto 0) <= (others => '0');
            nn(67 downto 36) <= (others => '0');
            state <= NORMALISE_ST;
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

