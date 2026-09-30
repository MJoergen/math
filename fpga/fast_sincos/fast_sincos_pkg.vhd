library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

-- This package provides a convenient type fraction_type.
-- It can either represent an unsigned real value in [0.0, 2.0[,
-- or a signed real value in [-1.0, 1.0[.
package fast_sincos_pkg is

   -- The nominal precision of the fraction_type is 32 bits.
   -- However, to avoid accumulation of rounding errors, some
   -- additional guard bits are added.
   constant C_GUARD_BITS : natural := 7;
   constant C_SIZE       : natural := 32 + C_GUARD_BITS;

   subtype  fraction_type is unsigned(C_SIZE downto 0);

   -- The following two helper functions convert between real numbers and the above
   -- fraction_type.

   pure function real2fraction (arg : real) return fraction_type;

   pure function fraction2real (arg : fraction_type) return real;

end package fast_sincos_pkg;

package body fast_sincos_pkg is

   -- Expects a real number in the interval [0.0, 1.0[.
   pure function real2fraction (arg : real) return fraction_type is
      variable tmp_v        : real;
      variable res_v        : fraction_type;
      constant C_SCALE_HIGH : real := 2.0 ** (C_SIZE - 29);
      constant C_SCALE_LOW  : real := 2.0 ** 29;
   begin
      tmp_v                       := arg * C_SCALE_HIGH;
      res_v(C_SIZE)               := '0';
      res_v(C_SIZE - 1 downto 29) := to_unsigned(integer(floor(tmp_v)), C_SIZE - 29);
      tmp_v                       := tmp_v - real(integer(floor(tmp_v)));
      tmp_v                       := tmp_v * C_SCALE_LOW;
      res_v(28 downto 0)          := to_unsigned(integer(tmp_v), 29);
      return res_v;
   end function real2fraction;

   -- Returns a real number in the interval [-1.0, 1.0[.
   pure function fraction2real (arg : fraction_type) return real is
      constant C_SCALE_HIGH : real := 2.0 ** (C_SIZE - 29);
      constant C_SCALE_LOW  : real := 2.0 ** 29;
   begin
      if arg(C_SIZE) = '0' then
         return (real(to_integer(arg(C_SIZE - 1 downto 29))) +
                 real(to_integer(arg(28 downto 0))) / C_SCALE_LOW) / C_SCALE_HIGH;
      else
         return (real(to_integer(arg(C_SIZE - 1 downto 29))) +
                 real(to_integer(arg(28 downto 0))) / C_SCALE_LOW) / C_SCALE_HIGH - 1.0;
      end if;
   end function fraction2real;

end package body fast_sincos_pkg;

