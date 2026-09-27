library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;
   use ieee.fixed_float_types.all;
   use ieee.fixed_pkg.all;

-- Tangent CORDIC, modelled on the algorithm used in the Intel 8087, as described in
-- https://www.righto.com/2026/09/8087-tangent-cordic.html
--
-- The algorithm has three phases:
-- 1) Pseudo-division : the input angle is decomposed into a sum of a subset of the
--    special angles arctan(2**-i), leaving a tiny residual angle.
-- 2) Padé approximation : the tiny residual angle is converted to an (x, y) vector using
--    the rational approximation tan(z) = 3z / (3 - z*z).
-- 3) Pseudo-multiplication : the (x, y) vector is rotated by exactly the special angles
--    used during phase 1 (applied smallest-first), so that y/x becomes tan of the full
--    input angle.
--
-- A final restoring division y/x produces the actual tangent value.
--
-- Input and output use an AXI-style VALID/READY handshake.

entity tan_cordic is
   generic (
      -- Number of CORDIC iterations. The 8087 uses up to 16.
      G_ITERATIONS : positive := 16;

      -- Number of fractional bits in the input angle and output tangent.
      G_FRAC_BITS  : positive := 24
   );
   port (
      clk_i     : in    std_logic;
      rst_i     : in    std_logic;

      -- Input angle in radians, must satisfy 0.0 <= angle < pi/4.
      -- Unsigned fixed-point format U0.G_FRAC_BITS, i.e. angle = s_angle_i / 2**G_FRAC_BITS.
      s_valid_i : in    std_logic;
      s_ready_o : out   std_logic;
      s_angle_i : in    std_logic_vector(G_FRAC_BITS - 1 downto 0);

      -- Output tan(angle), in the range [0.0, 1.0[.
      -- Unsigned fixed-point format U0.G_FRAC_BITS, i.e. tan = m_tan_o / 2**G_FRAC_BITS.
      m_valid_o : out   std_logic;
      m_ready_i : in    std_logic;
      m_tan_o   : out   std_logic_vector(G_FRAC_BITS - 1 downto 0)
   );
end entity tan_cordic;

architecture synthesis of tan_cordic is

   -- Extra internal fractional bits, to limit rounding error build-up during the
   -- three phases of the algorithm.
   constant C_GUARD_BITS : natural := 8;
   constant C_FRAC       : natural := G_FRAC_BITS + C_GUARD_BITS;

   -- Holds the (residual) angle. All angles here lie in [0.0, pi/4], so one
   -- integer bit (the sign) is enough.
   subtype  angle_t is sfixed(0 downto -C_FRAC);

   -- Holds the (x, y) vector during pseudo-multiplication. The vector grows from
   -- its initial length of about 3.0 by at most the CORDIC gain of about 1.647,
   -- i.e. to at most about 5.0, so three integer bits (plus sign) are used.
   subtype  vec_t   is sfixed(3 downto -C_FRAC);

   -- Holds the remainder during the final restoring division. One extra integer
   -- bit is needed, since the remainder is doubled every iteration.
   subtype  rem_t   is sfixed(4 downto -C_FRAC);

   type     state_t is (
      IDLE_ST, REDUCE_ST, PADE_ST, ROTATE_ST, LOAD_DIV_ST, DIVIDE_ST, WAIT_ST
   );
   signal   state : state_t := IDLE_ST;

   -- Number of remaining iterations in the current phase.
   signal   count : natural range 0 to G_ITERATIONS - 1;

   -- Phase 1: pseudo-division.
   signal   angle : angle_t;
   signal   bits  : std_logic_vector(0 to G_ITERATIONS - 1);

   -- Phase 3: pseudo-multiplication.
   signal   x     : vec_t;
   signal   y     : vec_t;

   -- Phase 4: restoring division.
   signal   rem_reg   : rem_t;
   signal   div       : rem_t;
   signal   div_count : natural range 0 to G_FRAC_BITS - 1;
   signal   quotient  : std_logic_vector(G_FRAC_BITS - 1 downto 0);

   type     rom_t is array (0 to G_ITERATIONS - 1) of angle_t;

   pure function calc_angles return rom_t is
      variable res_v : rom_t;
   begin
      for i in 0 to G_ITERATIONS - 1 loop
         res_v(i) := to_sfixed(arctan(2.0 ** (-i)), angle_t'high, angle_t'low);
      end loop;
      return res_v;
   end function calc_angles;

   constant C_ANGLES : rom_t := calc_angles;

begin

   fsm_proc : process (clk_i)
      variable z_v         : angle_t;
      variable zz_v        : sfixed(2 * angle_t'high + 1 downto 2 * angle_t'low);
      variable r_doubled_v : rem_t;
      variable trial_v     : rem_t;
      variable qbit_v      : std_logic;
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' then
            m_valid_o <= '0';
         end if;

         case state is

            when IDLE_ST =>
               null;

            when REDUCE_ST =>
               -- Pseudo-division: if the current special angle fits inside the
               -- remaining angle, subtract it and record a '1'; otherwise record a
               -- '0' and leave the remaining angle unchanged. After all iterations,
               -- "angle" holds a tiny residual, and "bits" records exactly which
               -- special angles were used.
               if angle >= C_ANGLES(count) then
                  angle       <= resize(angle - C_ANGLES(count), angle_t'high, angle_t'low);
                  bits(count) <= '1';
               else
                  bits(count) <= '0';
               end if;

               if count = G_ITERATIONS - 1 then
                  state <= PADE_ST;
               else
                  count <= count + 1;
               end if;

            when PADE_ST =>
               -- Padé approximant: tan(z) = 3z / (3 - z*z), for the tiny residual
               -- angle z. Rather than performing the division, the numerator
               -- becomes the initial y, and the denominator the initial x.
               z_v  := angle;
               zz_v := z_v * z_v;

               x <= resize(to_sfixed(3.0, vec_t'high, vec_t'low) -
                           resize(zz_v, vec_t'high, vec_t'low), vec_t'high, vec_t'low);
               y <= resize(resize(z_v, vec_t'high, vec_t'low) +
                           resize(z_v, vec_t'high, vec_t'low) +
                           resize(z_v, vec_t'high, vec_t'low), vec_t'high, vec_t'low);

               count <= G_ITERATIONS - 1;
               state <= ROTATE_ST;

            when ROTATE_ST =>
               -- Pseudo-multiplication: replay (smallest-first) exactly the special
               -- angles that were used during pseudo-division, i.e. rotate (x, y) by
               -- +arctan(2**-count) whenever bits(count) = '1', and leave it unchanged
               -- otherwise.
               if bits(count) = '1' then
                  x <= resize(x - (y sra count), vec_t'high, vec_t'low);
                  y <= resize(y + (x sra count), vec_t'high, vec_t'low);
               end if;

               if count = 0 then
                  state <= LOAD_DIV_ST;
               else
                  count <= count - 1;
               end if;

            when LOAD_DIV_ST =>
               -- One clock cycle after the last rotation, x and y hold their final
               -- values, ready to be loaded into the divider.
               rem_reg   <= resize(y, rem_t'high, rem_t'low);
               div       <= resize(x, rem_t'high, rem_t'low);
               div_count <= 0;
               state     <= DIVIDE_ST;

            when DIVIDE_ST =>
               -- Restoring division: y / x, where 0 <= y <= x, so the quotient lies
               -- in [0.0, 1.0]. One quotient bit is produced per iteration, MSB first.
               r_doubled_v := resize(rem_reg + rem_reg, rem_t'high, rem_t'low);
               trial_v     := resize(r_doubled_v - div, rem_t'high, rem_t'low);

               if trial_v(trial_v'high) = '0' then
                  rem_reg <= trial_v;
                  qbit_v  := '1';
               else
                  rem_reg <= r_doubled_v;
                  qbit_v  := '0';
               end if;
               quotient <= quotient(G_FRAC_BITS - 2 downto 0) & qbit_v;

               if div_count = G_FRAC_BITS - 1 then
                  m_tan_o   <= quotient(G_FRAC_BITS - 2 downto 0) & qbit_v;
                  m_valid_o <= '1';
                  state     <= WAIT_ST;
               else
                  div_count <= div_count + 1;
               end if;

            when WAIT_ST =>
               if m_ready_i = '1' then
                  state <= IDLE_ST;
               end if;

         end case;

         if s_valid_i = '1' and s_ready_o = '1' then
            -- s_angle_i is unsigned U0.G_FRAC_BITS; widen it with one (zero) sign bit,
            -- then extend it with additional (zero) guard fraction bits.
            angle <= resize(to_sfixed(to_ufixed(s_angle_i, -1, -G_FRAC_BITS)),
                             angle_t'high, angle_t'low);
            count <= 0;
            state <= REDUCE_ST;
         end if;

         if rst_i = '1' then
            m_valid_o <= '0';
            state     <= IDLE_ST;
         end if;
      end if;
   end process fsm_proc;

   s_ready_o <= '1' when state = IDLE_ST else '0';

end architecture synthesis;
