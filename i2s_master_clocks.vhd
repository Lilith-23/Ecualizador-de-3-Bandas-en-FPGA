library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_master_clocks is
    port(
        clk_50mhz : in  std_logic;
        reset     : in  std_logic;
        mclk      : out std_logic;
        bclk      : out std_logic;
        lrck      : out std_logic
    );
end entity i2s_master_clocks;

architecture rtl of i2s_master_clocks is
    signal counter : unsigned(9 downto 0) := (others => '0');
begin
    process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if reset = '0' then -- Lógica negativa (botón presionado)
                counter <= (others => '0');
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    -- mclk: 12.5 MHz, bclk: 3.125 MHz, lrck: 48.828 kHz
    mclk <= counter(1);
    bclk <= counter(3);
    lrck <= counter(9);
end architecture rtl;