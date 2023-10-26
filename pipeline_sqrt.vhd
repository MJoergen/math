library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use ieee.math_real.all;

-- This calculates the square root of a number.
-- Input: The range of values is [1, 4[, and the value
--        is encoded as fixed point 2.27.
--        The integer part (upper two bits) must be nonzero.
-- Output: The range of values is [1, 2[, and the
--         fractional part is encoded as fixed point 0.29.

-- Resources used:
-- 2 BRAMs
-- 1 DSP

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
    data_i : in  std_logic_vector(28 downto 0); -- Fixed point 2.27
    data_o : out std_logic_vector(28 downto 0)  -- Fixed point 0.29
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
      res_v(i) := to_stdlogicvector(integer(floor((y_v-1.0)*SCALE_OUT)), 18);
      report "i="&to_string(i)&", sqrt="&to_hstring(res_v(i));
    end loop;
    return res_v;
  end function sqrt_rom_initial;

  -- This calculates the error in the approximation
  pure function diff_rom_initial return bram_t is
    constant SCALE_IN  : real := 2.0**(C_BRAM_ADDR_BITS-2);
    constant SCALE_OUT : real := 2.0**C_BRAM_DATA_BITS;
    variable x_v       : real;
    variable y_v       : real;
    variable res_v     : bram_t := (others => (others => '0'));
  begin
    for i in 2**(C_BRAM_ADDR_BITS-2) to 2**C_BRAM_ADDR_BITS-1 loop
      x_v := real(i) / SCALE_IN; -- x is in the range [1, 4[
      y_v := sqrt(x_v);          -- y is in the range [1, 2[
      y_v := floor((y_v-1.0)*SCALE_OUT)/SCALE_OUT + 1.0; -- y is still in the range [1, 2[
      res_v(i) := to_stdlogicvector(integer(floor((y_v-1.0)*SCALE_OUT)), 18);
      report "i="&to_string(i)&", sqrt="&to_hstring(res_v(i));
    end loop;
    return res_v;
  end function diff_rom_initial;

  -- This calculates an approximation to the inverse square root
  -- The output format is fixed point 0.18
  pure function inv_sqrt_rom_initial return bram_t is
    constant SCALE_IN  : real := 2.0**(C_BRAM_ADDR_BITS-2);
    constant SCALE_OUT : real := 2.0**C_BRAM_DATA_BITS;
    variable x_v       : real;
    variable y_v       : real;
    variable res_v     : bram_t := (others => (others => '0'));
  begin
    for i in 2**(C_BRAM_ADDR_BITS-2)+1 to 2**C_BRAM_ADDR_BITS-1 loop
      x_v := real(i) / SCALE_IN; -- x is in the range ]1, 4[
      y_v := 2.0/sqrt(x_v);      -- y is in the range ]1, 2[
      res_v(i) := to_stdlogicvector(integer(floor((y_v-1.0)*SCALE_OUT)), 18);
      report "i="&to_string(i)&", inv_sqrt="&to_hstring(res_v(i));
    end loop;
    return res_v;
  end function inv_sqrt_rom_initial;

  constant C_SQRT_ROM     : bram_t := sqrt_rom_initial;
  constant C_DIFF_ROM     : bram_t := diff_rom_initial;
  constant C_INV_SQRT_ROM : bram_t := inv_sqrt_rom_initial;

  signal stage1_sqrt     : std_logic_vector(17 downto 0);
  signal stage1_inv_sqrt : std_logic_vector(17 downto 0);
  signal stage2_data     : std_logic_vector(17 downto 0);

begin

  stage1_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      assert data_i(28 downto 27) /= "00"; -- Integer part must be nonzero
      stage1_sqrt     <= C_SQRT_ROM(    to_integer(data_i(28 downto 18)));
      stage1_inv_sqrt <= C_INV_SQRT_ROM(to_integer(data_i(28 downto 18)));
    end if;
  end process stage1_proc;

  stage2_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      stage2_data <= stage1_sqrt + stage1_inv_sqrt;
    end if;
  end process stage2_proc;

  data_o(17 downto 0) <= stage2_data;

end architecture rtl;

