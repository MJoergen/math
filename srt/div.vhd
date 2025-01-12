library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std_unsigned.all;

-- This divides two numbers using the SRT algorithm (with radix 4).
-- It is inspired by this analysis: https://www.righto.com/2024/12/this-die-photo-of-pentium-shows.html

-- The values must be normalized on input and output.

entity div is
   generic (
      G_SIZE  : natural;
      G_DEBUG : boolean
   );
   port (
      clk_i   : in    std_logic;
      n_i     : in    std_logic_vector(G_SIZE-1 downto 0); -- dividend
      d_i     : in    std_logic_vector(G_SIZE-1 downto 0); -- divisor
      start_i : in    std_logic;
      q_o     : out   std_logic_vector(2*G_SIZE+3 downto 0); -- quotient
      busy_o  : out   std_logic
   );
end entity div;

architecture synthesis of div is

   constant C_NUM_ITERS : natural                 := G_SIZE+2;

   signal   iter : natural range 0 to C_NUM_ITERS;

   signal   pla_q : integer range -2 to 2;

   function get_init_d return std_logic_vector is
      variable res_v : std_logic_vector(G_SIZE-1 downto 0);
   begin
      res_v := (others => '0');
      res_v(G_SIZE-4) := '1';
      return res_v;
   end function get_init_d;

   signal   n     : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');
   signal   d     : std_logic_vector(G_SIZE-1 downto 0) := get_init_d;
   signal   res_p : std_logic_vector(2*G_SIZE+3 downto 0);
   signal   res_n : std_logic_vector(2*G_SIZE+3 downto 0);

   type     state_type is (IDLE_ST, BUSY_ST);
   signal   state : state_type                    := IDLE_ST;

   pure function get_n (
      arg_n : std_logic_vector(G_SIZE-1 downto 0);
      arg_d : std_logic_vector(G_SIZE-1 downto 0);
      arg_q : integer range -2 to 2
   ) return std_logic_vector is
      variable tmp_v : std_logic_vector(G_SIZE-1 downto 0);
   begin
      --
      case arg_q is

         when -2 =>
            tmp_v := arg_n + (arg_d(G_SIZE-2 downto 0) & "0");

         when -1 =>
            tmp_v := arg_n + arg_d;

         when 0 =>
            tmp_v := arg_n;

         when 1 =>
            tmp_v := arg_n - arg_d;

         when 2 =>
            tmp_v := arg_n - (arg_d(G_SIZE-2 downto 0) & "0");

         when others =>
            tmp_v := arg_n;

      end case;

      if G_DEBUG then
         report "get_n: tmp_v=0x" & to_hstring(tmp_v);
      end if;

      f_74 : assert tmp_v(G_SIZE-1 downto G_SIZE-3) = "000" or tmp_v(G_SIZE-1 downto G_SIZE-3) = "111"
         report "tmp_v=0x" & to_hstring(tmp_v);
      return tmp_v(G_SIZE-3 downto 0) & "00";
   end function get_n;

begin

   busy_o <= '1' when state /= IDLE_ST else
             '0';

   div_proc : process (clk_i)
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
                  res_p <= res_p(2*G_SIZE+1 downto 0) & to_stdlogicvector(pla_q, 2);
                  res_n <= res_n(2*G_SIZE+1 downto 0) & "00";
               else
                  res_p <= res_p(2*G_SIZE+1 downto 0) & "00";
                  res_n <= res_n(2*G_SIZE+1 downto 0) & to_stdlogicvector(-pla_q, 2);
               end if;
               if iter < C_NUM_ITERS then
                  iter <= iter + 1;
               else
                  q_o   <= res_p - res_n;
                  state <= IDLE_ST;
               end if;

         end case;

         if start_i then
            f_119 : assert n_i(G_SIZE-1 downto G_SIZE-4) = "0001";
            f_120 : assert d_i(G_SIZE-1 downto G_SIZE-4) = "0001";
            n     <= n_i;
            d     <= d_i;
            iter  <= 0;
            res_p <= (others => '0');
            res_n <= (others => '0');
            state <= BUSY_ST;
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

