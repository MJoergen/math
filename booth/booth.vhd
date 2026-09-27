library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-- This multiplies two signed (two's complement) numbers using Booth's algorithm (radix 4).
-- Both inputs are G_DATA_SIZE bits wide, and the product is 2*G_DATA_SIZE bits wide.
--
-- Interface:
-- The inputs are accepted when s_valid_i and s_ready_o are both asserted on the same clock edge.
-- The product is presented when m_valid_o is asserted, and is held stable until m_ready_i is asserted.
-- None of the output signals depend combinatorially on any of the input signals.
--
-- Latency and throughput:
-- The calculation takes one clock cycle per two bits, i.e. ceil(G_DATA_SIZE/2) clock cycles.
-- The product is written to a separate output register, so the calculation engine is free to
-- start on a new pair of inputs while the previous product is waiting to be consumed.
-- In the last clock cycle of a calculation, a new pair of inputs is accepted provided the output
-- register is empty. So if m_ready_i is constantly asserted, a new pair of inputs is accepted
-- every ceil(G_DATA_SIZE/2) clock cycles (for G_DATA_SIZE >= 3).
--
-- Theory of operation:
-- Let M be the multiplicand (a) and Q be the multiplier (b). If G_DATA_SIZE is odd, then Q is
-- sign-extended by one bit, so that it has an even number of bits.
-- A working register is formed by concatenating P (the partial product, initially zero), Q, and
-- an extra bit Q(-1) (initially zero):
--
--   prod = P & Q & Q(-1)
--
-- In each of ceil(G_DATA_SIZE/2) iterations, the three least significant bits Q(1), Q(0), and
-- Q(-1) are examined:
--   "001" or "010" : P := P + M
--   "011"          : P := P + 2M
--   "100"          : P := P - 2M
--   "101" or "110" : P := P - M
--   "000" or "111" : No change
-- Then the entire register is shifted two bits to the right (arithmetic shift).
-- After ceil(G_DATA_SIZE/2) iterations the product is found in P & Q.
--
-- P is two bits wider than M, so that the operation P - 2M does not overflow when M is the most
-- negative number, i.e. -2^(G_DATA_SIZE-1).

entity booth is
   generic (
      G_DATA_SIZE : positive := 16
   );
   port (
      clk_i     : in    std_logic;
      rst_i     : in    std_logic;

      -- Input
      s_valid_i : in    std_logic;
      s_ready_o : out   std_logic;
      s_a_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);      -- Multiplicand (signed)
      s_b_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);      -- Multiplier (signed)

      -- Output
      m_valid_o : out   std_logic;
      m_ready_i : in    std_logic;
      m_res_o   : out   std_logic_vector(2 * G_DATA_SIZE - 1 downto 0)   -- Product (signed)
   );
end entity booth;

architecture synthesis of booth is

   -- Number of iterations
   constant C_ITERS  : positive := (G_DATA_SIZE + 1) / 2;

   -- Size of the (possibly sign-extended) multiplier Q
   constant C_Q_SIZE : positive := 2 * C_ITERS;

   -- Size of the partial product P
   constant C_P_SIZE : positive := G_DATA_SIZE + 2;

   -- IDLE_ST : Waiting for new inputs.
   -- BUSY_ST : Calculation in progress.
   -- FULL_ST : Calculation finished, but the output register is still occupied.
   type     state_type is (IDLE_ST, BUSY_ST, FULL_ST);
   signal   state : state_type := IDLE_ST;

   -- Number of remaining iterations
   signal   count : natural range 0 to C_ITERS;

   -- Sign-extended multiplicand M
   signal   mcand : signed(C_P_SIZE - 1 downto 0);

   -- Working register P & Q & Q(-1)
   signal   prod : signed(C_P_SIZE + C_Q_SIZE downto 0);

   -- Perform a single iteration of Booth's algorithm.
   -- To make sure only a single adder is synthesized, the operand (0, M, or 2M) is selected
   -- first, and subtraction is performed by inverting the operand and setting the carry input.
   pure function booth_step (
      arg_prod  : signed(C_P_SIZE + C_Q_SIZE downto 0);
      arg_mcand : signed(C_P_SIZE - 1 downto 0)
   ) return signed is
      variable p_v   : signed(C_P_SIZE - 1 downto 0);
      variable opd_v : signed(C_P_SIZE - 1 downto 0);
      variable sub_v : std_logic;
      variable sum_v : signed(C_P_SIZE downto 0);
   begin
      p_v := arg_prod(C_P_SIZE + C_Q_SIZE downto C_Q_SIZE + 1);

      case std_logic_vector(arg_prod(2 downto 0)) is

         when "001" | "010" | "101" | "110" =>
            opd_v := arg_mcand;

         when "011" | "100" =>
            opd_v := shift_left(arg_mcand, 1);

         when others =>
            opd_v := (others => '0');

      end case;

      -- Subtract when Q(1) = '1'. For "111" this gives P - 0, which is fine.
      sub_v := arg_prod(2);
      if sub_v = '1' then
         opd_v := not opd_v;
      end if;

      -- The appended LSBs implement the carry input: This calculates P + opd_v + sub_v
      sum_v := (p_v & '1') + (opd_v & sub_v);
      p_v   := sum_v(C_P_SIZE downto 1);

      return shift_right(p_v & arg_prod(C_Q_SIZE downto 0), 2);
   end function booth_step;

   -- Extract the product from the working register.
   -- The upper bits of P are just sign extension, and Q(-1) is not part of the product.
   pure function get_result (
      arg_prod : signed(C_P_SIZE + C_Q_SIZE downto 0)
   ) return std_logic_vector is
   begin
      return std_logic_vector(arg_prod(2 * G_DATA_SIZE downto 1));
   end function get_result;

begin

   -- Accept new inputs when idle, or in the last iteration if the output register is empty
   -- (because then the current product is guaranteed to be moved to the output register).
   s_ready_o <= '1' when state = IDLE_ST or (state = BUSY_ST and count = 1 and m_valid_o = '0') else
                '0';

   fsm_proc : process (clk_i)
      variable prod_v : signed(C_P_SIZE + C_Q_SIZE downto 0);
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' then
            m_valid_o <= '0';
         end if;

         case state is

            when IDLE_ST =>
               null;

            when BUSY_ST =>
               prod_v := booth_step(prod, mcand);
               prod   <= prod_v;
               count  <= count - 1;

               if count = 1 then
                  if m_valid_o = '0' or m_ready_i = '1' then
                     m_res_o   <= get_result(prod_v);
                     m_valid_o <= '1';
                     state     <= IDLE_ST;
                  else
                     state <= FULL_ST;
                  end if;
               end if;

            when FULL_ST =>
               if m_valid_o = '0' or m_ready_i = '1' then
                  m_res_o   <= get_result(prod);
                  m_valid_o <= '1';
                  state     <= IDLE_ST;
               end if;

         end case;

         -- This takes priority over the state machine above
         if s_valid_i = '1' and s_ready_o = '1' then
            mcand                   <= resize(signed(s_a_i), C_P_SIZE);
            prod                    <= (others => '0');
            prod(C_Q_SIZE downto 1) <= resize(signed(s_b_i), C_Q_SIZE);
            count                   <= C_ITERS;
            state                   <= BUSY_ST;
         end if;

         if rst_i = '1' then
            m_valid_o <= '0';
            state     <= IDLE_ST;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;

