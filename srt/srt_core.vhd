library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

library work;
   use work.pla_pkg.all;

-- This divides two numbers using the SRT algorithm (with radix 4), see
-- https://en.wikipedia.org/wiki/Division_algorithm#SRT_division
-- and ALGORITHM.md. It is inspired by Ken Shirriff's analysis of the Pentium
-- division bug: https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html
--
-- Each iteration selects a quotient digit q in {-2, -1, 0, 1, 2} from a small
-- lookup table (the "PLA", see pla.vhd), and then updates the partial
-- remainder:
--    n := 4*(n - q*d)
-- The digit set is redundant, so the table only needs to look at the top few
-- bits of n and d, and an imprecise choice of q is corrected by later digits.
--
-- Number formats (G_SIZE bits, two's complement with 4 integer bits including
-- the sign, i.e. bit G_SIZE-4 has weight 1):
--   s_n_i    : The dividend. Must be normalized, i.e. the top nibble must be
--              "0001", so 1 <= s_n_i < 2. As a special case s_n_i = 0 is
--              allowed.
--   s_d_i    : The divisor. Must be normalized, so 1 <= s_d_i < 2.
--   n        : The partial remainder, n = n_s + n_c (see below). It stays
--              within |n/d| <= 8/3, see ALGORITHM.md. Formal verification
--              shows that -4.5 <= n < 4.5.
--   m_q_o    : Unsigned, with 2 integer bits and 2*G_SIZE+2 fractional bits.
--              The quotient digit from iteration k has weight 4^(-k). Since
--              1/2 < s_n_i/s_d_i < 2 the first digit is always 1 or 2
--              (unless s_n_i = 0).
--
-- The partial remainder is kept in carry-save form (see
-- https://en.wikipedia.org/wiki/Carry-save_adder), like in the Pentium: two
-- registers n_s (the sums) and n_c (the carries), with n = n_s + n_c. Then
-- n - q*d is calculated with a carry-save adder, i.e. each bit is a full
-- adder of n_s, n_c, and -q*d, without any carry chain. A positive q*d is
-- subtracted by adding its complement, and the 1 is added as the lowest bit
-- of the new carries, which is otherwise 0. For the table lookup only the top
-- 7 bits of n_s and n_c are added. This ignores the carries from the lower
-- bits, so the table may see n one row too low (1/8 less). The table in
-- pla.vhd allows for this, see there.
--
-- The divisor does not change during a division, so the thresholds of its
-- column of the table are stored in col when the division starts. Then each
-- iteration only compares the estimate of n against them, see pla.vhd.
--
-- The quotient digits are converted to an ordinary binary number on the fly,
-- without any carry chain: Two registers hold the quotient so far (quot) and
-- the quotient minus one unit of the last digit (quot_m1). A negative digit
-- q is then handled by appending (4 + q) to quot_m1, since
--    4*quot + q = 4*quot_m1 + (4 + q)
-- So each iteration only selects one of the two registers and appends two
-- bits. See the table in append_proc. This technique is described by
-- Ercegovac and Lang in "On-the-Fly Conversion of Redundant into Conventional
-- Representations", IEEE Transactions on Computers, 1987:
-- https://doi.org/10.1109/TC.1987.1676986
--
-- Each digit is first stored in the register digit, and only appended to
-- quot in the next iteration. This keeps the quotient registers (about 140
-- loads) off the output of the PLA, which is on the critical path. The
-- quotient m_q_o is quot with the stored digit appended, so it includes the
-- last digit as soon as the last iteration is done.
--
-- The generic G_PLA selects the quotient digit table:
--   "srt"           : pla.vhd (the default).
--   "pentium"       : pla_pentium.vhd, the original Pentium table with the
--                     FDIV bug.
--   "pentium_fixed" : pla_pentium.vhd, the fixed Pentium table.
-- With the Pentium tables the partial remainder has a larger range, see
-- pla_pentium.vhd. With the original Pentium table, this divider has the FDIV
-- bug (see https://en.wikipedia.org/wiki/Pentium_FDIV_bug), e.g. for
-- 4195835/3145727. The formal verification only covers pla.vhd.
-- The original Pentium table cannot be expressed with two thresholds per
-- column (it holds 0 above the q = 2 region), so the Pentium tables use a
-- lookup in the table instead. They are only meant for simulation.
--
-- Usage: Both ports use AXI-style handshaking (see
-- https://en.wikipedia.org/wiki/Advanced_eXtensible_Interface),
-- i.e. a value is transferred in a clock cycle where both valid and ready are
-- high.
-- * Input: Set s_valid_i together with s_n_i and s_d_i, and keep them
--   unchanged until s_ready_o is high. s_ready_o is only high when no
--   division is in progress, and the previous result has been taken.
-- * Output: m_valid_o is set together with the quotient m_q_o, G_SIZE+3
--   clock cycles after the input transfer. They stay unchanged until
--   m_ready_i is high.

entity srt_core is
   generic (
      G_SIZE  : natural;
      G_DEBUG : boolean;
      G_PLA   : string := "srt"
   );
   port (
      clk_i     : in    std_logic;

      -- Input
      s_valid_i : in    std_logic;
      s_ready_o : out   std_logic;
      s_n_i     : in    std_logic_vector(G_SIZE - 1 downto 0);     -- dividend (normalized)
      s_d_i     : in    std_logic_vector(G_SIZE - 1 downto 0);     -- divisor (normalized)

      -- Output
      m_valid_o : out   std_logic;
      m_ready_i : in    std_logic;
      m_q_o     : out   std_logic_vector(2 * G_SIZE + 3 downto 0)  -- quotient
   );
end entity srt_core;

architecture synthesis of srt_core is

   -- Number of quotient digits. Each digit is two bits, so this fills m_q_o.
   constant C_NUM_ITERS : natural                         := G_SIZE + 2;

   signal   iter : natural range 0 to C_NUM_ITERS - 1;

   -- The quotient digit selected by the PLA: its magnitude, and the digit
   -- itself (with the sign of the estimate of n)
   signal   pla_mag : mag_type;
   signal   pla_q   : integer range -2 to 2;

   -- The initial value of d, before the first division. Any normalized value
   -- will do. The initial value of col must match it, see f_col.
   function get_init_d return std_logic_vector is
      variable res_v : std_logic_vector(G_SIZE - 1 downto 0);
   begin
      res_v             := (others => '0');
      res_v(G_SIZE - 4) := '1';
      return res_v;
   end function get_init_d;

   constant C_INIT_D : std_logic_vector(G_SIZE - 1 downto 0) := get_init_d;

   -- The 4 bits of d that select the column of the table
   pure function get_d4 (
      arg_d : std_logic_vector(G_SIZE - 1 downto 0)
   ) return std_logic_vector is
   begin
      return arg_d(G_SIZE - 5 downto G_SIZE - 8);
   end function get_d4;

   -- The partial remainder in carry-save form, n = n_s + n_c
   signal   n_s   : std_logic_vector(G_SIZE - 1 downto 0) := (others => '0'); -- Sums
   signal   n_c   : std_logic_vector(G_SIZE - 1 downto 0) := (others => '0'); -- Carries

   -- The partial remainder as a single number. This is only used for
   -- verification (the assertions below, and srt_core.psl) and debugging. It
   -- is not used by the divider, so synthesis removes it.
   signal   n     : std_logic_vector(G_SIZE - 1 downto 0);

   -- The estimate of n that is used for the table lookup: The sum of the top
   -- 7 bits of n_s and n_c. The lower bits are zero.
   signal   n_est : std_logic_vector(G_SIZE - 1 downto 0);

   signal   d     : std_logic_vector(G_SIZE - 1 downto 0) := C_INIT_D;        -- Divisor
   signal   col   : col_type := get_col(get_d4(C_INIT_D));                     -- Column of d
   signal   quot    : std_logic_vector(2 * G_SIZE + 3 downto 0);              -- Quotient so far
   signal   quot_m1 : std_logic_vector(2 * G_SIZE + 3 downto 0);              -- quot - 1
   signal   digit   : integer range -2 to 2;                                  -- Not yet appended to quot

   -- quot and quot_m1 with digit appended
   signal   new_quot    : std_logic_vector(2 * G_SIZE + 3 downto 0);
   signal   new_quot_m1 : std_logic_vector(2 * G_SIZE + 3 downto 0);

   -- DONE_ST: The result is valid on m_q_o, and waits to be taken
   type     state_type is (IDLE_ST, BUSY_ST, DONE_ST);
   signal   state : state_type                            := IDLE_ST;

   -- The severity of the assertions in get_n. With the original Pentium table,
   -- the divider has the FDIV bug, so these invariants fail in rare divisions.
   -- Then they are only warnings, so the testbench can verify the wrong result.
   pure function get_severity return severity_level is
   begin
      if G_PLA = "pentium" then
         return warning;
      else
         return error;
      end if;
   end function get_severity;

   constant C_SEVERITY : severity_level := get_severity;

   -- Absolute value of a two's complement number
   pure function abs_slv (
      arg : std_logic_vector
   ) return std_logic_vector is
   begin
      if arg(arg'left) = '0' then
         return arg;
      else
         return 1 + not arg;
      end if;
   end function abs_slv;

   -- Calculate the next partial remainder 4*(n - q*d) in carry-save form,
   -- from n = arg_s + arg_c. The quotient digit q has the magnitude arg_mag
   -- (see pla.vhd), and it is negative if arg_neg is set. Returns the new sums
   -- and carries, concatenated.
   -- The assertions verify the invariants of the SRT algorithm, and are used
   -- during formal verification. They use the exact values of the partial
   -- remainder, which are not needed otherwise.
   pure function get_n (
      arg_s   : std_logic_vector(G_SIZE - 1 downto 0);
      arg_c   : std_logic_vector(G_SIZE - 1 downto 0);
      arg_d   : std_logic_vector(G_SIZE - 1 downto 0);
      arg_neg : std_logic;
      arg_mag : mag_type
   ) return std_logic_vector is
      variable mult_v  : std_logic_vector(G_SIZE - 1 downto 0);
      variable sub_v   : std_logic;
      variable y_v     : std_logic_vector(G_SIZE - 1 downto 0);
      variable cin_v   : std_logic;
      variable sum_v   : std_logic_vector(G_SIZE - 1 downto 0);
      variable carry_v : std_logic_vector(G_SIZE - 1 downto 0);
      variable arg_n_v : std_logic_vector(G_SIZE - 1 downto 0);
      variable tmp_v   : std_logic_vector(G_SIZE - 1 downto 0);
      variable tmp3_v  : std_logic_vector(G_SIZE + 1 downto 0);
      variable argn3_v : std_logic_vector(G_SIZE + 1 downto 0);
   begin
      arg_n_v := arg_s + arg_c;
      argn3_v := ("00" & abs_slv(arg_n_v)) + ("0" & abs_slv(arg_n_v) & "0");

      -- Verify that |n|/d < 8/3, i.e. 3*|n| < 8*d
      f_quotient_bound : assert argn3_v(G_SIZE + 1 downto G_SIZE) = "00" and
                                argn3_v(G_SIZE - 1 downto 0) < arg_d(G_SIZE - 4 downto 0) & "000"
         report "argn3_v=0x" & to_hstring(argn3_v) &
                ", arg_n_v=0x" & to_hstring(arg_n_v) &
                ", arg_d=0x" & to_hstring(arg_d)
         severity C_SEVERITY;

      -- Calculate |q|*d. Multiplying by 2 is just a shift.
      if arg_mag(1) = '1' then
         mult_v := arg_d(G_SIZE - 2 downto 0) & "0";
      elsif arg_mag(0) = '1' then
         mult_v := arg_d;
      else
         mult_v := (others => '0');
      end if;

      -- The value y = -q*d to add, i.e. y = |q|*d for a negative q. For a
      -- positive q, -q*d = not(|q|*d) + 1, where the 1 is added as cin_v. For
      -- q = 0, y = 0 (and not "all ones plus one"), so that the sums and
      -- carries are the same as in the model srt.py. The table lookup only
      -- sees the top bits of the sums and carries, so they must match the
      -- model exactly, and not just their sum.
      sub_v := not arg_neg and arg_mag(0);
      y_v   := mult_v xor (mult_v'range => sub_v);
      cin_v := sub_v;

      -- Carry-save adder: n - q*d = sum_v + carry_v
      sum_v   := arg_s xor arg_c xor y_v;
      carry_v := (arg_s and arg_c) or (arg_s and y_v) or (arg_c and y_v);
      carry_v := carry_v(G_SIZE - 2 downto 0) & cin_v;

      if G_DEBUG then
         report "get_n: sum_v=0x" & to_hstring(sum_v) & ", carry_v=0x" & to_hstring(carry_v);
      end if;

      tmp_v  := sum_v + carry_v;
      tmp3_v := ("00" & abs_slv(tmp_v)) + ("0" & abs_slv(tmp_v) & "0");

      -- Verify that |n - q*d| < 4/3, i.e. 3*|n - q*d| < 4.
      -- This follows from |n - q*d| <= 2/3*d and d < 2.
      f_remainder_bound : assert tmp3_v(G_SIZE + 1 downto G_SIZE - 2) = "0000"
         report "tmp_v=0x" & to_hstring(tmp_v) &
                ", tmp3_v=0x" & to_hstring(tmp3_v) &
                ", arg_d=0x" & to_hstring(arg_d)
         severity C_SEVERITY;

      -- Verify that |n - q*d| < 2, so that multiplying by 4 does not overflow.
      f_no_overflow : assert tmp_v(G_SIZE - 1 downto G_SIZE - 3) = "000" or
                             tmp_v(G_SIZE - 1 downto G_SIZE - 3) = "111"
         report "tmp_v=0x" & to_hstring(tmp_v)
         severity C_SEVERITY;

      -- Multiply by 4. The sums and carries may overflow individually, but
      -- their sum n is correct modulo 2^G_SIZE, which is all that matters.
      return sum_v(G_SIZE - 3 downto 0) & "00" & carry_v(G_SIZE - 3 downto 0) & "00";
   end function get_n;

begin

   s_ready_o <= '1' when state = IDLE_ST else
                '0';
   m_valid_o <= '1' when state = DONE_ST else
                '0';

   n     <= n_s + n_c;
   n_est <= (n_s(G_SIZE - 1 downto G_SIZE - 7) + n_c(G_SIZE - 1 downto G_SIZE - 7)) &
            (G_SIZE - 8 downto 0 => '0');

   -- Append the stored quotient digit q (on-the-fly conversion). The new
   -- values are 4*quot + q and 4*quot + q - 1, where
   -- 4*quot = quot & "00", and 4*quot = quot_m1 & "00" + 4.
   --    q  | new quot       | new quot_m1
   --    2  | quot    & "10" | quot    & "01"
   --    1  | quot    & "01" | quot    & "00"
   --    0  | quot    & "00" | quot_m1 & "11"
   --   -1  | quot_m1 & "11" | quot_m1 & "10"
   --   -2  | quot_m1 & "10" | quot_m1 & "01"
   append_proc : process (all)
      variable quot_v    : std_logic_vector(2 * G_SIZE + 1 downto 0);
      variable quot_m1_v : std_logic_vector(2 * G_SIZE + 1 downto 0);
   begin
      quot_v    := quot(2 * G_SIZE + 1 downto 0);
      quot_m1_v := quot_m1(2 * G_SIZE + 1 downto 0);

      case digit is

         when 2 =>
            new_quot    <= quot_v & "10";
            new_quot_m1 <= quot_v & "01";

         when 1 =>
            new_quot    <= quot_v & "01";
            new_quot_m1 <= quot_v & "00";

         when -1 =>
            new_quot    <= quot_m1_v & "11";
            new_quot_m1 <= quot_m1_v & "10";

         when -2 =>
            new_quot    <= quot_m1_v & "10";
            new_quot_m1 <= quot_m1_v & "01";

         when others =>
            new_quot    <= quot_v & "00";
            new_quot_m1 <= quot_m1_v & "11";

      end case;

   end process append_proc;

   -- After the last iteration, digit holds the last digit, and quot holds
   -- all the digits before it.
   m_q_o <= new_quot;

   srt_core_proc : process (clk_i)
      variable next_v : std_logic_vector(2 * G_SIZE - 1 downto 0);
   begin
      if rising_edge(clk_i) then

         case state is

            when IDLE_ST =>
               null;

            when BUSY_ST =>
               if G_DEBUG then
                  report "iter=" & to_string(iter) &
                         ", n=0x" & to_hstring(n) &
                         ", n_est=0x" & to_hstring(n_est) &
                         ", d=0x" & to_hstring(d) &
                         ", pla_q=" & to_string(pla_q);
               end if;

               next_v := get_n(n_s, n_c, d, n_est(G_SIZE - 1), pla_mag);
               n_s    <= next_v(2 * G_SIZE - 1 downto G_SIZE);
               n_c    <= next_v(G_SIZE - 1 downto 0);

               -- Store the new digit, and append the previous one. In the
               -- first iteration, the previous digit is a leading zero,
               -- which leaves quot and quot_m1 unchanged.
               digit   <= pla_q;
               quot    <= new_quot;
               quot_m1 <= new_quot_m1;

               if iter < C_NUM_ITERS - 1 then
                  iter <= iter + 1;
               else
                  state <= DONE_ST;
               end if;

            when DONE_ST =>
               if m_ready_i = '1' then
                  state <= IDLE_ST;
               end if;

         end case;

         if s_valid_i = '1' and s_ready_o = '1' then
            -- The inputs must be normalized. A zero dividend is fine too,
            -- since the PLA will then select q = 0 in every iteration.
            f_valid_n : assert s_n_i(G_SIZE - 1 downto G_SIZE - 4) = "0001" or s_n_i = 0
               report "srt_core: Dividend 0x" & to_hstring(s_n_i) & " is not normalized.";
            f_valid_d : assert s_d_i(G_SIZE - 1 downto G_SIZE - 4) = "0001"
               report "srt_core: Divisor 0x" & to_hstring(s_d_i) & " is not normalized.";
            n_s     <= s_n_i;
            n_c     <= (others => '0');
            d       <= s_d_i;
            col     <= get_col(get_d4(s_d_i));
            iter    <= 0;
            quot    <= (others => '0');                -- 0
            quot_m1 <= (others => '1');                -- -1
            digit   <= 0;
            state   <= BUSY_ST;
         end if;
      end if;
   end process srt_core_proc;

   -- col is loaded together with d. This is also needed for the induction in
   -- the formal verification.
   f_col : assert col = get_col(get_d4(d))
      report "col does not match d=0x" & to_hstring(d);

   -- Select the magnitude of the quotient digit. The sign of the digit is the
   -- sign of the estimate of n.
   pla_gen : if G_PLA = "srt" generate

      pla_inst : entity work.pla
         generic map (
            G_SIZE  => G_SIZE,
            G_DEBUG => G_DEBUG
         )
         port map (
            n_i   => n_est,
            col_i => col,
            mag_o => pla_mag
         ); -- pla_inst

   elsif G_PLA = "pentium" or G_PLA = "pentium_fixed" generate

      signal pentium_q : integer range -2 to 2;

   begin

      pla_pentium_inst : entity work.pla_pentium
         generic map (
            G_SIZE  => G_SIZE,
            G_DEBUG => G_DEBUG,
            G_FIXED => G_PLA = "pentium_fixed"
         )
         port map (
            n_i => n_est,
            d_i => d,
            q_o => pentium_q
         ); -- pla_pentium_inst

      -- Convert the digit to the same format as mag_o of pla, see get_mag
      pla_mag <= "11" when abs(pentium_q) = 2 else
                 "01" when abs(pentium_q) = 1 else
                 "00";

   else generate

      assert false
         report "srt_core: Unknown G_PLA """ & G_PLA & """"
         severity failure;

   end generate pla_gen;

   pla_q <= get_digit(n_est(G_SIZE - 1), pla_mag);

end architecture synthesis;

