library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tone_sequencer is
    Port (
        clk          : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        data_valid   : in  STD_LOGIC; -- Pulso de sincronización LRCK (48.8 kHz)
        audio_out    : out STD_LOGIC_VECTOR(23 downto 0);
        current_band : out STD_LOGIC_VECTOR(1 downto 0) -- 00: Grave, 01: Medio, 10: Agudo
    );
end tone_sequencer;

architecture rtl of tone_sequencer is
    -- Contadores
    signal sample_cnt : integer range 0 to 50000 := 0;
    signal note_state : integer range 0 to 2 := 0;
    signal toggle_cnt : integer range 0 to 200 := 0;

    -- Amplitud de la onda cuadrada (Escalada al 25% por seguridad del TPA3110)
    constant AMP_POS : signed(23 downto 0) := x"03FFFF";
    constant AMP_NEG : signed(23 downto 0) := x"FC0000";
    signal current_val : signed(23 downto 0) := AMP_POS;

    -- Límites calculados matemáticamente para las frecuencias
    constant BASS_LIMIT : integer := 163; -- ~150 Hz
    constant MID_LIMIT  : integer := 24;  -- ~1000 Hz
    constant TREB_LIMIT : integer := 4;   -- ~6103 Hz

    signal active_limit : integer range 0 to 200 := BASS_LIMIT;

begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                sample_cnt  <= 0;
                note_state  <= 0;
                toggle_cnt  <= 0;
                current_val <= AMP_POS;
            elsif data_valid = '1' then
                -- 1. Control de Tiempo: 1 Segundo por nota (48828 muestras)
                if sample_cnt >= 48827 then
                    sample_cnt <= 0;
                    if note_state = 2 then
                        note_state <= 0;
                    else
                        note_state <= note_state + 1;
                    end if;
                else
                    sample_cnt <= sample_cnt + 1;
                end if;

                -- 2. Selector de frecuencia según la nota actual
                case note_state is
                    when 0 => active_limit <= BASS_LIMIT;
                    when 1 => active_limit <= MID_LIMIT;
                    when 2 => active_limit <= TREB_LIMIT;
                    when others => active_limit <= BASS_LIMIT;
                end case;

                -- 3. Oscilador Digital (Generador de Onda Cuadrada)
                if toggle_cnt >= active_limit then
                    toggle_cnt <= 0;
                    if current_val = AMP_POS then
                        current_val <= AMP_NEG;
                    else
                        current_val <= AMP_POS;
                    end if;
                else
                    toggle_cnt <= toggle_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Salidas
    audio_out <= std_logic_vector(current_val);
    
    -- Avisar al exterior qué banda se está reproduciendo
    current_band <= "00" when note_state = 0 else
                    "01" when note_state = 1 else
                    "10";
end rtl;