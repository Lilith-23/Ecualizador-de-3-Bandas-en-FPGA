library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity eq_top is
    Port (
        -- Entradas de la Tarjeta DE10-Lite
        MAX10_CLK1_50 : in  STD_LOGIC;  -- Reloj principal de 50 MHz
        KEY0          : in  STD_LOGIC;  -- Botón para reset
        SW           : in  STD_LOGIC_VECTOR(2 downto 0);  -- Switches para seleccionar la banda a ecualizar
		  
        -- Entradas desde el ADC PCM1808
        I2S_ADC_DOUT  : in  STD_LOGIC;  -- Datos de audio entrantes
        
        -- Salidas hacia los convertidores (ADC y DAC)
        I2S_MCLK      : out STD_LOGIC;  -- Reloj maestro del sistema para el ADC
        I2S_BCLK      : out STD_LOGIC;  -- Reloj de bit (Compartido para ADC y DAC)
        I2S_LRCK      : out STD_LOGIC;  -- Reloj de canal/muestreo (Compartido para ADC y DAC)
        
        -- Salida hacia el DAC PCM5102A
        I2S_DAC_DIN   : out STD_LOGIC   -- Datos de audio procesados
    );
end eq_top;

architecture Structural of eq_top is

    -- Declaración de los 4 componentes que ya creamos
    component i2s_master_clocks is
        Port ( clk_50mhz : in STD_LOGIC; reset : in STD_LOGIC;
               MCLK : out STD_LOGIC; BCLK : out STD_LOGIC; LRCK : out STD_LOGIC );
    end component;

    component i2s_rx is
        Port ( clk_50mhz : in STD_LOGIC; reset : in STD_LOGIC;
               BCLK : in STD_LOGIC; LRCK : in STD_LOGIC; DIN : in STD_LOGIC;
               audio_left : out STD_LOGIC_VECTOR(23 downto 0);
               audio_right : out STD_LOGIC_VECTOR(23 downto 0);
               data_ready : out STD_LOGIC );
    end component;

    component i2s_dsp is
        Port ( clk_50mhz : in STD_LOGIC; reset : in STD_LOGIC;
               data_ready : in STD_LOGIC; audio_left_in : in STD_LOGIC_VECTOR(23 downto 0);
               audio_right_in : in STD_LOGIC_VECTOR(23 downto 0); sw_band_ctrl : in STD_LOGIC_VECTOR;
               audio_left_out : out STD_LOGIC_VECTOR(23 downto 0);
               audio_right_out : out STD_LOGIC_VECTOR(23 downto 0);
               data_valid : out STD_LOGIC );
    end component;

    component i2s_tx is
        Port ( clk_50mhz : in STD_LOGIC; reset : in STD_LOGIC;
               BCLK : in STD_LOGIC; LRCK : in STD_LOGIC; DOUT : out STD_LOGIC;
               data_valid : in STD_LOGIC; audio_left : in STD_LOGIC_VECTOR(23 downto 0);
               audio_right : in STD_LOGIC_VECTOR(23 downto 0) );
    end component;

    -- "Cables" internos para conectar los bloques entre sí
    signal clk_bclk_sig      : STD_LOGIC;
    signal clk_lrck_sig      : STD_LOGIC;
    
    signal rx_ready_sig      : STD_LOGIC;
    signal left_rx_to_dsp    : STD_LOGIC_VECTOR(23 downto 0);
    signal right_rx_to_dsp   : STD_LOGIC_VECTOR(23 downto 0);
    
    signal dsp_valid_sig     : STD_LOGIC;
    signal left_dsp_to_tx    : STD_LOGIC_VECTOR(23 downto 0);
    signal right_dsp_to_tx   : STD_LOGIC_VECTOR(23 downto 0);

begin

    -- Enrutamos los relojes generados hacia los pines físicos exteriores
    I2S_BCLK <= clk_bclk_sig;
    I2S_LRCK <= clk_lrck_sig;

    -- Instancia 1: El Corazón (Generador de relojes)
    Inst_Clocks: i2s_master_clocks port map(
        clk_50mhz => MAX10_CLK1_50,
        reset     => KEY0,
        MCLK      => I2S_MCLK,
        BCLK      => clk_bclk_sig,
        LRCK      => clk_lrck_sig
    );

    -- Instancia 2: Los Oídos (Receptor RX)
    Inst_RX: i2s_rx port map(
        clk_50mhz   => MAX10_CLK1_50,
        reset       => KEY0,
        BCLK        => clk_bclk_sig,
        LRCK        => clk_lrck_sig,
        DIN         => I2S_ADC_DOUT,
        audio_left  => left_rx_to_dsp,
        audio_right => right_rx_to_dsp,
        data_ready  => rx_ready_sig
    );

    -- Instancia 3: El Cerebro (Procesador DSP y Limitador)
    Inst_DSP: i2s_dsp port map(
        clk_50mhz       => MAX10_CLK1_50,
        reset           => KEY0,
        data_ready      => rx_ready_sig,
        audio_left_in   => left_rx_to_dsp,
        audio_right_in  => right_rx_to_dsp,
        sw_band_ctrl    => SW,
        audio_left_out  => left_dsp_to_tx,
        audio_right_out => right_dsp_to_tx,
        data_valid      => dsp_valid_sig
    );

    -- Instancia 4: La Boca (Transmisor TX)
    Inst_TX: i2s_tx port map(
        clk_50mhz   => MAX10_CLK1_50,
        reset       => KEY0,
        BCLK        => clk_bclk_sig,
        LRCK        => clk_lrck_sig,
        DOUT        => I2S_DAC_DIN,
        data_valid  => dsp_valid_sig,
        audio_left  => left_dsp_to_tx,
        audio_right => right_dsp_to_tx
    );

end Structural;