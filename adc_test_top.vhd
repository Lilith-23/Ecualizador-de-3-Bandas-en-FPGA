library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_test_top is
    port (
        MAX10_CLK1_50 : in std_logic;
        KEY           : in std_logic_vector(1 downto 0);
        
        -- Interfaz I2S (Mapeada a tus nuevos pines)
        I2S_MCLK      : out std_logic;
        I2S_BCLK      : out std_logic;
        I2S_LRCK      : out std_logic;
        I2S_ADC_DOUT  : in  std_logic;
        I2S_DAC_DIN   : out std_logic;
        
        LEDR          : out std_logic_vector(9 downto 0)
    );
end entity adc_test_top;

architecture rtl of adc_test_top is

    signal clk_mclk : std_logic;
    signal clk_bclk : std_logic;
    signal clk_lrck : std_logic;
    
    -- Cables virtuales de audio y sincronización
    signal audio_left  : std_logic_vector(23 downto 0);
    signal audio_right : std_logic_vector(23 downto 0);
    signal audio_sync  : std_logic;

    -- Señales para el latido (Heartbeat)
    signal blink_counter : integer range 0 to 50000000 := 0;
    signal blink_state   : std_logic := '0';

    -- 1. Generador de Relojes
    component i2s_master_clocks is
        port(
            clk_50mhz : in  std_logic;
            reset     : in  std_logic;
            mclk      : out std_logic;
            bclk      : out std_logic;
            lrck      : out std_logic
        );
    end component;

    -- 2. Receptor (ADC)
    component i2s_rx is
        Port (
            clk_50mhz   : in  STD_LOGIC; -- ¡Este es el que faltaba!
            reset       : in  STD_LOGIC;
            BCLK        : in  STD_LOGIC;
            LRCK        : in  STD_LOGIC;
            DIN         : in  STD_LOGIC; 
            audio_left  : out STD_LOGIC_VECTOR(23 downto 0);
            audio_right : out STD_LOGIC_VECTOR(23 downto 0);
            data_ready  : out STD_LOGIC
        );
    end component;

    -- 3. Transmisor (DAC)
    /*component i2s_tx is
        Port (
            clk_50mhz   : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            BCLK        : in  STD_LOGIC;
            LRCK        : in  STD_LOGIC;
            DOUT        : out STD_LOGIC;
            data_valid  : in  STD_LOGIC;
            audio_left  : in  STD_LOGIC_VECTOR(23 downto 0);
            audio_right : in  STD_LOGIC_VECTOR(23 downto 0)
        );
    end component;*/

begin

    u_clocks: i2s_master_clocks
    port map (
        clk_50mhz => MAX10_CLK1_50,
        reset     => '0', 
        mclk      => clk_mclk,
        bclk      => clk_bclk,
        lrck      => clk_lrck
    );

    u_rx: i2s_rx
    port map (
        clk_50mhz   => MAX10_CLK1_50,  -- ¡El latido de vida para el módulo!
        reset       => KEY(0),         -- Botón físico de reset
        BCLK        => clk_bclk,
        LRCK        => clk_lrck,
        DIN         => I2S_ADC_DOUT, 
        audio_left  => audio_left,
        audio_right => audio_right,
        data_ready  => open            -- Dejamos este pin libre porque no lo usamos para los LEDs
    );

    /*u_tx: i2s_tx
    port map (
        clk_50mhz   => MAX10_CLK1_50,
        reset       => KEY(0),
        BCLK        => clk_bclk,
        LRCK        => clk_lrck,
        DOUT        => I2S_DAC_DIN,
        data_valid  => audio_sync,
        audio_left  => audio_left,
        audio_right => audio_right
    );*/

    -- Salida de relojes físicos
    I2S_MCLK <= clk_mclk;
    I2S_BCLK <= clk_bclk;
    I2S_LRCK <= clk_lrck;

    -- Generador del Latido a 1 Hz
    process(MAX10_CLK1_50)
    begin
        if rising_edge(MAX10_CLK1_50) then
            if blink_counter = 25000000 then
                blink_state <= not blink_state;
                blink_counter <= 0;
            else
                blink_counter <= blink_counter + 1;
            end if;
        end if;
    end process;

    -- ==============================================================
    -- RECUPERACIÓN DE LA CONFIRMACIÓN VISUAL EN LOS LEDs
    -- ==============================================================

    -- LED 9: Latido (Parpadea a 1 Hz. Confirma que la FPGA está viva).
    LEDR(9) <= blink_state;

    -- LEDs 8 al 4: Visualizador de audio. 
    -- (OJO: Usamos los bits 14 al 10 para que reaccionen a un volumen normal, no solo al máximo).
    LEDR(8 downto 4) <= audio_left(14 downto 10); 
    
    -- LED 3: Sonda de recepción de datos del ADC. (Debe verse con brillo tenue).
    LEDR(3) <= I2S_ADC_DOUT;   

    -- LEDs 2, 1 y 0: Sondas de los relojes. (Deben verse con brillo tenue constante).
    LEDR(2) <= clk_mclk;       
    LEDR(1) <= clk_bclk;       
    LEDR(0) <= clk_lrck;       

end architecture rtl;