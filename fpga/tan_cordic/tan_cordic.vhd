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
-- A final non-restoring division y/x produces the actual tangent value.
--
-- Phases 1 and 3, and the division, each do G_STEPS iterations in each clock
-- cycle.
--
-- Interface:
-- The input is accepted when s_valid_i and s_ready_o are both asserted on the
-- same clock edge. The result is presented when m_valid_o is asserted, and is
-- held stable until m_ready_i is asserted. None of the output signals depend
-- combinatorially on any of the input signals. rst_i is a synchronous reset
-- (active high). It clears m_valid_o, and abandons a calculation in progress.
--
-- Only one calculation is in progress at a time: a new angle is accepted only
-- when the previous result has been consumed.
--
-- Latency:
-- m_valid_o is asserted 2*ceil(G_ITERATIONS/G_STEPS) + ceil(G_FRAC_BITS/G_STEPS) + 3
-- clock cycles after the input is accepted, i.e. 13 clock cycles for the
-- default generics.

entity tan_cordic is
   generic (
      -- Number of CORDIC iterations. The 8087 uses up to 16, for 64 bits.
      -- About G_FRAC_BITS/4 are enough, since the Pade approximation gains
      -- about 5 bits per iteration, see ALGORITHM.md.
      G_ITERATIONS : positive := 6;

      -- Number of fractional bits in the input angle and output tangent.
      G_FRAC_BITS  : positive := 24;

      -- Number of iterations of phases 1 and 3, and of quotient bits of the
      -- division, in each clock cycle.
      G_STEPS      : positive := 4
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;

      -- Input angle in radians, must satisfy 0.0 <= angle < pi/4.
      -- Unsigned fixed-point format U0.G_FRAC_BITS, i.e. angle = s_angle_i / 2**G_FRAC_BITS.
      s_valid_i : in  std_logic;
      s_ready_o : out std_logic;
      s_angle_i : in  std_logic_vector(G_FRAC_BITS - 1 downto 0);

      -- Output tan(angle), in the range [0.0, 1.0[.
      -- Unsigned fixed-point format U0.G_FRAC_BITS, i.e. tan = m_tan_o / 2**G_FRAC_BITS.
      m_valid_o : out std_logic;
      m_ready_i : in  std_logic;
      m_tan_o   : out std_logic_vector(G_FRAC_BITS - 1 downto 0)
   );
end entity tan_cordic;

architecture synthesis of tan_cordic is

   -- Extra internal fractional bits, to limit rounding error build-up during the
   -- three phases of the algorithm.
   constant C_GUARD_BITS : natural := 8;
   constant C_FRAC       : natural := G_FRAC_BITS + C_GUARD_BITS;

   -- Holds the (residual) angle. All angles here lie in [0.0, pi/4], so one
   -- integer bit (the sign) is enough.
   subtype angle_type is sfixed(0 downto -C_FRAC);

   -- Holds the tiny residual angle left after REDUCE_ST, i.e. the "z" used by the
   -- Padé approximation, narrowed for the multiplication z*z. This keeps the
   -- multiplier (and hence the number of DSP48E1 tiles it needs) as small as
   -- possible:
   -- * Upper bits: After the last pseudo-division iteration (index
   --   G_ITERATIONS-1), the residual is always strictly less than
   --   arctan(2**-(G_ITERATIONS-1)) < 2**-(G_ITERATIONS-1), so all of its bits
   --   above weight 2**(1-G_ITERATIONS) are provably zero and can be dropped.
   -- * Lower bits: z*z only needs to be precise to about 2**-(G_FRAC_BITS+4).
   --   Truncating z to its bits down to weight 2**-m changes z*z by less than
   --   2**-(m+G_ITERATIONS-2), and the result by a third of that. With
   --   m = G_FRAC_BITS - G_ITERATIONS + 4 (C_SQ_LOW = -m), this is below
   --   2**-(G_FRAC_BITS+3.6), i.e. less than 1/12 of the last bit of the result.
   --   See ALGORITHM.md.
   -- With the default generics z has 18 bits (weights 2**-5 to 2**-22), so the
   -- multiplier fits in a single DSP48E1. If G_ITERATIONS is so large that z*z
   -- is always below this precision, only the sign bit is left, i.e. z*z is
   -- zero. The "maximum" guards against G_ITERATIONS being so large (relative
   -- to C_FRAC) that no bits would be left.
   constant C_SQ_LOW : integer := maximum(-C_FRAC,
                                          minimum(G_ITERATIONS - G_FRAC_BITS - 4, 1 - G_ITERATIONS));

   subtype small_angle_type is sfixed(maximum(1 - G_ITERATIONS, -C_FRAC) downto C_SQ_LOW);

   -- Holds the (x, y) vector during pseudo-multiplication. The vector grows from
   -- its initial length of about 3.0 by at most the CORDIC gain of about 1.647,
   -- i.e. to at most about 5.0, so three integer bits (plus sign) are used.
   subtype vec_type is sfixed(3 downto -C_FRAC);

   -- Holds the signed remainder during the final non-restoring division. One
   -- extra integer bit is needed, since the remainder is doubled every iteration.
   subtype rem_type is sfixed(4 downto -C_FRAC);

   type   state_type is (
      IDLE_ST, REDUCE_ST, PADE_MUL_ST, PADE_ST, ROTATE_ST, DIVIDE_ST, WAIT_ST
   );
   signal state : state_type := IDLE_ST;

   -- The number of clock cycles of each of phases 1 and 3, and of the division.
   -- If G_STEPS does not divide G_ITERATIONS or G_FRAC_BITS, the last clock
   -- cycle does fewer iterations.
   constant C_ITER_CYCLES : positive := (G_ITERATIONS + G_STEPS - 1) / G_STEPS;
   constant C_DIV_CYCLES  : positive := (G_FRAC_BITS + G_STEPS - 1) / G_STEPS;

   -- The clock cycle in phase 1 or 3
   signal count : natural range 0 to C_ITER_CYCLES - 1;

   -- Phase 1: pseudo-division.
   signal angle : angle_type;
   signal bits  : std_logic_vector(0 to G_ITERATIONS - 1);

   -- Phase 2: Padé approximation (registered halfway through, see PADE_MUL_ST).
   signal zz_reg : vec_type;
   signal z_reg  : vec_type;

   -- Phase 3: pseudo-multiplication.
   signal x : vec_type;
   signal y : vec_type;

   -- Phase 4: non-restoring division. div_count is the clock cycle.
   signal rem_reg   : rem_type;
   signal div       : rem_type;
   signal div_count : natural range 0 to C_DIV_CYCLES - 1;
   signal quotient  : std_logic_vector(G_FRAC_BITS - 1 downto 0);

   type rom_type is array (0 to G_ITERATIONS - 1) of angle_type;

   pure function calc_angles return rom_type is
      variable res_v : rom_type;
   begin
      for i in 0 to G_ITERATIONS - 1 loop
         res_v(i) := to_sfixed(arctan(2.0 ** (-i)), angle_type'high, angle_type'low);
      end loop;
      return res_v;
   end function calc_angles;

   constant C_ANGLES : rom_type := calc_angles;

begin

   fsm_proc : process (clk_i)
      variable z_v         : small_angle_type;
      variable zz_v        : sfixed(2 * small_angle_type'high + 1 downto 2 * small_angle_type'low);
      variable r_doubled_v : rem_type;
      variable rem_v       : rem_type;
      variable quotient_v  : std_logic_vector(G_FRAC_BITS - 1 downto 0);
      variable angle_v     : angle_type;
      variable bits_v      : std_logic_vector(0 to G_ITERATIONS - 1);
      variable x_v         : vec_type;
      variable y_v         : vec_type;
      variable tmp_v       : vec_type;
      variable i_v         : natural range 0 to C_ITER_CYCLES * G_STEPS - 1;
      variable n_v         : natural range 0 to C_DIV_CYCLES * G_STEPS - 1;
   begin
      if rising_edge(clk_i) then
         if m_ready_i = '1' then
            m_valid_o <= '0';
         end if;

         case state is

            when IDLE_ST =>
               if s_valid_i = '1' then
                  -- s_angle_i is unsigned U0.G_FRAC_BITS; widen it with one (zero) sign bit,
                  -- then extend it with additional (zero) guard fraction bits.
                  angle <= resize(to_sfixed(to_ufixed(s_angle_i, -1, -G_FRAC_BITS)),
                                   angle_type'high, angle_type'low);
                  count <= 0;
                  state <= REDUCE_ST;
               end if;

            when REDUCE_ST =>
               -- Pseudo-division: if the current special angle fits inside the
               -- remaining angle, subtract it and record a '1'; otherwise record a
               -- '0' and leave the remaining angle unchanged. After all iterations,
               -- "angle" holds a tiny residual, and "bits" records exactly which
               -- special angles were used. G_STEPS iterations in each clock cycle.
               -- The values cannot overflow, so the results are wrapped and
               -- truncated, which needs no extra logic (the default of resize is
               -- to saturate and round).
               angle_v := angle;
               bits_v  := bits;
               for j in 0 to G_STEPS - 1 loop
                  i_v := count * G_STEPS + j;
                  if i_v < G_ITERATIONS then
                     if angle_v >= C_ANGLES(i_v) then
                        angle_v     := resize(angle_v - C_ANGLES(i_v),
                                              angle_type'high, angle_type'low,
                                              fixed_wrap, fixed_truncate);
                        bits_v(i_v) := '1';
                     else
                        bits_v(i_v) := '0';
                     end if;
                  end if;
               end loop;
               angle <= angle_v;
               bits  <= bits_v;

               if count = C_ITER_CYCLES - 1 then
                  state <= PADE_MUL_ST;
               else
                  count <= count + 1;
               end if;

            when PADE_MUL_ST =>
               -- Padé approximant: tan(z) = 3z / (3 - z*z), for the tiny residual
               -- angle z. Rather than performing the division, the numerator
               -- becomes the initial y, and the denominator the initial x.
               -- The multiply z*z is registered here, separately from the
               -- subsequent subtraction in PADE_ST, so that each of the two
               -- following clock cycles has a shorter combinational path. "angle"
               -- is narrowed to small_angle_type for the multiplication (see its
               -- declaration), which keeps the multiplier as small as possible.
               -- The dropped upper bits are always zero, so wrapping is
               -- lossless, and truncation needs no adder. z_reg keeps all the
               -- bits of z.
               z_v  := resize(angle, small_angle_type'high, small_angle_type'low,
                              fixed_wrap, fixed_truncate);
               zz_v := z_v * z_v;

               zz_reg <= resize(zz_v, vec_type'high, vec_type'low);
               z_reg  <= resize(angle, vec_type'high, vec_type'low);

               state <= PADE_ST;

            when PADE_ST =>
               x <= resize(to_sfixed(3.0, vec_type'high, vec_type'low) - zz_reg, vec_type'high, vec_type'low);
               y <= resize(z_reg + z_reg + z_reg, vec_type'high, vec_type'low);

               count <= 0;
               state <= ROTATE_ST;

            when ROTATE_ST =>
               -- Pseudo-multiplication: replay (smallest-first) exactly the special
               -- angles that were used during pseudo-division, i.e. rotate (x, y) by
               -- +arctan(2**-i) whenever bits(i) = '1', and leave it unchanged
               -- otherwise. G_STEPS iterations in each clock cycle. Since count only
               -- has C_ITER_CYCLES values, each shift by i is a multiplexer with
               -- only C_ITER_CYCLES inputs.
               x_v := x;
               y_v := y;
               for j in 0 to G_STEPS - 1 loop
                  if count * G_STEPS + j < G_ITERATIONS then
                     i_v := G_ITERATIONS - 1 - (count * G_STEPS + j);
                     if bits(i_v) = '1' then
                        tmp_v := resize(x_v - (y_v sra i_v), vec_type'high, vec_type'low,
                                         fixed_wrap, fixed_truncate);
                        y_v   := resize(y_v + (x_v sra i_v), vec_type'high, vec_type'low,
                                         fixed_wrap, fixed_truncate);
                        x_v   := tmp_v;
                     end if;
                  end if;
               end loop;
               x <= x_v;
               y <= y_v;

               if count = C_ITER_CYCLES - 1 then
                  -- The final x and y are loaded directly into the divider
                  rem_reg   <= resize(y_v, rem_type'high, rem_type'low);
                  div       <= resize(x_v, rem_type'high, rem_type'low);
                  div_count <= 0;
                  state     <= DIVIDE_ST;
               else
                  count <= count + 1;
               end if;

            when DIVIDE_ST =>
               -- Division y / x, where 0 <= y <= x, so the quotient lies in
               -- [0.0, 1.0]. One quotient bit is produced per iteration, MSB first,
               -- G_STEPS in each clock cycle. Non-restoring: if the quotient bit is
               -- 0, the remainder is negative and is not restored, and the next
               -- iteration adds the divisor instead of subtracting it. The quotient
               -- bits are the same as with a restoring division, see ALGORITHM.md.
               rem_v      := rem_reg;
               quotient_v := quotient;
               for j in 0 to G_STEPS - 1 loop
                  n_v := div_count * G_STEPS + j;
                  if n_v < G_FRAC_BITS then
                     r_doubled_v := resize(rem_v + rem_v, rem_type'high, rem_type'low,
                                       fixed_wrap, fixed_truncate);
                     if rem_v(rem_v'high) = '0' then
                        rem_v := resize(r_doubled_v - div, rem_type'high, rem_type'low,
                                       fixed_wrap, fixed_truncate);
                     else
                        rem_v := resize(r_doubled_v + div, rem_type'high, rem_type'low,
                                       fixed_wrap, fixed_truncate);
                     end if;
                     quotient_v := quotient_v(G_FRAC_BITS - 2 downto 0) & (not rem_v(rem_v'high));
                  end if;
               end loop;
               rem_reg  <= rem_v;
               quotient <= quotient_v;

               if div_count = C_DIV_CYCLES - 1 then
                  m_tan_o   <= quotient_v;
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

         if rst_i = '1' then
            m_valid_o <= '0';
            state     <= IDLE_ST;
         end if;
      end if;
   end process fsm_proc;

   s_ready_o <= '1' when state = IDLE_ST else '0';

end architecture synthesis;
