library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- This divides two numbers using the SRT algorithm (with radix 4).
-- It is inspired by this analysis: https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html
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
--   n_i, d_i : Must be normalized, i.e. the top nibble must be "0001", so
--              1 <= n_i, d_i < 2. As a special case n_i = 0 is allowed.
--   n        : The partial remainder. It stays within |n/d| < 8/3, which is
--              the radix 4 times the redundancy factor 2/3 of the digit set.
--              Formal verification shows that -4 <= n < 4.5.
--   q_o      : Unsigned, with 2 integer bits and 2*G_SIZE+2 fractional bits.
--              The quotient digit from iteration k has weight 4^(-k). Since
--              1/2 < n_i/d_i < 2 the first digit is always 1 or 2
--              (unless n_i = 0).
--
-- The quotient digits are converted to an ordinary binary number on the fly,
-- without any carry chain: Two registers hold the quotient so far (quot) and
-- the quotient minus one unit of the last digit (quot_m1). A negative digit
-- q is then handled by appending (4 + q) to quot_m1, since
--    4*quot + q = 4*quot_m1 + (4 + q)
-- So each iteration only selects one of the two registers and appends two
-- bits, and after the last iteration quot is the result. See the table in
-- div_proc.
--
-- Usage: Pulse start_i for one clock cycle. The inputs n_i and d_i are only
-- sampled in that cycle. The result is valid on q_o when busy_o returns low.

entity div is
   generic (
      G_SIZE  : natural;
      G_DEBUG : boolean
   );
   port (
      clk_i   : in    std_logic;
      n_i     : in    std_logic_vector(G_SIZE - 1 downto 0);     -- dividend (normalized)
      d_i     : in    std_logic_vector(G_SIZE - 1 downto 0);     -- divisor (normalized)
      start_i : in    std_logic;
      q_o     : out   std_logic_vector(2 * G_SIZE + 3 downto 0); -- quotient
      busy_o  : out   std_logic
   );
end entity div;

architecture synthesis of div is

   -- Number of quotient digits. Each digit is two bits, so this fills q_o.
   constant C_NUM_ITERS : natural                         := G_SIZE + 2;

   signal   iter : natural range 0 to C_NUM_ITERS - 1;

   signal   pla_q : integer range -2 to 2;

   -- Any normalized value will do. This just keeps the PLA assertion happy
   -- before the first division.
   function get_init_d return std_logic_vector is
      variable res_v : std_logic_vector(G_SIZE - 1 downto 0);
   begin
      res_v             := (others => '0');
      res_v(G_SIZE - 4) := '1';
      return res_v;
   end function get_init_d;

   signal   n     : std_logic_vector(G_SIZE - 1 downto 0) := (others => '0'); -- Partial remainder
   signal   d     : std_logic_vector(G_SIZE - 1 downto 0) := get_init_d;      -- Divisor
   signal   quot    : std_logic_vector(2 * G_SIZE + 3 downto 0);              -- Quotient so far
   signal   quot_m1 : std_logic_vector(2 * G_SIZE + 3 downto 0);              -- quot - 1

   type     state_type is (IDLE_ST, BUSY_ST);
   signal   state : state_type                            := IDLE_ST;

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

   -- Calculate the next partial remainder 4*(n - q*d).
   -- The assertions verify the invariants of the SRT algorithm, and are used
   -- during formal verification.
   pure function get_n (
      arg_n : std_logic_vector(G_SIZE - 1 downto 0);
      arg_d : std_logic_vector(G_SIZE - 1 downto 0);
      arg_q : integer range -2 to 2
   ) return std_logic_vector is
      variable tmp_v   : std_logic_vector(G_SIZE - 1 downto 0);
      variable neg_v   : std_logic_vector(G_SIZE - 1 downto 0);
      variable tmp3_v  : std_logic_vector(G_SIZE + 1 downto 0);
      variable argn3_v : std_logic_vector(G_SIZE + 1 downto 0);
   begin
      argn3_v := ("00" & abs_slv(arg_n)) + ("0" & abs_slv(arg_n) & "0");

      -- Verify that n/d < 8/3, i.e. 3*n < 8*d
      f_quotient_bound : assert argn3_v(G_SIZE + 1 downto G_SIZE) = "00" and
                                argn3_v(G_SIZE - 1 downto 0) < arg_d(G_SIZE - 4 downto 0) & "000"
         report "argn3_v=0x" & to_hstring(argn3_v) &
                ", arg_n=0x" & to_hstring(arg_n) &
                ", arg_d=0x" & to_hstring(arg_d);

      -- Calculate n - q*d. Multiplying by 2 is just a shift.
      case arg_q is

         when -2 =>
            tmp_v := arg_n + (arg_d(G_SIZE - 2 downto 0) & "0");

         when -1 =>
            tmp_v := arg_n + arg_d;

         when 0 =>
            tmp_v := arg_n;

         when 1 =>
            tmp_v := arg_n - arg_d;

         when 2 =>
            tmp_v := arg_n - (arg_d(G_SIZE - 2 downto 0) & "0");

         when others =>
            tmp_v := arg_n;

      end case;

      if G_DEBUG then
         report "get_n: tmp_v=0x" & to_hstring(tmp_v);
      end if;

      tmp3_v := ("00" & abs_slv(tmp_v)) + ("0" & abs_slv(tmp_v) & "0");

      -- Verify that |n - q*d| < 4/3, i.e. 3*|n - q*d| < 4.
      -- This follows from |n - q*d| <= 2/3*d and d < 2.
      f_remainder_bound : assert tmp3_v(G_SIZE + 1 downto G_SIZE - 2) = "0000"
         report "tmp_v=0x" & to_hstring(tmp_v) &
                ", tmp3_v=0x" & to_hstring(tmp3_v) &
                ", arg_d=0x" & to_hstring(arg_d);

      -- Verify that |n - q*d| < 2, so that multiplying by 4 does not overflow.
      f_no_overflow : assert tmp_v(G_SIZE - 1 downto G_SIZE - 3) = "000" or
                             tmp_v(G_SIZE - 1 downto G_SIZE - 3) = "111"
         report "tmp_v=0x" & to_hstring(tmp_v);
      -- Multiply by 4
      return tmp_v(G_SIZE - 3 downto 0) & "00";
   end function get_n;

