library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- This module takes a floating point number (s_exp_i, s_mant_i) and returns
-- the square root as a floating point number (m_exp_o, m_mant_o).
--
-- It calculates C_GUARDS extra bits in order to perform the correct rounding.
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
-- https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Goldschmidt%E2%80%99s_algorithm
-- A second form, using fused multiply-add operations, begins
-- y0 := approximation of 1/sqrt(s)
-- x0 := s*y0
-- h0 := y0/2
-- and iterates
-- rn := 0.5-xn*hn
-- x_(n+1) := xn + xn*rn
-- h_(n+1) := hn + hn*rn
-- until rn is sufficiently close to 0.
-- This converges to:
-- xn -> sqrt(s)
-- hn -> 0.5/sqrt(s)
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
-- The number of clock cycles depends on how many iterations are needed. In the
-- testbench m_valid_o is asserted 5 to 9 clock cycles (7.1 on average) after
-- the input is accepted (1 clock cycle for a negative or zero input). A new
-- input is accepted in the clock cycle after the result is written to the
-- output register.

entity c64_sqrt2 is
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
end entity c64_sqrt2;

architecture synthesis of c64_sqrt2 is

   type float_type is record
      exp  : unsigned( 7 downto 0);
      mant : unsigned(31 downto 0);
   end record float_type;

   constant C_ROM_SIZE : natural := 6;
   constant C_GUARDS   : natural := 4;

   -- Input is interpreted as a real value between 0.25 and 1.0
   -- Output is 0.5/sqrt(input) and is interpreted as a real value
   -- between 0.5 and 1.0.
   pure function inv_sqrt(arg : unsigned(C_ROM_SIZE-1 downto 0)) return unsigned is
      variable arg_real_v : real;
      variable res_real_v : real;
      variable res_v      : unsigned(C_ROM_SIZE-1 downto 0);
   begin
      assert arg(C_ROM_SIZE-1 downto C_ROM_SIZE-2) /= "00";
      arg_real_v := real(to_integer(arg)+1)/(2.0 ** C_ROM_SIZE);
      res_real_v := 0.5/sqrt(arg_real_v);
      if res_real_v = 1.0 then
         res_v := (others => '1');
      else
         res_v := to_unsigned(integer(floor(res_real_v*(2.0 ** C_ROM_SIZE))), C_ROM_SIZE);
      end if;
      return res_v;
   end function inv_sqrt;

   -- IDLE_ST    : Waiting for a new input.
   -- INIT_ST    : Calculate x0 from the initial approximation.
   -- CALC_R_ST  : Calculate r.
   -- CALC_XH_ST : Calculate x and h. When r is close enough to 0, the result
   --              is written to the output register as soon as it is free.
   -- DONE_ST    : The result is zero. It is written to the output register as
   --              soon as it is free.
   type   state_type is (IDLE_ST, INIT_ST, CALC_R_ST, CALC_XH_ST, DONE_ST);
   signal state : state_type := IDLE_ST;

   type rom_type is array (natural range 0 to 2**C_ROM_SIZE-1) of unsigned(C_ROM_SIZE-1 downto 0);

   pure function init_inv_sqrt return rom_type is
      variable res_v : rom_type := (others => (others => '0'));
   begin
      for i in 2**C_ROM_SIZE/4 to 2**C_ROM_SIZE-1 loop
         res_v(i) := inv_sqrt(to_unsigned(i, C_ROM_SIZE));
      end loop;
      return res_v;
   end function init_inv_sqrt;

   constant C_INV_SQRT : rom_type := init_inv_sqrt;
   constant C_ZERO     : unsigned(31+C_GUARDS downto 0) := (others => '0');
   constant C_HALF     : unsigned(31+C_GUARDS downto 0) := (31+C_GUARDS => '1', others => '0');

   signal x         : unsigned(31+C_GUARDS downto 0);
   signal h         : unsigned(31+C_GUARDS downto 0);
   signal r         : unsigned(31+C_GUARDS downto 0);
   signal dsp_0_a   : unsigned(31+C_GUARDS downto 0);
   signal dsp_0_b   : unsigned(31+C_GUARDS downto 0);
   signal dsp_0_c   : unsigned(31+C_GUARDS downto 0);
   signal dsp_0_res : unsigned(31+C_GUARDS downto 0);
   signal dsp_1_a   : unsigned(31+C_GUARDS downto 0);
   signal dsp_1_b   : unsigned(31+C_GUARDS downto 0);
   signal dsp_1_c   : unsigned(31+C_GUARDS downto 0);
   signal dsp_1_res : unsigned(31+C_GUARDS downto 0);

   -- The exponent of the result, and whether the input is negative
   signal exp : unsigned(7 downto 0);
   signal neg : std_logic;

