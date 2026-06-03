library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dac_test_top is
    port (
        MAX10_CLK1_50 : in  std_logic;
        SW            : in  std_logic_vector(2 downto 0); -- SW(2): Agudos, SW(1): Medios, SW(0): Graves
        KEY           : in  std_logic_vector(1 downto 0); -- KEY(0): Subir volumen, KEY(1): Bajar volumen
        I2S_MCLK      : out std_logic;
        I2S_BCLK      : out std_logic;
        I2S_LRCK      : out std_logic;
        I2S_DAC_DIN   : out std_logic;
        LEDR          : out std_logic_vector(9 downto 0)  -- Monitoreo visual completo
    );
end entity dac_test_top;

architecture rtl of dac_test_top is
    -- Relojes internos
    signal clk_mclk   : std_logic;
    signal clk_bclk   : std_logic;
    signal clk_lrck   : std_logic;
    signal lrck_prev  : std_logic := '0';
    signal audio_sync : std_logic := '0';
    
    -- Señales de Audio y Datos
    signal noise_raw   : std_logic_vector(23 downto 0);
    signal audio_out   : std_logic_vector(23 downto 0) := (others => '0');
    signal sig_dac_din : std_logic;

    -- Registros de Ganancia provenientes del controlador (0 a 15)
    signal g_bass : unsigned(3 downto 0);
    signal g_mid  : unsigned(3 downto 0);
    signal g_treb : unsigned(3 downto 0);
    
    -- Lógica de prueba para volumen directo
    signal active_gain : unsigned(3 downto 0);
    signal gain_int    : integer range 0 to 15;

    -- Señal para el latido del sistema
    signal blink_counter : integer range 0 to 50000000 := 0;
    signal blink_state   : std_logic := '0';

    -- Componentes externos
    component i2s_master_clocks is
        port(
            clk_50mhz : in  std_logic;
            reset     : in  std_logic; -- Tareas internas
            mclk      : out std_logic;
            bclk      : out std_logic;
            lrck      : out std_logic
        );
    end component;

    component lfsr_noise is
        Port (
            clk        : in  STD_LOGIC;
            reset      : in  STD_LOGIC;
            data_valid : in  STD_LOGIC;
            noise_out  : out STD_LOGIC_VECTOR(23 downto 0)
        );
    end component;

    component control_eq is
        Port (
            clk        : in  STD_LOGIC;
            reset      : in  STD_LOGIC;
            SW         : in  STD_LOGIC_VECTOR(2 downto 0);
            KEY        : in  STD_LOGIC_VECTOR(1 downto 0);
            gain_bass  : out UNSIGNED(3 downto 0);
            gain_mid   : out UNSIGNED(3 downto 0);
            gain_treb  : out UNSIGNED(3 downto 0)
        );
    end component;

    component i2s_tx is
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
    end component;

begin
    -- 1. Instanciación del Generador de Relojes (Forzamos reset alto interno)
    u_clocks: i2s_master_clocks
        port map (
            clk_50mhz => MAX10_CLK1_50,
            reset     => '1', 
            mclk      => clk_mclk,
            bclk      => clk_bclk,
            lrck      => clk_lrck
        );

    -- 2. Instanciación del Generador de Ruido Blanco
    u_noise: lfsr_noise
        port map (
            clk        => MAX10_CLK1_50,
            reset      => '1',
            data_valid => audio_sync,
            noise_out  => noise_raw
        );

    -- 3. Instanciación del Controlador de Ecualización (Botones y Switches)
    u_control: control_eq
        port map (
            clk        => MAX10_CLK1_50,
            reset      => '1',
            SW         => SW,
            KEY        => KEY,
            gain_bass  => g_bass,
            gain_mid   => g_mid,
            gain_treb  => g_treb
        );

    -- 4. Instanciación del Transmisor I2S (Mapeo elegante con señal interna)
    u_tx: i2s_tx
        port map (
            clk_50mhz   => MAX10_CLK1_50,
            reset       => '1',
            BCLK        => clk_bclk,
            LRCK        => clk_lrck,
            DOUT        => sig_dac_din,
            data_valid  => audio_sync,
            audio_left  => audio_out,
            audio_right => audio_out
        );

    -- Conexiones a Pines Físicos de Salida Audio
    I2S_MCLK    <= clk_mclk;
    I2S_BCLK    <= clk_bclk;
    I2S_LRCK    <= clk_lrck;
    I2S_DAC_DIN <= sig_dac_din;

    -- Generador de pulso de sincronización basado en LRCK
    process(MAX10_CLK1_50)
    begin
        if rising_edge(MAX10_CLK1_50) then
            lrck_prev <= clk_lrck;
            audio_sync <= '0';
            if lrck_prev = '1' and clk_lrck = '0' then
                audio_sync <= '1';
            end if;
        end if;
    end process;

    -- Selección de ganancia activa según el switch para la prueba acústica
    with SW select
        active_gain <= g_treb when "100",  -- Muestra volumen de agudos
                       g_mid  when "010",  -- Muestra volumen de medios
                       g_bass when "001",  -- Muestra volumen de graves
                       to_unsigned(8, 4) when others;

    gain_int <= to_integer(active_gain);

    -- Procesamiento matemático de ganancia temporal (Multiplicación de volumen)
    process(MAX10_CLK1_50)
        variable val_audio : signed(23 downto 0);
        variable val_gain  : signed(4 downto 0);
        variable mult_res  : signed(28 downto 0); -- 24 bits + 5 bits = 29 bits exactos
    begin
        if rising_edge(MAX10_CLK1_50) then
            if audio_sync = '1' then
                -- 1. Preparamos el audio (24 bits con signo)
                val_audio := signed(noise_raw);
                
                -- 2. Convertimos la ganancia a 5 bits con signo positivo para empatar tipos
                val_gain := signed("0" & std_logic_vector(active_gain));
                
                -- 3. Multiplicación controlada y exacta
                mult_res := val_audio * val_gain;
                
                -- 4. Extracción de 24 bits para el DAC. 
                -- Tomar desde el bit 27 hasta el 4 divide el resultado entre 16,
                -- asegurando que el volumen máximo (15) nunca sature tu amplificador.
                audio_out <= std_logic_vector(mult_res(27 downto 4));
            end if;
        end if;
    end process;

    -- Contador para el LED de latido (Heartbeat) a 1Hz
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

    -- =================================================================
    -- MAPEO DE LEDS SOLICITADO (Visualización Completa de Estados)
    -- =================================================================
    -- Los 3 bits más significativos de cada registro se muestran en los LEDs
    LEDR(9 downto 7) <= std_logic_vector(g_treb(3 downto 1)); -- Barra de Agudos
    LEDR(6 downto 4) <= std_logic_vector(g_mid(3 downto 1));  -- Barra de Medios
    LEDR(3 downto 1) <= std_logic_vector(g_bass(3 downto 1)); -- Barra de Graves
    LEDR(0)          <= blink_state;                          -- FPGA Viva (Heartbeat)

end architecture rtl;