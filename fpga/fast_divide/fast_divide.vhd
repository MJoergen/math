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

architecture synthesis of fast_divide is

   type   state_type is (IDLE_ST, STEP_ST, OUTPUT_ST);
   signal state           : state_type := IDLE_ST;
   signal steps_remaining : integer range 0 to 5 := 0;

   signal dd : unsigned(35 downto 0) := to_unsigned(0, 36);
   signal nn : unsigned(67 downto 0) := to_unsigned(0, 68);

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

   fsm_proc : process (clk_i)
      variable temp64_v        : unsigned( 73 downto 0) := to_unsigned(0, 74);
      variable temp96_v        : unsigned(105 downto 0) := to_unsigned(0, 106);
      variable f_v             : unsigned( 37 downto 0) := to_unsigned(0, 38);
      variable leading_zeros_v : natural range 0 to 31;
      variable new_dd_v        : unsigned( 35 downto 0);
      variable new_nn_v        : unsigned( 67 downto 0);
   begin
      if rising_edge(clk_i) then
         if G_DEBUG then
            report "state is " & state_type'image(state);
         end if;
         -- only for vunit test
         -- report "q$" & to_hstring(q) & " = n$" & to_hstring(n) & " / d$" & to_hstring(d);
         case state is
            when IDLE_ST =>
               -- Deal with divide by zero
               if dd = to_unsigned(0, 36) then
                  q_o    <= (others => '1');
                  busy_o <= '0';
               end if;

            when STEP_ST =>
               if G_DEBUG then
                  report "nn=$" & to_hstring(nn(67 downto 36)) & "." & to_hstring(nn(35 downto 4)) & "." & to_hstring(nn(3 downto 0))
                         & " / $" & to_hstring(dd(35 downto 4)) & "." & to_hstring(dd(3 downto 0));
               end if;

               -- f = 2 - dd
               f_v     := to_unsigned(0, 38);
               f_v(37) := '1';
               f_v     := f_v - dd;
               if G_DEBUG then
                  report "f = $" & to_hstring(f_v);
               end if;

               -- Now multiply both nn and dd by f
               temp96_v := nn * f_v;
               nn       <= temp96_v(103 downto 36);
               if G_DEBUG then
                  report "temp96=$" & to_hstring(temp96_v);
               end if;

               temp64_v := dd * f_v;
               dd       <= temp64_v(71 downto 36);
               if G_DEBUG then
                  report "temp64=$" & to_hstring(temp64_v);
               end if;

               -- Perform number of required steps, or abort early if we can
               if steps_remaining /= 0 and dd /= X"FFFFFFFFF" then
                  steps_remaining <= steps_remaining - 1;
               else
                  state <= OUTPUT_ST;
               end if;

            when OUTPUT_ST =>
               -- No idea why we need to add one, but we do to stop things like 4/2
               -- giving a result of 1.999999999
               temp64_v(67 downto  0) := nn;
               temp64_v(73 downto 68) := (others => '0');
               temp64_v               := temp64_v + 7;
               if G_DEBUG then
                  report "temp64=$" & to_hstring(temp64_v);
               end if;
               busy_o <= '0';
               q_o    <= temp64_v(67 downto 4);
               state  <= IDLE_ST;

         end case;

         if start_over_i = '1' and d_i /= to_unsigned(0, 32) then
            if G_DEBUG then
               report "Calculating $" & to_hstring(n_i) & " / $" & to_hstring(d_i);
            end if;

            leading_zeros_v                                       := count_leading_zeros(d_i);
            new_dd_v                                              := (others => '0');
            new_dd_v(35 downto 4+leading_zeros_v)                 := d_i(31-leading_zeros_v downto 0);
            new_nn_v                                              := (others => '0');
            new_nn_v(35+leading_zeros_v downto 4+leading_zeros_v) := n_i;
            if G_DEBUG then
               report "Normalised to $" & to_hstring(new_nn_v(67 downto 36)) & "." &
                      to_hstring(new_nn_v(35 downto 4)) & "." & to_hstring(new_nn_v(3 downto 0))
                      & " / $" & to_hstring(new_dd_v(35 downto 4)) & "." & to_hstring(new_dd_v(3 downto 0));
            end if;
            dd    <= new_dd_v;
            nn    <= new_nn_v;
            state <= STEP_ST;

            steps_remaining <= 5;
            busy_o          <= '1';
         elsif start_over_i = '1' then
            if G_DEBUG then
               report "Ignoring divide by zero";
            end if;
         end if;

      end if;
   end process fsm_proc;

end architecture synthesis;

