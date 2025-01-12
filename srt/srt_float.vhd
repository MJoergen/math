library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- This divides two numbers using the SRT algorithm (with radix 4).
-- It is inspired by this analysis: https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html

entity srt_float is
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
end entity srt_float;

architecture synthesis of srt_float is

   signal norm_n   : std_logic_vector(31 downto 0)  := (others => '0');
   signal norm_d   : std_logic_vector(31 downto 0)  := X"10000000";
   signal norm_exp : integer range -31 to 32;

   signal div_n     : std_logic_vector(31 downto 0) := (others => '0');
   signal div_d     : std_logic_vector(31 downto 0) := X"10000000";
   signal div_start : std_logic;
   signal div_q     : std_logic_vector(67 downto 0);
   signal div_busy  : std_logic;

   signal shifter_q : std_logic_vector(67 downto 0);

   signal shifted : std_logic_vector(67 downto 0);

   signal exp : natural range 0 to 67               := 0;

   type   state_type is (IDLE_ST, BUSY_ST, ROUND_ST);
   signal state : state_type                        := IDLE_ST;

begin

   busy_o <= '1' when state /= IDLE_ST else '0';

   srt_float_proc : process (clk_i)
      variable res_v   : std_logic_vector(67 downto 0);
      constant C_ROUND : std_logic_vector(67 downto 0) := X"00000000000000008";
   begin
      if rising_edge(clk_i) then
         div_start <= '0';

         case state is

            when IDLE_ST =>
               null;

            when BUSY_ST =>
               if div_busy = '0' then
                  shifted <= shifter_q;
                  state   <= ROUND_ST;
               end if;

            when ROUND_ST =>
               res_v := shifted + C_ROUND;
               q_o   <= res_v(67 downto 4);
               state <= IDLE_ST;

         end case;

         if start_over_i then
            div_start <= '1';
            div_n     <= norm_n;
            div_d     <= norm_d;
            exp       <= 30 + norm_exp;
            state     <= BUSY_ST;
         end if;
      end if;
   end process srt_float_proc;

   normalizer_inst : entity work.normalizer
      port map (
         n_i   => n_i,
         d_i   => d_i,
         n_o   => norm_n,
         d_o   => norm_d,
         exp_o => norm_exp
      ); -- normalizer_inst

   div_inst : entity work.div
      generic map (
         G_SIZE  => 32,
         G_DEBUG => G_DEBUG
      )
      port map (
         clk_i   => clk_i,
         start_i => start_over_i,
         n_i     => norm_n,
         d_i     => norm_d,
         q_o     => div_q,
         busy_o  => div_busy
      ); -- div_inst

   shifter_inst : entity work.shifter
      port map (
         p_i   => div_q,
         exp_i => exp,
         q_o   => shifter_q
      ); -- shifter_inst

end architecture synthesis;

