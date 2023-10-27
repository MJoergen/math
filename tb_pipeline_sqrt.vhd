library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity tb_pipeline_sqrt is
end entity tb_pipeline_sqrt;

architecture sim of tb_pipeline_sqrt is

  signal clk      : std_logic := '0';
  signal data_in  : std_logic_vector(21 downto 0); -- Fixed point 2.20
  signal data_out : std_logic_vector(21 downto 0); -- Fixed point 0.22

begin

  clk <= '1', '0' after 5 ns;

  pipeline_sqrt_inst : entity work.pipeline_sqrt
    port map (
      clk_i  => clk,
      data_i => data_in,
      data_o => data_out
    );

end architecture sim;