begin

   busy_o <= '1' when state /= IDLE_ST else
             '0';

   div_proc : process (clk_i)
      variable quot_v    : std_logic_vector(2 * G_SIZE + 1 downto 0);
      variable quot_m1_v : std_logic_vector(2 * G_SIZE + 1 downto 0);
      variable new_v     : std_logic_vector(2 * G_SIZE + 3 downto 0);
      variable new_m1_v  : std_logic_vector(2 * G_SIZE + 3 downto 0);
   begin
      if rising_edge(clk_i) then

         case state is

            when IDLE_ST =>
               null;

            when BUSY_ST =>
               if G_DEBUG then
                  report "iter=" & to_string(iter) &
                         ", n=0x" & to_hstring(n) &
                         ", d=0x" & to_hstring(d) &
                         ", pla_q=" & to_string(pla_q);
               end if;

               n <= get_n(n, d, pla_q);

               -- Append the new quotient digit q (on-the-fly conversion). The
               -- new values are 4*quot + q and 4*quot + q - 1, where
               -- 4*quot = quot & "00", and 4*quot = quot_m1 & "00" + 4.
               --    q  | new quot       | new quot_m1
               --    2  | quot    & "10" | quot    & "01"
               --    1  | quot    & "01" | quot    & "00"
               --    0  | quot    & "00" | quot_m1 & "11"
               --   -1  | quot_m1 & "11" | quot_m1 & "10"
               --   -2  | quot_m1 & "10" | quot_m1 & "01"
               quot_v    := quot(2 * G_SIZE + 1 downto 0);
               quot_m1_v := quot_m1(2 * G_SIZE + 1 downto 0);

               case pla_q is

                  when 2 =>
                     new_v    := quot_v & "10";
                     new_m1_v := quot_v & "01";

                  when 1 =>
                     new_v    := quot_v & "01";
                     new_m1_v := quot_v & "00";

                  when -1 =>
                     new_v    := quot_m1_v & "11";
                     new_m1_v := quot_m1_v & "10";

                  when -2 =>
                     new_v    := quot_m1_v & "10";
                     new_m1_v := quot_m1_v & "01";

                  when others =>
                     new_v    := quot_v & "00";
                     new_m1_v := quot_m1_v & "11";

               end case;

               quot    <= new_v;
               quot_m1 <= new_m1_v;

               -- In the last iteration, the result includes the digit just
               -- calculated.
               if iter < C_NUM_ITERS - 1 then
                  iter <= iter + 1;
               else
                  q_o   <= new_v;
                  state <= IDLE_ST;
               end if;

         end case;

         if start_i then
            -- The inputs must be normalized. A zero dividend is fine too,
            -- since the PLA will then select q = 0 in every iteration.
            f_valid_n : assert n_i(G_SIZE - 1 downto G_SIZE - 4) = "0001" or n_i = 0
               report "div: Dividend 0x" & to_hstring(n_i) & " is not normalized.";
            f_valid_d : assert d_i(G_SIZE - 1 downto G_SIZE - 4) = "0001"
               report "div: Divisor 0x" & to_hstring(d_i) & " is not normalized.";
            n       <= n_i;
            d       <= d_i;
            iter    <= 0;
            quot    <= (others => '0');                -- 0
            quot_m1 <= (others => '1');                -- -1
            state   <= BUSY_ST;
         end if;
      end if;
   end process div_proc;

   pla_inst : entity work.pla
      generic map (
         G_SIZE  => G_SIZE,
         G_DEBUG => G_DEBUG
      )
      port map (
         n_i => n,
         d_i => d,
         q_o => pla_q
      ); -- pla_inst

end architecture synthesis;