begin

   dsp_0_inst : entity work.dsp
      generic map (
         G_SIZE => 32+C_GUARDS
      )
      port map (
         a_i   => dsp_0_a,
         b_i   => dsp_0_b,
         c_i   => dsp_0_c,
         res_o => dsp_0_res
      );

   dsp_1_inst : entity work.dsp
      generic map (
         G_SIZE => 32+C_GUARDS
      )
      port map (
         a_i   => dsp_1_a,
         b_i   => dsp_1_b,
         c_i   => dsp_1_c,
         res_o => dsp_1_res
      );

   dsp_0_a <= x;
   dsp_0_b <= r when state = CALC_XH_ST else h;
   dsp_0_c <= x when state = CALC_XH_ST else C_HALF;

   dsp_1_a <= h;
   dsp_1_b <= r;
   dsp_1_c <= h when state = CALC_XH_ST else C_ZERO;


   s_ready_o <= '1' when state = IDLE_ST else
                '0';

   sqrt_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' then
            m_valid_o <= '0';
         end if;

         case state is

            when IDLE_ST =>
               null;

            when INIT_ST =>
               x     <= dsp_1_res(30+C_GUARDS downto 0) & "0";
               state <= CALC_R_ST;

            when CALC_R_ST =>
               r     <= 0-dsp_0_res;
               state <= CALC_XH_ST;

            when CALC_XH_ST =>
               if r(31+C_GUARDS downto (32+C_GUARDS)/2) = 0 then
                  -- Wait until the output register is free. x and h are not
                  -- updated, so the result stays the same while waiting.
                  if m_valid_o = '0' or m_ready_i = '1' then
                     if dsp_0_res(C_GUARDS-1) = '0' then
                        m_mant_o <= std_logic_vector(dsp_0_res(31+C_GUARDS downto C_GUARDS));
                     else
                        m_mant_o <= std_logic_vector(dsp_0_res(31+C_GUARDS downto C_GUARDS) + 1);
                     end if;
                     m_mant_o(31) <= '0';
                     m_exp_o      <= std_logic_vector(exp);
                     m_error_o    <= '0';
                     m_valid_o    <= '1';
                     state        <= IDLE_ST;
                  end if;
               else
                  x     <= dsp_0_res;
                  h     <= dsp_1_res;
                  state <= CALC_R_ST;
               end if;

            when DONE_ST =>
               if m_valid_o = '0' or m_ready_i = '1' then
                  m_mant_o  <= (others => '0');
                  m_exp_o   <= (others => '0');
                  m_error_o <= neg;
                  m_valid_o <= '1';
                  state     <= IDLE_ST;
               end if;

         end case;

         -- This takes priority over the state machine above
         if s_valid_i = '1' and s_ready_o = '1' then
            h <= (others => '0');
            r <= (others => '0');
            if s_exp_i(0) = '0' then
               r(31+C_GUARDS downto C_GUARDS)               <= unsigned(s_mant_i) or X"80000000";
               h(31+C_GUARDS downto 32+C_GUARDS-C_ROM_SIZE) <= C_INV_SQRT(to_integer(unsigned("1" & s_mant_i(30 downto 32-C_ROM_SIZE))));
               exp                                          <= ("0" & unsigned(s_exp_i(7 downto 1))) + X"40";
            else
               r(30+C_GUARDS downto C_GUARDS-1)             <= unsigned(s_mant_i) or X"80000000";
               h(31+C_GUARDS downto 32+C_GUARDS-C_ROM_SIZE) <= C_INV_SQRT(to_integer(unsigned("01" & s_mant_i(30 downto 33-C_ROM_SIZE))));
               exp                                          <= ("0" & unsigned(s_exp_i(7 downto 1))) + X"41";
            end if;
            neg <= s_mant_i(31);

            if s_mant_i(31) = '1' or s_exp_i = X"00" then
               state <= DONE_ST;
            else
               state <= INIT_ST;
            end if;
         end if;

         if rst_i = '1' then
            m_valid_o <= '0';
            state     <= IDLE_ST;
         end if;
      end if;
   end process sqrt_proc;

end architecture synthesis;

