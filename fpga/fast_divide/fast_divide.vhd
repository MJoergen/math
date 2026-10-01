library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-- This divides two 32-bit unsigned integers using Goldschmidt division, see
-- https://en.wikipedia.org/wiki/Division_algorithm#Goldschmidt_division
-- and README.md. The quotient is a 64-bit fixed-point number, with 32 integer
-- bits and 32 fractional bits.
--
-- Interface:
-- The inputs are accepted when s_valid_i and s_ready_o are both asserted on
-- the same clock edge. The quotient is presented when m_valid_o is asserted,
-- and is held stable until m_ready_i is asserted. None of the output signals
-- depend combinatorially on any of the input signals. rst_i is a synchronous
-- reset (active high). It clears m_valid_o, and abandons a calculation in
-- progress.
--
-- A division by zero gives a quotient of all ones (the largest value).
--
-- Latency and throughput:
-- m_valid_o is asserted at most 7 clock cycles after the inputs are accepted
-- (1 clock cycle for a division by zero). A new pair of inputs is accepted in
-- the clock cycle after the quotient is written to the output register.

entity fast_divide is
   generic (
      G_DEBUG : boolean := false
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;

      -- Input
      s_valid_i : in  std_logic;
      s_ready_o : out std_logic;
      s_n_i     : in  std_logic_vector(31 downto 0);   -- Numerator (unsigned)
      s_d_i     : in  std_logic_vector(31 downto 0);   -- Divisor (unsigned)

      -- Output
      m_valid_o : out std_logic;
      m_ready_i : in  std_logic;
      m_q_o     : out std_logic_vector(63 downto 0)    -- Quotient (32.32 fixed point)
   );
end entity fast_divide;

architecture synthesis of fast_divide is

   -- IDLE_ST   : Waiting for new inputs.
   -- STEP_ST   : The iterations, one in each clock cycle.
   -- OUTPUT_ST : The quotient is ready. It is written to the output register
   --             as soon as the output register is free.
   type   state_type is (IDLE_ST, STEP_ST, OUTPUT_ST);
   signal state           : state_type := IDLE_ST;
   signal steps_remaining : integer range 0 to 5 := 0;

   -- Set for a division by zero
   signal div_zero : std_logic;

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

   s_ready_o <= '1' when state = IDLE_ST else
                '0';

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

         if m_ready_i = '1' then
            m_valid_o <= '0';
         end if;

         case state is

            when IDLE_ST =>
               null;

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
               -- Wait until the output register is free
               if m_valid_o = '0' or m_ready_i = '1' then
                  -- Remove the 4 guard bits. Adding 7 (just below half of the last
                  -- bit) rounds to nearest, so that e.g. 4/2 does not give
                  -- 1.999999999, see "Rounding" in ALGORITHM.md.
                  temp64_v(67 downto  0) := nn;
                  temp64_v(73 downto 68) := (others => '0');
                  temp64_v               := temp64_v + 7;
                  if G_DEBUG then
                     report "temp64=$" & to_hstring(temp64_v);
                  end if;
                  if div_zero = '1' then
                     m_q_o <= (others => '1');
                  else
                     m_q_o <= std_logic_vector(temp64_v(67 downto 4));
                  end if;
                  m_valid_o <= '1';
                  state     <= IDLE_ST;
               end if;

         end case;

         -- This takes priority over the state machine above
         if s_valid_i = '1' and s_ready_o = '1' then
            if G_DEBUG then
               report "Calculating $" & to_hstring(s_n_i) & " / $" & to_hstring(s_d_i);
            end if;

            -- Shift both operands left by the number of leading zeros of
            -- the divisor (and by the 4 guard bits). The bits shifted out of
            -- the divisor are the leading zeros.
            leading_zeros_v := count_leading_zeros(unsigned(s_d_i));
            new_dd_v        := shift_left(resize(unsigned(s_d_i), 36), 4 + leading_zeros_v);
            new_nn_v        := shift_left(resize(unsigned(s_n_i), 68), 4 + leading_zeros_v);
            if G_DEBUG then
               report "Normalised to $" & to_hstring(new_nn_v(67 downto 36)) & "." &
                      to_hstring(new_nn_v(35 downto 4)) & "." & to_hstring(new_nn_v(3 downto 0))
                      & " / $" & to_hstring(new_dd_v(35 downto 4)) & "." & to_hstring(new_dd_v(3 downto 0));
            end if;
            dd    <= new_dd_v;
            nn    <= new_nn_v;
            state <= STEP_ST;

            steps_remaining <= 5;
            div_zero        <= '0';

            if s_d_i = X"00000000" then
               if G_DEBUG then
                  report "Divide by zero";
               end if;
               div_zero <= '1';
               state    <= OUTPUT_ST;
            end if;
         end if;

         if rst_i = '1' then
            m_valid_o <= '0';
            state     <= IDLE_ST;
         end if;

      end if;
   end process fsm_proc;

end architecture synthesis;

