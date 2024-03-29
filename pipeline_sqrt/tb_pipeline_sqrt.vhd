library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use ieee.math_real.all;

entity tb_pipeline_sqrt is
  generic (
    G_EXTRA_BITS : natural
  );
end entity tb_pipeline_sqrt;

architecture sim of tb_pipeline_sqrt is

  signal clk          : std_logic := '0';
  signal test_running : std_logic := '1';
  signal data_in      : std_logic_vector(21 downto 0) := (20 => '1', others => '0'); -- Fixed point 2.20
  signal data_out     : std_logic_vector(21 downto 0);                               -- Fixed point 0.22

  signal data_in_d    : std_logic_vector(21 downto 0) := (20 => '1', others => '0'); -- Fixed point 2.20
  signal data_in_dd   : std_logic_vector(21 downto 0) := (20 => '1', others => '0'); -- Fixed point 2.20
  signal max_diff     : std_logic_vector(21 downto 0) := (others => '0');

begin

  clk <= test_running and not clk after 5 ns; -- 100 MHz

  pipeline_sqrt_inst : entity work.pipeline_sqrt
    generic map (
      G_EXTRA_BITS => G_EXTRA_BITS
    )
    port map (
      clk_i  => clk,
      data_i => data_in,
      data_o => data_out
    );

  data_proc : process (clk)
  begin
     if rising_edge(clk) then
        data_in <= data_in + 1;
        if and(data_in) = '1' then
           test_running <= '0';
        end if;
     end if;
  end process data_proc;

  validate_proc : process (clk)
     variable y_v            : real;
     variable x_v            : real;
     variable exp_data_out_v : std_logic_vector(21 downto 0);
     variable diff_v         : std_logic_vector(21 downto 0);
  begin
     if rising_edge(clk) then
        data_in_d <= data_in;
        data_in_dd <= data_in_d;
        y_v := real(to_integer(data_in_dd)) / (2.0**20);
        x_v := real(to_integer("1" & data_out)) / (2.0**22);
        exp_data_out_v := to_stdlogicvector(integer(floor((sqrt(y_v)-1.0)*(2.0**22))), 22);

        if data_out /= exp_data_out_v then
           if data_out > exp_data_out_v then
              diff_v := data_out - exp_data_out_v;
           else
              diff_v := exp_data_out_v - data_out;
           end if;
           if diff_v > max_diff then
              max_diff <= diff_v;
              report "data_in:" & to_hstring(data_in_dd) & ", data_out:" & to_hstring(data_out) & ", exp_data_out:" & to_hstring(exp_data_out_v);
           end if;
        end if;
        --report "data_in:" & to_string(y_v,6) & ", data_out:" & to_string(x_v,6) & ", exp_out:" & to_string(sqrt(y_v),6);
     end if;
  end process validate_proc;

end architecture sim;

