library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;

package fast_sincos_pkg is

   -- C_ANGLE_NUM is the number of CORDIC iterations.
   constant C_GUARD_BITS : natural := 4;
   constant C_SIZE       : natural := 32 + C_GUARD_BITS;

   -- This is just giving a name to a commonly used type.
   -- This type represents an unsigned fractional value, i.e. real number between 0.0 and 1.0.
   subtype  fraction_type is unsigned(C_SIZE - 1 downto 0);

   pure function real2fraction (arg : real) return fraction_type;

   pure function fraction2real (arg : fraction_type) return real;

end package fast_sincos_pkg;

package body fast_sincos_pkg is

   -- The following two helper functions convert between real numbers and the above
   -- fraction_type.

   pure function real2fraction (arg : real) return fraction_type is
      variable tmp_v        : real;
      variable res_v        : fraction_type;
      constant C_SCALE_HIGH : real := 2.0 ** (C_SIZE - 29);
      constant C_SCALE_LOW  : real := 2.0 ** 29;
   begin
      tmp_v                       := arg * C_SCALE_HIGH;
      res_v(C_SIZE - 1 downto 29) := to_unsigned(integer(floor(tmp_v)), C_SIZE - 29);
      tmp_v                       := tmp_v - real(integer(floor(tmp_v)));
      tmp_v                       := tmp_v * C_SCALE_LOW;
      res_v(28 downto 0)          := to_unsigned(integer(tmp_v), 29);
      --report "real2fraction: " & to_string(arg, 11) & " => 0x" & to_hstring(res_v);
      return res_v;
   end function real2fraction;

   pure function fraction2real (arg : fraction_type) return real is
   begin
      return (real(to_integer(arg(C_SIZE - 1 downto 29))) +
              real(to_integer(arg(28 downto 0))) / (2.0 ** 29)) / (2.0 ** (C_SIZE - 29));
   end function fraction2real;

end package body fast_sincos_pkg;

