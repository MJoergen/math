library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

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
-- where eps = 2^(-9), and b is in the range [0, 1[. In this way, the value a can be
-- represented in fixed point 2.9 and the number b in fixed point 0.11
-- 2. Second the number a is used as index into two lookup tables (BRAMs)
-- The first gives f(a) = sqrt(a)-1 represented as fixed point 0.18
-- The second gives g(a) = (2/sqrt(a))-1 represented as fixed point 0.18


-- The calculation is in two stages:
-- Stage 1 : Get an initial good approximation to the result.
-- Stage 2 : Refine the result by one iteration of Newtons method.
-- The latency is therefore 2 clock cycles, and the calculation is pipelined,
-- and a new calculation may be initiated every clock cycle.

-- Stage 1 is done by performing lookups in the two BRAMs, using the first 11 bits
-- (2.9 fixed point format).

-- Stage 1 details.
-- The two lookups use only the top 11 bits of x, i.e. it truncates x to a
-- fixed point 2.9 value. The truncated value is called x_bar, and we thus have
-- 0 <= x - x_bar < 2^(-9)
-- The output of the lookup is itself a truncated value of sqrt(x_bar) in
-- fixed point 0.18.
-- We call the output y_bar, and we thus have
-- 0 <= sqrt(x_bar) - y_bar < 2^(-18).

-- The two lookups take a value 1 < x < 4 and generate two values y0 and z0, where
-- y0 = floor(sqrt(x))
-- z0 = floor(2/sqrt(x))
--
-- y0 is thus an approximation to the final result.
--
-- 

entity pipeline_sqrt is
  port (
    clk_i  : in  std_logic;
    data_i : in  std_logic_vector(21 downto 0); -- Fixed point 2.20
    data_o : out std_logic_vector(21 downto 0)  -- Fixed point 0.22
  );
end entity pipeline_sqrt;

architecture rtl of pipeline_sqrt is

  -- Each BRAM can be configured as a 2Kx18 bits of storage.
  constant C_BRAM_ADDR_BITS : natural := 11; -- 2K
  constant C_BRAM_DATA_BITS : natural := 18;
  type bram_t is array (natural range 0 to 2**C_BRAM_ADDR_BITS-1) of
                 std_logic_vector(C_BRAM_DATA_BITS-1 downto 0);

  -- This calculates an approximation to the square root
  -- The output format is fixed point 0.18
  pure function sqrt_rom_initial return bram_t is
    constant SCALE_IN  : real := 2.0**(C_BRAM_ADDR_BITS-2);
    constant SCALE_OUT : real := 2.0**C_BRAM_DATA_BITS;
    variable x_v       : real;
    variable y_v       : real;
    variable res_v     : bram_t := (others => (others => '0'));
  begin
    for i in 2**(C_BRAM_ADDR_BITS-2) to 2**C_BRAM_ADDR_BITS-1 loop
      x_v := real(i) / SCALE_IN; -- x is in the range [1, 4[
      y_v := sqrt(x_v);          -- y is in the range [1, 2[
      res_v(i) := std_logic_vector(to_unsigned(integer(floor((y_v-1.0)*SCALE_OUT)), 18));
      report "i="&to_string(i)&", sqrt="&to_hstring(res_v(i));
    end loop;
    return res_v;
  end function sqrt_rom_initial;

  -- This calculates an approximation to the inverse square root
  -- The output format is fixed point 0.18
  pure function inv_sqrt_rom_initial return bram_t is
    constant SCALE_IN  : real := 2.0**(C_BRAM_ADDR_BITS-2);
    constant SCALE_OUT : real := 2.0**C_BRAM_DATA_BITS;
    variable x_v       : real;
    variable y_v       : real;
    variable res_v     : bram_t := (others => (others => '0'));
    variable i         : integer;
  begin
    i := 2**(C_BRAM_ADDR_BITS-2);
    res_v(i) := (others => '1');
    report "i="&to_string(i)&", inv_sqrt="&to_hstring(res_v(i));

    for i in 2**(C_BRAM_ADDR_BITS-2)+1 to 2**C_BRAM_ADDR_BITS-1 loop
      x_v := real(i) / SCALE_IN; -- x is in the range ]1, 4[
      y_v := 2.0/sqrt(x_v);      -- y is in the range ]1, 2[
      res_v(i) := std_logic_vector(to_unsigned(integer(floor((y_v-1.0)*SCALE_OUT)), 18));
      report "i="&to_string(i)&", inv_sqrt="&to_hstring(res_v(i));
    end loop;
    return res_v;
  end function inv_sqrt_rom_initial;

  constant C_SQRT_ROM     : bram_t := sqrt_rom_initial;
  constant C_INV_SQRT_ROM : bram_t := inv_sqrt_rom_initial;

  signal stage1_data     : std_logic_vector(21 downto 0);
  signal stage1_sqrt     : std_logic_vector(17 downto 0);
  signal stage1_inv_sqrt : std_logic_vector(17 downto 0);
  signal stage2_data     : std_logic_vector(21 downto 0);

begin

  stage1_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      assert data_i(21 downto 20) /= "00"; -- Integer part must be nonzero
      stage1_sqrt     <= C_SQRT_ROM(    to_integer(unsigned(data_i(21 downto 11))));
      stage1_inv_sqrt <= C_INV_SQRT_ROM(to_integer(unsigned(data_i(21 downto 11))));
      stage1_data     <= data_i;
    end if;
  end process stage1_proc;

  stage2_proc : process (clk_i)
    variable a_v   : signed(18 downto 0);
    variable b_v   : signed(11 downto 0);
    variable c_v   : signed(18 downto 0);
    variable abc_v : signed(30 downto 0);
  begin
    if rising_edge(clk_i) then
      -- The DSP only works with signed numbers, so we need to prepend
      -- a zero bit, to make sure all values are interpreted as positive.
      a_v := signed("0" & unsigned(stage1_inv_sqrt));
      b_v := signed("0" & unsigned(stage1_data(10 downto 0)));
      c_v := signed("0" & unsigned(stage1_sqrt));
      abc_v := a_v * b_v + c_v;
      stage2_data <= std_logic_vector(abc_v(30 downto 9));
    end if;
  end process stage2_proc;

  data_o <= stage2_data;

end architecture rtl;

