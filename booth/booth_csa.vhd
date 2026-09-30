library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-- This multiplies two signed (two's complement) numbers using Booth's
-- algorithm with radix 4, like booth.vhd, but with the partial product P in
-- carry-save form, and with G_DIGITS Booth digits (2*G_DIGITS bits of the
-- multiplier) in each clock cycle. So an iteration has no carry chain, and
-- the clock frequency hardly depends on G_DATA_SIZE. At the end, a
-- carry-select adder converts P from carry-save form to a normal binary
-- number, in two clock cycles.
--
-- Interface:
-- The same as booth.vhd.
--
-- Latency and throughput:
-- The calculation takes C_ITERS = ceil(G_DATA_SIZE/(2*G_DIGITS)) iterations,
-- followed by two clock cycles for the final addition. So the latency is
-- C_CYCLES = C_ITERS + 2 clock cycles. As in booth.vhd, a new pair of inputs
-- is accepted in the last clock cycle of a calculation, provided the output
-- register is empty. So if m_ready_i is constantly asserted, a new pair of
-- inputs is accepted every C_CYCLES clock cycles.
--
-- Theory of operation:
-- See booth.vhd for Booth's algorithm itself. With k = G_DIGITS, each
-- iteration adds k operands (0, +-M, or +-2M), with the operand j shifted 2*j
-- bits to the left, and then shifts P 2*k bits to the right. The multiplier Q
-- is sign-extended to C_Q_SIZE = 2*k*C_ITERS bits.
--
-- Carry-save form: P is kept as the sum of two vectors s and c. An iteration
-- reduces s, c, and the k operands (k+2 vectors) to two vectors with k 3:2
-- compressors (a full adder for each bit, without a carry chain), see
-- compress. Their upper bits are the new s and c, and their low 2*k bits
-- (lo_a and lo_b) are the finished bits of the product, except that they
-- still have to be added. This is done in the next clock cycle, with a 2*k
-- bit adder and the carry cy between these additions, and the result is
-- shifted into r at the top, see "Pipelining" below.
--
-- Bias: s and c cannot be sign-extended individually. So instead of P, the
-- non-negative number U = P + B is stored, with B = 2^(G_DATA_SIZE+1). Since
-- -B <= P < B, 0 <= U < 2B. Each operand is added with the bias 3B, which
-- makes it non-negative too. In total, the biases add
-- 3B*(1 + 4 + ... + 4^(k-1)) = (4^k - 1)*B, so the sum is P + operands +
-- 4^k*B, and shifting 2*k bits to the right gives the new P plus B again,
-- while the bits shifted out are the same as for P. So all the vectors are
-- non-negative numbers, and are simply shifted right, with zeros shifted in.
--
-- Subtraction: A negative operand is the inverted positive operand plus one
-- (the bit sub). For operand j, the one is added at bit 2*j. It is split into
-- 4^j - 1 (sub in all of the 2*j free bits below operand j) and 1 (sub in the
-- free LSB of the carry vector of compressor j).
--
-- Pipelining: The low bits of the product lag one clock cycle behind the
-- iteration that produced them, so that the adder for the low bits is not in
-- the same clock cycle as the compressors. So after the last iteration, the
-- remaining value is V = (s & lo_a) + (c & lo_b) + cy.
--
-- Final addition: The low C_V_SIZE bits of V are the remaining bits of the
-- product (the bias B is a multiple of 2^C_V_SIZE, so it disappears). They are
-- added by a carry-select adder, with blocks of G_CPA_SIZE bits:
-- * First clock cycle: Each block is added with the carry input 0 and 1,
--   giving the two sums sum0 and sum1, and their carry outputs g (generate) and
--   t (carry out if the carry input is 1).
-- * Second clock cycle: The carry input of each block is the carry into that
--   bit of the addition t + g (with one bit per block), since a block has a
--   carry out if it generates one, or if it has a carry input and passes it on.
--   Then each block selects sum0 or sum1. The first block has the carry
--   input cy, and needs no selection.
--
-- Timing: The wide registers are only controlled by registers (ready, s_en,
-- d1_en), which are calculated one clock cycle in advance. In particular,
-- their clock enables do not depend on the input handshake: They are loaded
-- with s_a_i and s_b_i whenever s_ready_o is high, even if s_valid_i is low
-- (the values are then just not used). The operands are also calculated one
-- clock cycle in advance (see opd).
--
-- G_CPA_SIZE: Each block of the final adder uses G_CPA_SIZE+1 bits of the
-- carry chain, including the carry out. So one less than a multiple of 4 (the
-- size of a CARRY4 cell) makes best use of it.

entity booth_csa is
   generic (
      G_DATA_SIZE : positive := 16;
      G_DIGITS    : positive := 4;  -- Booth digits in each clock cycle
      G_CPA_SIZE  : positive := 7   -- Block size of the final adder
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
end entity booth_csa;

architecture synthesis of booth_csa is

   -- Number of bits of Q in each iteration
   constant C_STEP     : positive := 2 * G_DIGITS;

   -- Number of iterations
   constant C_ITERS    : positive := (G_DATA_SIZE + C_STEP - 1) / C_STEP;

   -- Size of the (possibly sign-extended) multiplier Q
   constant C_Q_SIZE   : positive := C_STEP * C_ITERS;

   -- Total number of clock cycles
   constant C_CYCLES   : positive := C_ITERS + 2;

   -- Size of the partial product P (as a signed number), and of s and c
   constant C_P_SIZE   : positive := G_DATA_SIZE + 2;

   -- Size of the vectors in the compressors
   constant C_ROW_SIZE : positive := C_P_SIZE + C_STEP;

   -- Number of bits of V in the product, i.e. those not in r
   constant C_V_SIZE   : positive := 2 * G_DATA_SIZE - C_Q_SIZE + C_STEP;

   -- Number of blocks of the final adder
   constant C_BLOCKS   : positive := (C_V_SIZE + G_CPA_SIZE - 1) / G_CPA_SIZE;
   constant C_SUM_SIZE : positive := C_BLOCKS * G_CPA_SIZE;

   -- IDLE_ST : Waiting for new inputs.
   -- BUSY_ST : Calculation in progress. If the output register is still
   --           occupied in the last clock cycle, the calculation waits there.
   type     state_type is (IDLE_ST, BUSY_ST);
   signal   state : state_type := IDLE_ST;

   -- Number of remaining clock cycles
   signal   count : natural range 1 to C_CYCLES;

   -- Set in the first clock cycle of the final addition (count = 2), and in the
   -- last clock cycle (count = 1), which is the second one
   signal   d1   : std_logic;
   signal   last : std_logic;

   -- The same as s_ready_o. The datapath is loaded when this is set.
   signal   ready : std_logic := '1';

   -- The clock enables of the iteration registers (load and iteration), and of
   -- the registers of the final addition
   signal   s_en  : std_logic;
   signal   d1_en : std_logic;

   -- These control the wide registers. Vivado may replicate them, and it
   -- must use the clock enable input of the flip-flops for the enables.
   attribute max_fanout    : integer;
   attribute direct_enable : boolean;
   attribute max_fanout of ready    : signal is 32;
   attribute max_fanout of s_en     : signal is 32;
   attribute max_fanout of d1_en    : signal is 32;
   attribute direct_enable of s_en  : signal is true;
   attribute direct_enable of d1_en : signal is true;

   -- Sign-extended multiplicand M
   signal   mcand : signed(C_P_SIZE - 1 downto 0);

   -- The partial product in carry-save form. P + B is the sum of s and c, the
   -- not yet added low bits lo_a and lo_b of the previous iteration below
   -- them, and the carry cy of the previous addition of low bits.
   signal   s    : unsigned(C_P_SIZE - 1 downto 0);
   signal   c    : unsigned(C_P_SIZE - 1 downto 0);
   signal   lo_a : unsigned(C_STEP - 1 downto 0);
   signal   lo_b : unsigned(C_STEP - 1 downto 0);
   signal   cy   : std_logic;

   -- Q & Q(-1), with the low bits of the product shifted in at the top
   signal   r : std_logic_vector(C_Q_SIZE downto 0);

   -- The operands for the current iteration, calculated one clock cycle in
   -- advance, i.e. booth_opd(r, mcand, j) for each j
   type     opd_type is array (natural range <>) of unsigned(C_P_SIZE + 1 downto 0);
   signal   opd : opd_type(0 to G_DIGITS - 1);

   -- The first clock cycle of the final addition: For each block, the sums
   -- with carry input 0 and 1, and their carry outputs
   signal   sum0 : unsigned(C_SUM_SIZE - 1 downto 0);
   signal   sum1 : unsigned(C_SUM_SIZE - 1 downto 0);
   signal   g    : unsigned(C_BLOCKS - 1 downto 0);
   signal   t    : unsigned(C_BLOCKS - 1 downto 0);

   -- Operand j of an iteration of Booth's algorithm, as selected by bits
   -- 2*j+2 downto 2*j of r. See booth.vhd. The operand in two's complement
   -- (C_P_SIZE bits) is in the range -B to B-1. Inverting the MSB adds B, and
   -- prepending a '1' adds 2B, so the result is the operand plus 3B, as an
   -- unsigned number of C_P_SIZE+1 bits. The carry input (sub) is appended as
   -- the LSB.
   pure function booth_opd (
      arg_r     : std_logic_vector(C_Q_SIZE downto 0);
      arg_mcand : signed(C_P_SIZE - 1 downto 0);
      arg_j     : natural
   ) return unsigned is
      variable bits_v : std_logic_vector(2 downto 0);
      variable opd_v  : signed(C_P_SIZE - 1 downto 0);
      variable sub_v  : std_logic;
   begin
      bits_v := arg_r(2 * arg_j + 2 downto 2 * arg_j);

      case bits_v is

         when "001" | "010" | "101" | "110" =>
            opd_v := arg_mcand;

         when "011" | "100" =>
            opd_v := shift_left(arg_mcand, 1);

         when others =>
            opd_v := (others => '0');

      end case;

      -- Subtract when Q(1) = '1'. For "111" this gives P - 0, which is fine.
      sub_v := arg_r(2 * arg_j + 2);
      if sub_v = '1' then
         opd_v := not opd_v;
      end if;

      return '1' & not opd_v(C_P_SIZE - 1) & unsigned(opd_v(C_P_SIZE - 2 downto 0)) & sub_v;
   end function booth_opd;

   -- The operands of all digits for the next iteration, or for the first
   -- iteration
   pure function booth_opds (
      arg_r     : std_logic_vector(C_Q_SIZE downto 0);
      arg_mcand : signed(C_P_SIZE - 1 downto 0)
   ) return opd_type is
      variable res_v : opd_type(0 to G_DIGITS - 1);
   begin
      for j in 0 to G_DIGITS - 1 loop
         res_v(j) := booth_opd(arg_r, arg_mcand, j);
      end loop;
      return res_v;
   end function booth_opds;

   type     row_type is array (natural range <>) of unsigned(C_ROW_SIZE - 1 downto 0);

   -- Add s, c, and the operands, using G_DIGITS 3:2 compressors. The vectors
   -- form a queue: Each compressor takes the first three vectors, and appends
   -- its sum and carry vectors. This gives a balanced tree. The last two
   -- vectors are the result.
   pure function compress (
      arg_s   : unsigned(C_P_SIZE - 1 downto 0);
      arg_c   : unsigned(C_P_SIZE - 1 downto 0);
      arg_opd : opd_type(0 to G_DIGITS - 1)
   ) return row_type is
      variable q_v   : row_type(0 to 3 * G_DIGITS + 1);
      variable x_v   : unsigned(C_ROW_SIZE - 1 downto 0);
      variable y_v   : unsigned(C_ROW_SIZE - 1 downto 0);
      variable z_v   : unsigned(C_ROW_SIZE - 1 downto 0);
      variable sub_v : std_logic;
   begin
      q_v(0) := resize(arg_s, C_ROW_SIZE);
      q_v(1) := resize(arg_c, C_ROW_SIZE);

      -- Operand j, shifted 2*j bits to the left, with sub in the free bits
      -- below it
      for j in 0 to G_DIGITS - 1 loop
         sub_v      := arg_opd(j)(0);
         q_v(2 + j) := shift_left(resize(arg_opd(j)(C_P_SIZE + 1 downto 1), C_ROW_SIZE), 2 * j);
         for i in 0 to 2 * j - 1 loop
            q_v(2 + j)(i) := sub_v;
         end loop;
      end loop;

      -- Compressor j has sub of operand j in the free LSB of the carry vector
      for j in 0 to G_DIGITS - 1 loop
         x_v                      := q_v(3 * j);
         y_v                      := q_v(3 * j + 1);
         z_v                      := q_v(3 * j + 2);
         q_v(G_DIGITS + 2 + 2 * j) := x_v xor y_v xor z_v;
         q_v(G_DIGITS + 3 + 2 * j) := shift_left((x_v and y_v) or (x_v and z_v) or (y_v and z_v), 1);
         q_v(G_DIGITS + 3 + 2 * j)(0) := arg_opd(j)(0);
      end loop;

      return q_v(3 * G_DIGITS to 3 * G_DIGITS + 1);
   end function compress;

   -- A block of the final adder: arg_a + arg_b + arg_cin, with the carry out
   -- as the MSB. The carry input is appended to both operands as an LSB,
   -- where it gives a carry into the actual LSB if it is '1'.
   pure function add_cin (
      arg_a   : unsigned(G_CPA_SIZE - 1 downto 0);
      arg_b   : unsigned(G_CPA_SIZE - 1 downto 0);
      arg_cin : std_logic
   ) return unsigned is
      variable sum_v : unsigned(G_CPA_SIZE + 1 downto 0);
   begin
      sum_v := ('0' & arg_a & arg_cin) + ('0' & arg_b & arg_cin);
      return sum_v(G_CPA_SIZE + 1 downto 1);
   end function add_cin;

begin

   s_ready_o <= ready;

   fsm_proc : process (clk_i)
      variable state_v  : state_type;
      variable d1_v     : std_logic;
      variable last_v   : std_logic;
      variable ready_v  : std_logic;
      variable valid_v  : std_logic;
      variable rows_v   : row_type(0 to 1);
      variable low_v    : unsigned(C_STEP downto 0);
      variable r_v      : std_logic_vector(C_Q_SIZE downto 0);
      variable mcand_v  : signed(C_P_SIZE - 1 downto 0);
      variable va_v     : unsigned(C_SUM_SIZE - 1 downto 0);
      variable vb_v     : unsigned(C_SUM_SIZE - 1 downto 0);
      variable blk0_v   : unsigned(G_CPA_SIZE downto 0);
      variable blk1_v   : unsigned(G_CPA_SIZE downto 0);
      variable tg_v     : unsigned(C_BLOCKS downto 0);
      variable cin_v    : std_logic;
      variable v_v      : unsigned(C_SUM_SIZE - 1 downto 0);
      variable result_v : std_logic_vector(2 * G_DATA_SIZE - 1 downto 0);
   begin
      if rising_edge(clk_i) then
         ------------------
         -- Control
         ------------------

         -- The flags are updated together with count, from the current value
         -- of count, to avoid a comparison after the decrement.
         state_v := state;
         d1_v    := d1;
         last_v  := last;
         valid_v := m_valid_o;

         if m_ready_i = '1' then
            valid_v := '0';
         end if;

         if state = BUSY_ST then
            if last = '0' then
               count  <= count - 1;
               d1_v   := '1' when count = 3 else '0';
               last_v := '1' when count = 2 else '0';
            elsif m_valid_o = '0' or m_ready_i = '1' then
               -- The last clock cycle. Otherwise wait here until the output
               -- register is free.
               valid_v := '1';
               state_v := IDLE_ST;
            end if;
         end if;

         if s_valid_i = '1' and ready = '1' then
            count   <= C_CYCLES;
            d1_v    := '0';
            last_v  := '0';
            state_v := BUSY_ST;
         end if;

         if rst_i = '1' then
            valid_v := '0';
            state_v := IDLE_ST;
         end if;

         state     <= state_v;
         d1        <= d1_v;
         last      <= last_v;
         m_valid_o <= valid_v;

         -- Accept new inputs when idle, or in the last clock cycle if the
         -- output register is empty (because then the current product is
         -- guaranteed to be moved to the output register).
         ready_v := '1' when state_v = IDLE_ST or (last_v = '1' and valid_v = '0') else '0';
         ready   <= ready_v;

         -- The enables for the next clock cycle
         s_en  <= '1' when ready_v = '1' or (state_v = BUSY_ST and d1_v = '0' and last_v = '0') else '0';
         d1_en <= '1' when state_v = BUSY_ST and d1_v = '1' else '0';

         ------------------
         -- Iterations
         ------------------

         -- Add the low bits of the previous iteration, and shift them into r
         low_v := ('0' & lo_a) + ('0' & lo_b) + unsigned'(0 => cy);
         r_v   := std_logic_vector(low_v(C_STEP - 1 downto 0)) & r(C_Q_SIZE downto C_STEP);

         rows_v := compress(s, c, opd);

         -- The inputs, loaded when ready = '1'. They are only used if
         -- s_valid_i = '1'.
         mcand_v := resize(signed(s_a_i), C_P_SIZE);

         if ready = '1' then
            mcand <= mcand_v;
            opd   <= booth_opds(std_logic_vector(resize(signed(s_b_i), C_Q_SIZE)) & '0', mcand_v);
         elsif C_ITERS > 1 then
            -- Only used in the iterations. With a single iteration, the
            -- operands are only needed from the load, and r_v would already
            -- contain bits from the adder of the low bits.
            opd <= booth_opds(r_v, mcand);
         end if;

         if s_en = '1' then
            if ready = '1' then
               s               <= (others => '0');
               c               <= (others => '0');
               c(C_P_SIZE - 1) <= '1';                    -- The bias B
               lo_a            <= (others => '0');
               lo_b            <= (others => '0');
               cy              <= '0';
               r               <= std_logic_vector(resize(signed(s_b_i), C_Q_SIZE)) & '0';
            else
               s    <= rows_v(0)(C_ROW_SIZE - 1 downto C_STEP);
               c    <= rows_v(1)(C_ROW_SIZE - 1 downto C_STEP);
               lo_a <= rows_v(0)(C_STEP - 1 downto 0);
               lo_b <= rows_v(1)(C_STEP - 1 downto 0);
               cy   <= low_v(C_STEP);
               r    <= r_v;
            end if;
         end if;

         ------------------
         -- Final addition
         ------------------

         -- First clock cycle: The blocks, with carry input 0 and 1. The first
         -- block has the carry input cy.
         va_v := resize(s & lo_a, C_SUM_SIZE);
         vb_v := resize(c & lo_b, C_SUM_SIZE);

         -- The carry input is given as an extra LSB of both operands, so that
         -- the sums with carry input 0 and 1 are two separate adders. Otherwise
         -- Vivado calculates sum1 as sum0 + 1, after the carry chain.
         if d1_en = '1' then
            for b in 0 to C_BLOCKS - 1 loop
               if b = 0 then
                  blk0_v := add_cin(va_v(G_CPA_SIZE - 1 downto 0), vb_v(G_CPA_SIZE - 1 downto 0), cy);
                  blk1_v := blk0_v;
               else
                  blk0_v := add_cin(va_v(b * G_CPA_SIZE + G_CPA_SIZE - 1 downto b * G_CPA_SIZE),
                                    vb_v(b * G_CPA_SIZE + G_CPA_SIZE - 1 downto b * G_CPA_SIZE), '0');
                  blk1_v := add_cin(va_v(b * G_CPA_SIZE + G_CPA_SIZE - 1 downto b * G_CPA_SIZE),
                                    vb_v(b * G_CPA_SIZE + G_CPA_SIZE - 1 downto b * G_CPA_SIZE), '1');
               end if;
               sum0(b * G_CPA_SIZE + G_CPA_SIZE - 1 downto b * G_CPA_SIZE) <= blk0_v(G_CPA_SIZE - 1 downto 0);
               sum1(b * G_CPA_SIZE + G_CPA_SIZE - 1 downto b * G_CPA_SIZE) <= blk1_v(G_CPA_SIZE - 1 downto 0);
               g(b)                                                        <= blk0_v(G_CPA_SIZE);
               t(b)                                                        <= blk1_v(G_CPA_SIZE);
            end loop;
         end if;

         -- Second clock cycle: The carry input of each block, and the
         -- selection
         tg_v := ('0' & t) + ('0' & g);

         for b in 0 to C_BLOCKS - 1 loop
            cin_v := tg_v(b) xor t(b) xor g(b);
            if cin_v = '1' then
               v_v(b * G_CPA_SIZE + G_CPA_SIZE - 1 downto b * G_CPA_SIZE) :=
                  sum1(b * G_CPA_SIZE + G_CPA_SIZE - 1 downto b * G_CPA_SIZE);
            else
               v_v(b * G_CPA_SIZE + G_CPA_SIZE - 1 downto b * G_CPA_SIZE) :=
                  sum0(b * G_CPA_SIZE + G_CPA_SIZE - 1 downto b * G_CPA_SIZE);
            end if;
         end loop;

         result_v := std_logic_vector(v_v(C_V_SIZE - 1 downto 0)) & r(C_Q_SIZE downto C_STEP + 1);

         if state = BUSY_ST and last = '1' and (m_valid_o = '0' or m_ready_i = '1') then
            m_res_o <= result_v;
         end if;
      end if;
   end process fsm_proc;

end architecture synthesis;
