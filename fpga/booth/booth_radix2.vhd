library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-- This multiplies two signed (two's complement) numbers using Booth's
-- algorithm with radix 2, see
-- https://en.wikipedia.org/wiki/Booth%27s_multiplication_algorithm
--
-- This is the radix 2 counterpart of booth.vhd (radix 4), for comparison. It
-- has the same interface, the same output register, and the same single-adder
-- structure. Only the parts that depend on the radix are different. See
-- "Radix 2 versus radix 4" in ALGORITHM.md.
--
-- Latency and throughput:
-- The calculation takes one clock cycle per bit, i.e. G_DATA_SIZE clock
-- cycles. If m_ready_i is constantly high, a new pair of inputs is accepted
-- every G_DATA_SIZE clock cycles (for G_DATA_SIZE >= 2).
--
-- Theory of operation:
-- Let M be the multiplicand (s_a_i) and Q be the multiplier (s_b_i). A
-- working register is formed by concatenating P (the partial product,
-- initially zero), Q, and an extra bit Q(-1) (initially zero):
--
--   prod = P & Q & Q(-1)
--
-- In each of G_DATA_SIZE iterations, the two least significant bits Q(0) and
-- Q(-1) are examined:
--   "01"         : P := P + M
--   "10"         : P := P - M
--   "00" or "11" : No change
-- Then the entire register is shifted one bit to the right (arithmetic
-- shift). After G_DATA_SIZE iterations the product is the low 2*G_DATA_SIZE
-- bits of P & Q.
--
-- P is one bit wider than M, so that the operation P - M does not overflow
-- when M is the most negative number, i.e. -2^(G_DATA_SIZE-1).

entity booth_radix2 is
   generic (
      G_DATA_SIZE : positive := 16
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;

      -- Input
      s_valid_i : in  std_logic;
      s_ready_o : out std_logic;
      s_a_i     : in  std_logic_vector(G_DATA_SIZE - 1 downto 0);      -- Multiplicand (signed)
      s_b_i     : in  std_logic_vector(G_DATA_SIZE - 1 downto 0);      -- Multiplier (signed)

      -- Output
      m_valid_o : out std_logic;
      m_ready_i : in  std_logic;
      m_res_o   : out std_logic_vector(2 * G_DATA_SIZE - 1 downto 0)   -- Product (signed)
   );
end entity booth_radix2;

architecture synthesis of booth_radix2 is

   -- Number of iterations
   constant C_ITERS : positive := G_DATA_SIZE;

   -- Size of the multiplier Q
   constant C_Q_SIZE : positive := G_DATA_SIZE;

   -- Size of the partial product P
   constant C_P_SIZE : positive := G_DATA_SIZE + 1;

   -- IDLE_ST : Waiting for new inputs.
   -- BUSY_ST : Calculation in progress. If the output register is still
   --           occupied in the last iteration, the calculation waits there,
   --           so that the output register is always loaded directly from
   --           the adder.
   type   state_type is (IDLE_ST, BUSY_ST);
   signal state : state_type := IDLE_ST;

   -- Number of remaining iterations
   signal count : natural range 1 to C_ITERS;

   -- Set in the last iteration, i.e. when count = 1. This is a separate
   -- register, so that s_ready_o does not depend on the comparison of count.
   signal last : std_logic;

   -- Sign-extended multiplicand M
   signal mcand : signed(C_P_SIZE - 1 downto 0);

   -- Working register P & Q & Q(-1)
   signal prod : signed(C_P_SIZE + C_Q_SIZE downto 0);

   -- The operand and the carry input for the current iteration, i.e.
   -- booth_opd(prod, mcand). This is calculated one clock cycle in advance,
   -- so that the adder only depends on registers next to it. This is possible
   -- because the bits of Q that select the operand are never changed by the
   -- adder.
   signal opd : signed(C_P_SIZE downto 0);

   -- The operand of an iteration of Booth's algorithm, as selected by the
   -- least significant bits of the working register. To make sure only a
   -- single adder is synthesized, the operand (0 or M) is selected first,
   -- and subtraction is performed by inverting the operand and setting the
   -- carry input. The carry input is appended as the LSB.
   pure function booth_opd (
      arg_prod  : signed(C_P_SIZE + C_Q_SIZE downto 0);
      arg_mcand : signed(C_P_SIZE - 1 downto 0)
   ) return signed is
      variable opd_v : signed(C_P_SIZE - 1 downto 0);
      variable sub_v : std_logic;
   begin
      case std_logic_vector(arg_prod(1 downto 0)) is

         when "01" | "10" =>
            opd_v := arg_mcand;

         when others =>
            opd_v := (others => '0');

      end case;

      -- Subtract when Q(0) = '1'. For "11" this gives P - 0, which is fine.
      sub_v := arg_prod(1);
      if sub_v = '1' then
         opd_v := not opd_v;
      end if;

      return opd_v & sub_v;
   end function booth_opd;

   -- Perform a single iteration of Booth's algorithm, with the operand from
   -- booth_opd.
   pure function booth_step (
      arg_prod : signed(C_P_SIZE + C_Q_SIZE downto 0);
      arg_opd  : signed(C_P_SIZE downto 0)
   ) return signed is
      variable p_v   : signed(C_P_SIZE - 1 downto 0);
      variable sum_v : signed(C_P_SIZE downto 0);
   begin
      p_v := arg_prod(C_P_SIZE + C_Q_SIZE downto C_Q_SIZE + 1);

      -- The appended LSB of P and the carry input appended to the operand
      -- give P + operand + carry input
      sum_v := (p_v & '1') + arg_opd;
      p_v   := sum_v(C_P_SIZE downto 1);

      return shift_right(p_v & arg_prod(C_Q_SIZE downto 0), 1);
   end function booth_step;

   -- Extract the product from the working register. The top bit of P is just
   -- sign extension, and Q(-1) is not part of the product.
   pure function get_result (
      arg_prod : signed(C_P_SIZE + C_Q_SIZE downto 0)
   ) return std_logic_vector is
   begin
      return std_logic_vector(arg_prod(2 * G_DATA_SIZE downto 1));
   end function get_result;

begin

   -- Accept new inputs when idle, or in the last iteration if the output
   -- register is empty (because then the current product is guaranteed to be
   -- moved to the output register).
   s_ready_o <= '1' when state = IDLE_ST or (state = BUSY_ST and last = '1' and m_valid_o = '0') else
                '0';

   fsm_proc : process (clk_i)
      variable prod_v  : signed(C_P_SIZE + C_Q_SIZE downto 0);
      variable mcand_v : signed(C_P_SIZE - 1 downto 0);
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' then
            m_valid_o <= '0';
         end if;

         case state is

            when IDLE_ST =>
               null;

            when BUSY_ST =>
               prod_v := booth_step(prod, opd);

               if last = '0' then
                  prod  <= prod_v;
                  opd   <= booth_opd(prod_v, mcand);
                  count <= count - 1;
                  if count = 2 then
                     last <= '1';
                  end if;
               elsif m_valid_o = '0' or m_ready_i = '1' then
                  -- The last iteration. Otherwise wait here until the output
                  -- register is free. prod is not needed afterwards.
                  m_res_o   <= get_result(prod_v);
                  m_valid_o <= '1';
                  state     <= IDLE_ST;
               end if;

         end case;

         -- This takes priority over the state machine above
         if s_valid_i = '1' and s_ready_o = '1' then
            mcand_v                   := resize(signed(s_a_i), C_P_SIZE);
            prod_v                    := (others => '0');
            prod_v(C_Q_SIZE downto 1) := signed(s_b_i);
            mcand                     <= mcand_v;
            prod                      <= prod_v;
            opd                       <= booth_opd(prod_v, mcand_v);
            count                     <= C_ITERS;
            last                      <= '1' when C_ITERS = 1 else '0';
            state                     <= BUSY_ST;
         end if;

         if rst_i = '1' then
            m_valid_o <= '0';
            state     <= IDLE_ST;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;

