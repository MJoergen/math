library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- Used to populate the lookup tables (BRAMs).

-- This calculates the square root of a number.
-- Input: The range of values is [1, 4[, and the value
--        is encoded as fixed point 2.20.
--        The integer part (upper two bits) must be nonzero.
-- Output: The range of values is [1, 2[, and the
--         fractional part is encoded as fixed point 0.22.

-- Reources:
-- This implementation consists of nothing other than two BRAMs and one DSP.

-- Theory of operation:
-- The calculation performed is x = sqrt(y), where y is the real input number and x is the
-- real output number.
-- The input number y is required to be in the range [1, 4[.
-- 1. First the input number y is decomposed into two parts:
-- y = a + b*eps
-- where a is in the range [1, 4[, b is in the range [0, 1[, and eps = 2^(-9).
-- In this way, the value a can be
-- represented in fixed point 2.9 and the number b in fixed point 0.11
-- 2. Second the number a is used as index into two lookup tables (BRAMs)
-- The first gives f(a) = sqrt(a)-1 represented as fixed point 0.18
-- The second gives g(a) = (2/sqrt(a))-1 represented as fixed point 0.18
-- 3. The formula for calculating x = sqrt(y) is based on a Taylor
-- expansion to first order in eps:
-- sqrt(y) == sqrt(a) + (2/sqrt(a))*b*(eps/4)
-- where "==" means approximately equal to.

entity pipeline_sqrt is
  port (
    clk_i  : in  std_logic;
    data_i : in  std_logic_vector(21 downto 0); -- Fixed point 2.20
    data_o : out std_logic_vector(21 downto 0)  -- Fixed point 0.22
  );
end entity pipeline_sqrt;

architecture rtl of pipeline_sqrt is

  -- Each BRAM can be configured as 2Kx18 bits of storage.
  constant C_BRAM_ADDR_BITS : natural := 11; -- 2K
  constant C_BRAM_DATA_BITS : natural := 18;
  type bram_t is array (natural range 0 to 2**C_BRAM_ADDR_BITS-1) of
                 std_logic_vector(C_BRAM_DATA_BITS-1 downto 0);

  -- This calculates an approximation to the square root
  -- The output format is fixed point 0.18.
  -- This stores the lookup table for the function f(a) = sqrt(a) - 1.
  pure function sqrt_rom_initial return bram_t is
    constant SCALE_IN   : natural := (2**C_BRAM_ADDR_BITS)/4;
    constant SCALE_OUT  : natural := 2**C_BRAM_DATA_BITS;
    variable a_v        : real;
    variable f_v        : real;
    variable scaled_f_v : natural range 0 to SCALE_OUT-1;
    variable res_v      : bram_t := (others => (others => '0'));
  begin
    for i in SCALE_IN to 4*SCALE_IN-1 loop
      a_v := real(i) / real(SCALE_IN); --   a  is in the range [1, 4[
      f_v := sqrt(a_v)-1.0;            -- f(a) is in the range [0, 1[
      scaled_f_v := integer(floor(f_v*real(SCALE_OUT)));
      res_v(i) := std_logic_vector(to_unsigned(scaled_f_v, 18));
--      report "i="&to_string(i)&", sqrt="&to_hstring(res_v(i));
    end loop;
    return res_v;
  end function sqrt_rom_initial;

  -- This calculates an approximation to the inverse square root
  -- The output format is fixed point 0.18
  -- This stores the lookup table for the function g(a) = (2/sqrt(a)) - 1.
  pure function inv_sqrt_rom_initial return bram_t is
    constant SCALE_IN   : natural := (2**C_BRAM_ADDR_BITS)/4;
    constant SCALE_OUT  : natural := 2**C_BRAM_DATA_BITS;
    variable a_v        : real;
    variable g_v        : real;
    variable scaled_g_v : natural range 0 to SCALE_OUT-1;
    variable res_v      : bram_t := (others => (others => '0'));
    variable i          : integer;
  begin
    i := SCALE_IN;
    res_v(i) := (others => '1');
    report "i="&to_string(i)&", inv_sqrt="&to_hstring(res_v(i));

    for i in SCALE_IN + 1 to 4*SCALE_IN-1 loop
      a_v := real(i) / real(SCALE_IN);  --   a  is in the range ]1, 4[
      g_v := 2.0/sqrt(a_v) - 1.0;       -- g(a) is in the range ]0, 1[
      scaled_g_v := integer(floor(g_v*real(SCALE_OUT)));
      res_v(i) := std_logic_vector(to_unsigned(scaled_g_v, 18));
--      report "i="&to_string(i)&", inv_sqrt="&to_hstring(res_v(i));
    end loop;
    return res_v;
  end function inv_sqrt_rom_initial;

  constant C_SQRT_ROM     : bram_t := sqrt_rom_initial;
  constant C_INV_SQRT_ROM : bram_t := inv_sqrt_rom_initial;

  signal stage1_sqrt     : std_logic_vector(17 downto 0);
  signal stage1_inv_sqrt : std_logic_vector(17 downto 0);
  signal stage1_data_lsb : std_logic_vector(10 downto 0);
  signal stage2_data     : std_logic_vector(21 downto 0);

begin

  stage1_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      assert data_i(21 downto 20) /= "00"; -- Integer part must be nonzero
      stage1_sqrt     <= C_SQRT_ROM(    to_integer(unsigned(data_i(21 downto 11))));
      stage1_inv_sqrt <= C_INV_SQRT_ROM(to_integer(unsigned(data_i(21 downto 11))));
      stage1_data_lsb <= data_i(10 downto 0);
    end if;
  end process stage1_proc;

  stage2_proc : process (clk_i)
    variable b_v   : signed(11 downto 0);
    variable g_v   : signed(19 downto 0);
    variable f_v   : signed(32 downto 0);
    variable abc_v : signed(32 downto 0);
  begin
    if rising_edge(clk_i) then
      -- The DSP only works with signed numbers, so we need to prepend
      -- a zero bit, to make sure all values are interpreted as positive.
      f_v := signed("01" & unsigned(stage1_sqrt) & "0000000000000");
      g_v := signed("01" & unsigned(stage1_inv_sqrt));
      b_v := signed("0"  & unsigned(stage1_data_lsb));
      -- Now we calculate: sqrt(a) + (2/sqrt(a))*b*(eps/4)
      abc_v := f_v + b_v * g_v;
      stage2_data <= std_logic_vector(abc_v(32 downto 11));
    end if;
  end process stage2_proc;

  data_o <= stage2_data;

end architecture rtl;

