library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This module takes a floating point number (exp_i, mant_i) and returns the
-- sine and cosing as a floating point number (exp_o, mant_o).
--
-- It takes a total of 34 clock cycles to perform the calculation.
-- It calculates one extra bit in order to perform the correct rounding.
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

entity fast_sincos is
   port (
      clk_i   : in  std_logic;
      start_i : in  std_logic;                -- Assert to restart calculation.
      ready_o : out std_logic := '1';         -- Asserted when output is ready.
      exp_i   : in  unsigned( 7 downto 0);    -- Exponent
      mant_i  : in  unsigned(31 downto 0);    -- Mantissa
      exp_o   : out unsigned( 7 downto 0);    -- Exponent
      mant_o  : out unsigned(31 downto 0)     -- Mantissa
   );
end entity fast_sincos;

architecture synthesis of fast_sincos is

begin

end architecture synthesis;

