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
    -- Un simple contador de 10 bits
    signal counter : unsigned(9 downto 0) := (others => '0');
begin

    process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if reset = '1' then
                counter <= (others => '0');
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    -- Extraemos los relojes directamente de los bits del contador
    -- Bit 1 cambia cada 2 ciclos (50MHz / 4)
    mclk <= counter(1); 
    
    -- Bit 3 cambia cada 8 ciclos (50MHz / 16)
    bclk <= counter(3); 
    
    -- Bit 9 cambia cada 512 ciclos (50MHz / 1024)
    lrck <= counter(9); 

end architecture rtl;