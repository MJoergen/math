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
-- https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2),
-- in its non-restoring form, with G_STEPS iterations in each clock cycle, see
-- ALGORITHM.md.
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
-- m_valid_o is asserted 32/G_STEPS + 1 clock cycles after the input is
-- accepted, i.e. 9 clock cycles for G_STEPS = 4 (1 clock cycle for a negative
-- or zero input). The result is written to a separate output register, so in
-- the clock cycle where the result is written, a new input is accepted
-- provided the output register is empty. So if m_ready_i is constantly
-- asserted, a new input is accepted every 32/G_STEPS + 1 clock cycles.

entity c64_sqrt is
   generic (
      -- The number of iterations, i.e. bits of the root, in each clock cycle.
      -- 32 must be divisible by it, i.e. 1, 2, 4, 8, 16, or 32.
      G_STEPS : positive := 4
   );
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
   -- CALC_ST : Calculation in progress, G_STEPS bits in each clock cycle.
   -- DONE_ST : The result is ready. It is written to the output register as
   --           soon as the output register is free.
   type   state_type is (IDLE_ST, CALC_ST, DONE_ST);
   signal state : state_type := IDLE_ST;

   -- The digit-by-digit calculation, see ALGORITHM.md. The radicand x (in
   -- [0.25, 1)) is scaled by 2^34, and the root r = sqrt(x) (in [0.5, 1)) is
   -- calculated in mant, also scaled by 2^34, from bit 33 down to bit 1. Bit
   -- 33 is always set, so it is set when the input is accepted, and the other
   -- 32 bits are calculated G_STEPS at a time. mask holds the next bit to be
   -- calculated. val is twice the signed remainder of the previous iteration,
   -- which is negative if its bit was not set (non-restoring). mant(1) is the
   -- extra bit used for rounding, and bit 0 of mant and mask is needed for the
   -- last iteration.
   signal val  : signed(35 downto 0);
   signal mant : unsigned(34 downto 0);
   signal mask : unsigned(34 downto 0);

   -- The exponent of the result, and whether the input is negative
   signal exp : unsigned(7 downto 0);
   signal neg : std_logic;

begin

   assert 32 mod G_STEPS = 0
      report "G_STEPS must divide 32"
      severity failure;

   -- Accept a new input when idle, or when the result is written to the
   -- output register
   s_ready_o <= '1' when state = IDLE_ST or (state = DONE_ST and m_valid_o = '0') else
                '0';

   fsm_proc : process (clk_i)
      variable val_v  : signed(35 downto 0);
      variable mant_v : unsigned(34 downto 0);
      variable mask_v : unsigned(34 downto 0);
      variable diff_v : signed(35 downto 0);
      variable x_v    : unsigned(33 downto 0);
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' then
            m_valid_o <= '0';
         end if;

         case state is

            when IDLE_ST =>
               null;

            when CALC_ST =>
               val_v  := val;
               mant_v := mant;
               mask_v := mask;

               for i in 1 to G_STEPS loop
                  -- The bit is set if (r + mask)^2 <= x, i.e. if the remainder
                  -- x - r^2 - (2*r*mask + mask^2) is not negative. If the
                  -- previous bit was set (val >= 0), it is val - (mant | mask/2).
                  -- Otherwise val was not restored, and it is
                  -- val + (mant | mask | mask/2), see ALGORITHM.md.
                  if val_v >= 0 then
                     diff_v := val_v - signed("0" & (mant_v or ("0" & mask_v(34 downto 1))));
                  else
                     diff_v := val_v + signed("0" & (mant_v or mask_v or ("0" & mask_v(34 downto 1))));
                  end if;

                  if diff_v >= 0 then
                     mant_v := mant_v or mask_v;
                  end if;
                  val_v  := diff_v(34 downto 0) & "0";
                  mask_v := "0" & mask_v(34 downto 1);
               end loop;

               val  <= val_v;
               mant <= mant_v;
               mask <= mask_v;

               if mask(G_STEPS) = '1' then
                  state <= DONE_ST;
               end if;

            when DONE_ST =>
               -- Wait until the output register is free. The extra bit
               -- mant(1) rounds the result to nearest.
               if m_valid_o = '0' or m_ready_i = '1' then
                  if mant(1) = '0' then
                     m_mant_o <= "0" & std_logic_vector(mant(32 downto 2));
                  else
                     m_mant_o <= "0" & std_logic_vector(mant(32 downto 2) + 1);
                  end if;
                  m_exp_o   <= std_logic_vector(exp);
                  m_error_o <= neg;
                  m_valid_o <= '1';
                  state     <= IDLE_ST;
               end if;

         end case;

         -- This takes priority over the state machine above
         if s_valid_i = '1' and s_ready_o = '1' then
            -- The radicand x, scaled by 2^34
            x_v := (others => '0');
            if s_exp_i(0) = '0' then
               x_v(33 downto 2) := unsigned(s_mant_i) or X"80000000";
               exp              <= ("0" & unsigned(s_exp_i(7 downto 1))) + X"40";
            else
               x_v(32 downto 1) := unsigned(s_mant_i) or X"80000000";
               exp              <= ("0" & unsigned(s_exp_i(7 downto 1))) + X"41";
            end if;

            -- The first iteration: Since x >= 1/4, bit 33 (the 1/2) of the
            -- root is always set, and the remainder is x - 1/4.
            x_v      := x_v - shift_left(to_unsigned(1, 34), 32);
            val      <= signed("0" & x_v & "0");
            mant     <= (others => '0');
            mant(33) <= '1';
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
