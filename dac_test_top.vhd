library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dac_test_top is
    port (
        MAX10_CLK1_50 : in  std_logic;
        SW            : in  std_logic_vector(2 downto 0); -- Selección de banda a configurar
        KEY           : in  std_logic_vector(1 downto 0); -- KEY0: Subir, KEY1: Bajar
        I2S_MCLK      : out std_logic;
        I2S_BCLK      : out std_logic;
        I2S_LRCK      : out std_logic;
        I2S_DAC_DIN   : out std_logic;
        LEDR          : out std_logic_vector(9 downto 0)
    );
end entity dac_test_top;

architecture rtl of dac_test_top is
    signal clk_mclk   : std_logic;
    signal clk_bclk   : std_logic;
    signal clk_lrck   : std_logic;
    signal lrck_prev  : std_logic := '0';
    signal audio_sync : std_logic := '0';
    
    -- Señales del secuenciador
    signal seq_audio   : std_logic_vector(23 downto 0);
    signal active_band : std_logic_vector(1 downto 0);
    signal audio_out   : std_logic_vector(23 downto 0) := (others => '0');
    signal sig_dac_din : std_logic;

    -- Registros de Ganancia provenientes del controlador
    signal g_bass : unsigned(3 downto 0);
    signal g_mid  : unsigned(3 downto 0);
    signal g_treb : unsigned(3 downto 0);
    signal active_gain : unsigned(3 downto 0);

    signal blink_counter : integer range 0 to 50000000 := 0;
    signal blink_state   : std_logic := '0';

    -- === COMPONENTES ===
    component i2s_master_clocks is
        port(clk_50mhz: in std_logic; reset: in std_logic; mclk, bclk, lrck: out std_logic);
    end component;

    component tone_sequencer is
        port(clk, reset, data_valid: in std_logic; audio_out: out std_logic_vector(23 downto 0); current_band: out std_logic_vector(1 downto 0));
    end component;

    component control_eq is
        port(clk, reset: in std_logic; SW: in std_logic_vector(2 downto 0); KEY: in std_logic_vector(1 downto 0); gain_bass, gain_mid, gain_treb: out unsigned(3 downto 0));
    end component;

    component i2s_tx is
        port(clk_50mhz, reset, BCLK, LRCK: in std_logic; DOUT: out std_logic; data_valid: in std_logic; audio_left, audio_right: in std_logic_vector(23 downto 0));
    end component;

begin
    u_clocks: i2s_master_clocks port map (MAX10_CLK1_50, '1', clk_mclk, clk_bclk, clk_lrck);

    u_seq: tone_sequencer port map (MAX10_CLK1_50, '1', audio_sync, seq_audio, active_band);

    u_control: control_eq port map (MAX10_CLK1_50, '1', SW, KEY, g_bass, g_mid, g_treb);

    u_tx: i2s_tx port map (MAX10_CLK1_50, '1', clk_bclk, clk_lrck, sig_dac_din, audio_sync, audio_out, audio_out);

    I2S_MCLK    <= clk_mclk;
    I2S_BCLK    <= clk_bclk;
    I2S_LRCK    <= clk_lrck;
    I2S_DAC_DIN <= sig_dac_din;

    -- Generador de pulso LRCK
    process(MAX10_CLK1_50)
    begin
        if rising_edge(MAX10_CLK1_50) then
            lrck_prev <= clk_lrck;
            audio_sync <= '0';
            if lrck_prev = '1' and clk_lrck = '0' then audio_sync <= '1'; end if;
        end if;
    end process;

    -- ===============================================================
    -- MULTIPLEXOR DE GANANCIA (Simulador de Filtro EQ Perfecto)
    -- Asigna la ganancia de tu interfaz a la nota que está sonando
    -- ===============================================================
    with active_band select
        active_gain <= g_bass when "00",
                       g_mid  when "01",
                       g_treb when "10",
                       to_unsigned(8, 4) when others;

    -- Multiplicador Matemático a 29 bits
    process(MAX10_CLK1_50)
        variable val_audio : signed(23 downto 0);
        variable val_gain  : signed(4 downto 0);
        variable mult_res  : signed(28 downto 0);
    begin
        if rising_edge(MAX10_CLK1_50) then
            if audio_sync = '1' then
                val_audio := signed(seq_audio);
                val_gain  := signed("0" & std_logic_vector(active_gain));
                mult_res  := val_audio * val_gain;
                
                audio_out <= std_logic_vector(mult_res(27 downto 4));
            end if;
        end if;
    end process;

    process(MAX10_CLK1_50)
    begin
        if rising_edge(MAX10_CLK1_50) then
            if blink_counter = 25000000 then blink_state <= not blink_state; blink_counter <= 0;
            else blink_counter <= blink_counter + 1; end if;
        end if;
    end process;

    LEDR(9 downto 7) <= std_logic_vector(g_treb(3 downto 1)); 
    LEDR(6 downto 4) <= std_logic_vector(g_mid(3 downto 1));  
    LEDR(3 downto 1) <= std_logic_vector(g_bass(3 downto 1)); 
    LEDR(0)          <= blink_state;
end architecture rtl;