library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- This divides two numbers using the SRT algorithm (with radix 4).
-- It is inspired by this analysis: https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html

entity srt is
   generic (
      G_DEBUG : boolean := false
   );
   port (
      clk_i        : in    std_logic;
      n_i          : in    std_logic_vector(31 downto 0); -- dividend
      d_i          : in    std_logic_vector(31 downto 0); -- divisor
      q_o          : out   std_logic_vector(63 downto 0); -- quotient
      start_over_i : in    std_logic;
      busy_o       : out   std_logic
   );
end entity srt;

architecture synthesis of srt is

   constant C_NUM_ITERS : natural                    := 34;

   signal   iter : natural range 0 to C_NUM_ITERS;

   signal   norm_n   : std_logic_vector(31 downto 0) := (others => '0');
   signal   norm_d   : std_logic_vector(31 downto 0) := X"10000000";
   signal   norm_exp : integer range -31 to 32;

   signal   pla_q : integer range -2 to 2;

   signal   shifter_q : std_logic_vector(67 downto 0);

   signal   shifted : std_logic_vector(67 downto 0);

   signal   n     : std_logic_vector(31 downto 0)    := (others => '0');
   signal   d     : std_logic_vector(31 downto 0)    := X"10000000";
   signal   q     : integer range -2 to 2;
   signal   exp   : natural range 0 to 67            := 0;
   signal   res_p : std_logic_vector(67 downto 0);
   signal   res_n : std_logic_vector(67 downto 0);
   signal   diff  : std_logic_vector(67 downto 0);

   type     state_type is (IDLE_ST, BUSY_ST, SHIFT_ST, ROUND_ST);
   signal   state : state_type                       := IDLE_ST;

   pure function get_n (
      arg_n : std_logic_vector(31 downto 0);
      arg_d : std_logic_vector(31 downto 0);
      arg_q : integer range -2 to 2
   ) return std_logic_vector is
      variable tmp_v : std_logic_vector(31 downto 0);
   begin
      --
      case arg_q is

         when -2 =>
            tmp_v := arg_n + (arg_d(30 downto 0) & "0");

         when -1 =>
            tmp_v := arg_n + arg_d;

         when 0 =>
            tmp_v := arg_n;

         when 1 =>
            tmp_v := arg_n - arg_d;

         when 2 =>
            tmp_v := arg_n - (arg_d(30 downto 0) & "0");

         when others =>
            tmp_v := arg_n;

      end case;

      if G_DEBUG then
         report "get_n: tmp_v=0x" & to_hstring(tmp_v);
      end if;

      assert tmp_v(31 downto 29) = "000" or tmp_v(31 downto 29) = "111"
         report "tmp_v=0x" & to_hstring(tmp_v);
      return tmp_v(29 downto 0) & "00";
   end function get_n;

begin

   busy_o <= '1' when state /= IDLE_ST else
             '0';

   div_proc : process (clk_i)
      variable res_v   : std_logic_vector(67 downto 0);
      constant C_ROUND : std_logic_vector(67 downto 0) := X"00000000000000008";
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
               if pla_q > 0 then
                  res_p <= res_p(65 downto 0) & to_stdlogicvector(pla_q, 2);
                  res_n <= res_n(65 downto 0) & "00";
               else
                  res_p <= res_p(65 downto 0) & "00";
                  res_n <= res_n(65 downto 0) & to_stdlogicvector(-pla_q, 2);
               end if;
               if iter < C_NUM_ITERS then
                  iter <= iter + 1;
               else
                  diff  <= res_p - res_n;
                  state <= SHIFT_ST;
               end if;

            when SHIFT_ST =>
               shifted <= shifter_q;
               state   <= ROUND_ST;

            when ROUND_ST =>
               res_v := shifted + C_ROUND;
               q_o   <= res_v(67 downto 4);
               state <= IDLE_ST;

         end case;

         if start_over_i then
            if G_DEBUG then
               report "norm_n=0x" & to_hstring(norm_n) &
                      ", norm_d=0x" & to_hstring(norm_d) &
                      ", norm_exp=" & to_string(norm_exp);
            end if;
            n     <= norm_n;
            d     <= norm_d;
            exp   <= 30 + norm_exp;
            iter  <= 0;
            res_p <= (others => '0');
            res_n <= (others => '0');
            state <= BUSY_ST;
         end if;
      end if;
   end process div_proc;

   normalizer_inst : entity work.normalizer
      port map (
         n_i   => n_i,
         d_i   => d_i,
         n_o   => norm_n,
         d_o   => norm_d,
         exp_o => norm_exp
      );

   pla_inst : entity work.pla
      generic map (
         G_DEBUG => G_DEBUG
      )
      port map (
         n_i => n,
         d_i => d,
         q_o => pla_q
      ); -- pla_inst

   shifter_inst : entity work.shifter
      port map (
         p_i   => diff,
         exp_i => exp,
         q_o   => shifter_q
      );

end architecture synthesis;

