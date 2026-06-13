library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_eq is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        SW         : in  STD_LOGIC_VECTOR(2 downto 0); -- Selección de banda
        KEY        : in  STD_LOGIC_VECTOR(1 downto 0); -- 0: Subir, 1: Bajar
        gain_bass  : out UNSIGNED(3 downto 0); -- Multiplicador Graves (0 a 15)
        gain_mid   : out UNSIGNED(3 downto 0); -- Multiplicador Medios
        gain_treb  : out UNSIGNED(3 downto 0)  -- Multiplicador Agudos
    );
end control_eq;

architecture rtl of control_eq is
    -- Registros internos de ganancia (inician a la mitad: 8)
    signal r_bass : unsigned(3 downto 0) := to_unsigned(8, 4);
    signal r_mid  : unsigned(3 downto 0) := to_unsigned(8, 4);
    signal r_treb : unsigned(3 downto 0) := to_unsigned(8, 4);

    -- Variables para detectar cuándo se presiona el botón (flanco)
    signal key0_prev, key1_prev : std_logic := '1';
    signal debounce_cnt : integer range 0 to 500000 := 0;
    signal keys_ready : std_logic := '1';

begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                r_bass <= to_unsigned(8, 4);
                r_mid  <= to_unsigned(8, 4);
                r_treb <= to_unsigned(8, 4);
                keys_ready <= '1';
            else
                -- Lógica Anti-rebote sencilla (espera ~10ms tras cada pulsación)
                if keys_ready = '0' then
                    if debounce_cnt = 500000 then
                        keys_ready <= '1';
                        debounce_cnt <= 0;
                    else
                        debounce_cnt <= debounce_cnt + 1;
                    end if;
                else
                    -- Detectar flanco de bajada (botón presionado)
                    if key0_prev = '1' and KEY(0) = '0' then
                        keys_ready <= '0'; -- Bloquear hasta que pase el rebote
                        
                        -- Lógica de SUBIR VOLUMEN según el Switch
                        if SW = "100" and r_treb < 15 then r_treb <= r_treb + 1; end if; -- Agudos
                        if SW = "010" and r_mid  < 15 then r_mid  <= r_mid  + 1; end if; -- Medios
                        if SW = "001" and r_bass < 15 then r_bass <= r_bass + 1; end if; -- Graves
                    end if;

                    if key1_prev = '1' and KEY(1) = '0' then
                        keys_ready <= '0';
                        
                        -- Lógica de BAJAR VOLUMEN según el Switch
                        if SW = "100" and r_treb > 0 then r_treb <= r_treb - 1; end if;
                        if SW = "010" and r_mid  > 0 then r_mid  <= r_mid  - 1; end if;
                        if SW = "001" and r_bass > 0 then r_bass <= r_bass - 1; end if;
                    end if;
                end if;
                
                key0_prev <= KEY(0);
                key1_prev <= KEY(1);
            end if;
        end if;
    end process;

    gain_bass <= r_bass;
    gain_mid  <= r_mid;
    gain_treb <= r_treb;
end rtl;