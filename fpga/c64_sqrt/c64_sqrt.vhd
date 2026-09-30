library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-- This module takes a floating point number (s_exp_i, s_mant_i) and returns
-- the square root as a floating point number (m_exp_o, m_mant_o).
--
-- It calculates one extra bit in order to perform the correct rounding.
--
-- Input and output are given in C64 floating point format (5-byte).
-- * exp is the exponent byte.
-- * mant is the mantissa (must be normalized).
-- Example values
-- Value |  Exp | Mantissa
--   0.0 | 0x00 |   XXXXXXXX
--   0.5 | 0x80 | 0x00000000
--   1.0 | 0x81 | 0x00000000
--  -1.0 | 0x81 | 0x80000000
-- See also: https://www.c64-wiki.com/wiki/Floating_point_arithmetic
--
-- The algorithm is taken from
-- https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2).
--
-- Interface:
-- The input is accepted when s_valid_i and s_ready_o are both asserted on the
-- same clock edge. The result is presented when m_valid_o is asserted, and is
-- held stable until m_ready_i is asserted. None of the output signals depend
-- combinatorially on any of the input signals. rst_i is a synchronous reset
-- (active high). It clears m_valid_o, and abandons a calculation in progress.
--
-- If the input is negative, m_error_o is set, and the result is zero. If the
-- input is zero, the result is zero.
--
-- Latency and throughput:
-- m_valid_o is asserted 34 clock cycles after the input is accepted (1 clock
-- cycle for a negative or zero input). The result is written to a separate
-- output register, so in the clock cycle where the result is written, a new
-- input is accepted provided the output register is empty. So if m_ready_i is
-- constantly asserted, a new input is accepted every 34 clock cycles.

entity c64_sqrt is
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;

      -- Input
      s_valid_i : in  std_logic;
      s_ready_o : out std_logic;
      s_exp_i   : in  std_logic_vector( 7 downto 0);   -- Exponent
      s_mant_i  : in  std_logic_vector(31 downto 0);   -- Mantissa

      -- Output
      m_valid_o : out std_logic;
      m_ready_i : in  std_logic;
      m_exp_o   : out std_logic_vector( 7 downto 0);   -- Exponent
      m_mant_o  : out std_logic_vector(31 downto 0);   -- Mantissa
      m_error_o : out std_logic                        -- The input was negative
   );
end entity c64_sqrt;

architecture synthesis of c64_sqrt is

   -- IDLE_ST : Waiting for a new input.
   -- CALC_ST : Calculation in progress, one bit in each clock cycle.
   -- DONE_ST : The result is ready. It is written to the output register as
   --           soon as the output register is free.
   type   state_type is (IDLE_ST, CALC_ST, DONE_ST);
   signal state : state_type := IDLE_ST;

   signal val  : unsigned(33 downto 0);
   signal mant : unsigned(33 downto 0);
   signal mask : unsigned(33 downto 0);

   -- The exponent of the result, and whether the input is negative
   signal exp : unsigned(7 downto 0);
   signal neg : std_logic;

begin

   -- Accept a new input when idle, or when the result is written to the
   -- output register
   s_ready_o <= '1' when state = IDLE_ST or (state = DONE_ST and m_valid_o = '0') else
                '0';

   fsm_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' then
            m_valid_o <= '0';
         end if;

         case state is

            when IDLE_ST =>
               null;

            when CALC_ST =>
               if val >= (mant or ("0" & mask(33 downto 1))) then
                  val(33 downto 1) <= val(32 downto 0) - (mant(32 downto 0) or mask(33 downto 1));
                  val(0)           <= '0';
                  mant             <= mant or mask;
               else
                  val <= val(32 downto 0) & "0";
               end if;
               mask <= "0" & mask(33 downto 1);

               if mask(0) = '1' then
                  state <= DONE_ST;
               end if;

            when DONE_ST =>
               -- Wait until the output register is free. The extra bit
               -- mant(0) rounds the result to nearest.
               if m_valid_o = '0' or m_ready_i = '1' then
                  if mant(0) = '0' then
                     m_mant_o <= "0" & std_logic_vector(mant(31 downto 1));
                  else
                     m_mant_o <= "0" & std_logic_vector(mant(31 downto 1) + 1);
                  end if;
                  m_exp_o   <= std_logic_vector(exp);
                  m_error_o <= neg;
                  m_valid_o <= '1';
                  state     <= IDLE_ST;
               end if;

         end case;

         -- This takes priority over the state machine above
         if s_valid_i = '1' and s_ready_o = '1' then
            val <= (others => '0');
            if s_exp_i(0) = '0' then
               val(32 downto 1) <= unsigned(s_mant_i) or X"80000000";
               exp              <= ("0" & unsigned(s_exp_i(7 downto 1))) + X"40";
            else
               val(31 downto 0) <= unsigned(s_mant_i) or X"80000000";
               exp              <= ("0" & unsigned(s_exp_i(7 downto 1))) + X"41";
            end if;
            mant     <= (others => '0');
            mask     <= (others => '0');
            mask(32) <= '1';
            neg      <= s_mant_i(31);

            if s_mant_i(31) = '1' or s_exp_i = X"00" then
               -- The result is zero, since mant is zero
               exp   <= X"00";
               state <= DONE_ST;
            else
               state <= CALC_ST;
            end if;
         end if;

         if rst_i = '1' then
            m_valid_o <= '0';
            state     <= IDLE_ST;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;
