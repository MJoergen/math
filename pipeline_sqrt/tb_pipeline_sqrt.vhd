library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity tb_pipeline_sqrt is
end entity tb_pipeline_sqrt;

architecture sim of tb_pipeline_sqrt is

  signal clk          : std_logic := '0';
  signal test_running : std_logic := '1';
  signal data_in      : std_logic_vector(21 downto 0) := (20 => '1', others => '0'); -- Fixed point 2.20
  signal data_out     : std_logic_vector(21 downto 0);                               -- Fixed point 0.22

  signal data_in_d    : std_logic_vector(21 downto 0) := (others => '0');            -- Fixed point 2.20
  signal data_in_dd   : std_logic_vector(21 downto 0) := (others => '0');            -- Fixed point 2.20

begin

  clk <= test_running and not clk after 5 ns;

  pipeline_sqrt_inst : entity work.pipeline_sqrt
    port map (
      clk_i  => clk,
      data_i => data_in,
      data_o => data_out
    );

  data_proc : process (clk)
  begin
     if rising_edge(clk) then
        data_in <= data_in + 1;
        if data_in = 0 then
           test_running <= '0';
        end if;
     end if;
  end process data_proc;

  validate_proc : process (clk)
  begin
     if rising_edge(clk) then
        data_in_d <= data_in;
        data_in_dd <= data_in_d;
        report "data_in:" & to_hstring(data_in_dd) & ", data_out:" & to_hstring(data_out);
     end if;
  end process validate_proc;

end architecture sim;

