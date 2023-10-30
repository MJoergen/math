library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- Used to populate the lookup tables (BRAMs).

-- This calculates the square root of a number.
-- Input: The range of values is [1, 4[, and the value
--        is encoded as fixed point 2.20.
--        The integer part (upper two bits) must be nonzero.
-- Output: The range of values is [1, 2[, and the
--         fractional part is encoded as fixed point 0.22 (the integer part is constant 1).

-- FPGA Reources:
-- This implementation uses two BRAMs and one DSP, and a small amount of extra logic.

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
-- In general we have f(a+b*eps) == f(a) + f'(a)*b*eps
-- where "==" means approximately equal to.
-- Here we use f(y) = sqrt(y), and we thus get
-- sqrt(y) == sqrt(a) + (2/sqrt(a))*b*(eps/4)

entity pipeline_sqrt is
  generic (
    G_EXTRA_BITS : natural
  );
  port (
    clk_i  : in  std_logic;
    data_i : in  std_logic_vector(21 downto 0); -- Fixed point 2.20
    data_o : out std_logic_vector(21 downto 0)  -- Fixed point 0.22
  );
end entity pipeline_sqrt;

architecture rtl of pipeline_sqrt is

  -- Convert a fixed-point number in i.f format to a real number
  pure function fixed_to_real(arg : std_logic_vector;
                                i : natural;
                                f : natural) return real is
  begin
    return real(to_integer(unsigned(arg))) / (2.0 ** f);
  end function fixed_to_real;

  -- Convert a real number to a fixed-point number in i.f format
  pure function real_to_fixed(arg : real;
                                i : natural;
                                f : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(integer(floor(arg * (2.0**f))), i+f));
  end function real_to_fixed;


  -- Each BRAM can be configured as 2Kx18 bits of storage.
  constant C_BRAM_ADDR_BITS : natural := 11; -- 2K
  constant C_BRAM_DATA_BITS : natural := 18;
  type bram_t is array (natural range 0 to 2**C_BRAM_ADDR_BITS-1) of
                 std_logic_vector(C_BRAM_DATA_BITS-1 downto 0);


  -- This calculates an approximation to the square root
  -- The output format is fixed point 0.18.
  -- This stores the lookup table for the function f(a) = sqrt(a) - 1.
  pure function sqrt_rom_low_initial return bram_t is
    constant SCALE_IN   : natural := (2**C_BRAM_ADDR_BITS)/4;
    variable a_v        : real;
    variable f_v        : real;
    variable sqrt_v     : std_logic_vector(C_BRAM_DATA_BITS-1+G_EXTRA_BITS downto 0);
    variable res_v      : bram_t := (others => (others => '0'));
  begin
    for i in SCALE_IN to 4*SCALE_IN-1 loop
      a_v      := real(i) / real(SCALE_IN); --   a  is in the range [1, 4[
      f_v      := sqrt(a_v)-1.0;            -- f(a) is in the range [0, 1[
      sqrt_v   := real_to_fixed(f_v, 0, C_BRAM_DATA_BITS + G_EXTRA_BITS);
      res_v(i) := sqrt_v(C_BRAM_DATA_BITS-1 downto 0);
--      report "i="&to_string(i)&", sqrt_low="&to_hstring(res_v(i));
    end loop;
    return res_v;
  end function sqrt_rom_low_initial;

  pure function sqrt_rom_high_initial return bram_t is
    constant SCALE_IN   : natural := (2**C_BRAM_ADDR_BITS)/4;
    variable a_v        : real;
    variable f_v        : real;
    variable sqrt_v     : std_logic_vector(C_BRAM_DATA_BITS-1+G_EXTRA_BITS downto 0);
    variable res_v      : bram_t := (others => (others => '0'));
  begin
    for i in SCALE_IN to 4*SCALE_IN-1 loop
      a_v      := real(i) / real(SCALE_IN); --   a  is in the range [1, 4[
      f_v      := sqrt(a_v)-1.0;            -- f(a) is in the range [0, 1[
      sqrt_v   := real_to_fixed(f_v, 0, C_BRAM_DATA_BITS + G_EXTRA_BITS);
      res_v(i)(C_BRAM_DATA_BITS-1 downto C_BRAM_DATA_BITS-G_EXTRA_BITS) :=
        sqrt_v(C_BRAM_DATA_BITS+G_EXTRA_BITS-1 downto C_BRAM_DATA_BITS);
--      report "i="&to_string(i)&", sqrt_high="&to_hstring(res_v(i));
    end loop;
    return res_v;
  end function sqrt_rom_high_initial;

  -- This calculates an approximation to the inverse square root
  -- The output format is fixed point 0.18
  -- This stores the lookup table for the function g(a) = (2/sqrt(a)) - 1.
  pure function inv_sqrt_rom_initial return bram_t is
    constant SCALE_IN   : natural := (2**C_BRAM_ADDR_BITS)/4;
    variable a_v        : real;
    variable g_v        : real;
    variable res_v      : bram_t := (others => (others => '0'));
  begin
    for i in SCALE_IN to 4*SCALE_IN-1 loop
      a_v := (real(i) + 0.5) / real(SCALE_IN);  --   a  is in the range ]1, 4[
      g_v := 2.0/sqrt(a_v) - 1.0;               -- g(a) is in the range ]0, 1[
      res_v(i)   := real_to_fixed(g_v, 0, C_BRAM_DATA_BITS);
--      report "i="&to_string(i)&", inv_sqrt="&to_hstring(res_v(i));
    end loop;
    return res_v;
  end function inv_sqrt_rom_initial;

  constant C_SQRT_ROM_LOW  : bram_t := sqrt_rom_low_initial;
  constant C_SQRT_ROM_HIGH : bram_t := sqrt_rom_high_initial;
  constant C_INV_SQRT_ROM  : bram_t := inv_sqrt_rom_initial;

  signal stage1_sqrt_low  : std_logic_vector(C_BRAM_DATA_BITS-1 downto 0);
  signal stage1_sqrt_high : std_logic_vector(G_EXTRA_BITS-1 downto 0);
  signal stage1_inv_sqrt  : std_logic_vector(C_BRAM_DATA_BITS-1 downto 0);
  signal stage1_data_lsb  : std_logic_vector(10 downto 0);
  signal stage1_b         : signed(11 downto 0);
  signal stage1_g         : signed(19 downto 0);
  signal stage1_f         : signed(40 downto 0) := (others => '0');
  signal stage1_abc       : signed(40 downto 0);

  signal stage2_data      : std_logic_vector(21 downto 0);

begin

  stage1_proc : process (clk_i)
    variable ram_addr_v : natural range 0 to 2**C_BRAM_ADDR_BITS-1;
  begin
    if rising_edge(clk_i) then
      assert data_i(21 downto 20) /= "00"; -- Integer part must be nonzero

      -- Calculate the lookup address
      ram_addr_v := to_integer(unsigned(data_i(21 downto 11)));

      -- Perform the ROM lookups
      stage1_sqrt_low  <= C_SQRT_ROM_LOW(ram_addr_v);
      stage1_sqrt_high <= C_SQRT_ROM_HIGH(ram_addr_v)(C_BRAM_DATA_BITS-1 downto C_BRAM_DATA_BITS-G_EXTRA_BITS);
      stage1_inv_sqrt  <= C_INV_SQRT_ROM(ram_addr_v);
      stage1_data_lsb  <= data_i(10 downto 0);
    end if;
  end process stage1_proc;

  -- The DSP only works with signed numbers, so we need to prepend
  -- a zero bit, to make sure all values are interpreted as positive.
  stage1_f(40-G_EXTRA_BITS downto 22-G_EXTRA_BITS) <= signed("0" & unsigned(stage1_sqrt_low));
  stage1_g <= signed("01" & unsigned(stage1_inv_sqrt));
  stage1_b <= signed("0"  & unsigned(stage1_data_lsb));

  -- Now we calculate: sqrt(a) + (2/sqrt(a))*b*(eps/4)
  stage1_abc <= stage1_f + stage1_b * stage1_g;

  stage2_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- Combine the final result
      stage2_data <= stage1_sqrt_high & std_logic_vector(stage1_abc(39-G_EXTRA_BITS downto 18));
    end if;
  end process stage2_proc;

  data_o <= stage2_data;

end architecture rtl;

