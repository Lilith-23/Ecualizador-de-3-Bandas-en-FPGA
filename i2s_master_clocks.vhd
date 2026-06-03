library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2s_master_clocks is
    Port (
        clk_50mhz : in  STD_LOGIC;  -- Reloj maestro de la DE10-Lite (50 MHz)
        reset     : in  STD_LOGIC;  -- Botón de reinicio (activo en bajo)
        
        -- Señales para el Bus I2S
        MCLK      : out STD_LOGIC;  -- System Clock (SCK) para el ADC (12.5 MHz)
        BCLK      : out STD_LOGIC;  -- Bit Clock (BCK) para ADC y DAC (3.125 MHz)
        LRCK      : out STD_LOGIC   -- Left/Right Clock (Frecuencia de Muestreo 48.8 kHz)
    );
end i2s_master_clocks;

architecture Behavioral of i2s_master_clocks is

    -- Contador de 10 bits para dividir la frecuencia
    signal contador : unsigned(9 downto 0) := (others => '0');

begin

    -- Proceso secuencial para incrementar el contador maestro
    process(clk_50mhz, reset)
    begin
        if reset = '0' then  -- Lógica negativa típica de los botones de la DE10-Lite
            contador <= (others => '0');
        elsif rising_edge(clk_50mhz) then
            contador <= contador + 1;
        end if;
    end process;

    -- Asignación concurrente de los relojes extrayendo bits del contador
    -- Al extraer bits específicos, creamos divisores de frecuencia exactos
    
    -- bit(1) divide el reloj entre 4. (50 MHz / 4 = 12.5 MHz) -> 256 * Fs
    MCLK <= contador(1);  
    
    -- bit(3) divide el reloj entre 16. (50 MHz / 16 = 3.125 MHz) -> 64 * Fs
    BCLK <= contador(3);  
    
    -- bit(9) divide el reloj entre 1024. (50 MHz / 1024 = 48.828 kHz) -> Fs
    LRCK <= contador(9);  

end Behavioral;