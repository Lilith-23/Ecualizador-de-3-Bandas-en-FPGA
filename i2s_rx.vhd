library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2s_rx is
    Port (
        clk_50mhz   : in  STD_LOGIC;  -- Reloj maestro de la FPGA (50 MHz)
        reset       : in  STD_LOGIC;  -- Botón de reinicio (activo en bajo)
        
        -- Señales del Bus I2S (Entradas desde el ADC y tu Master Clock)
        BCLK        : in  STD_LOGIC;  -- Bit Clock
        LRCK        : in  STD_LOGIC;  -- Señal Left/Right (48.8 kHz)
        DIN         : in  STD_LOGIC;  -- Datos en serie provenientes del pin OUT del PCM1808
        
        -- Salidas en paralelo hacia tu futuro bloque DSP
        audio_left  : out STD_LOGIC_VECTOR(23 downto 0);
        audio_right : out STD_LOGIC_VECTOR(23 downto 0);
        data_ready  : out STD_LOGIC   -- Pulso de 1 ciclo que indica que hay nuevos datos listos
    );
end i2s_rx;

architecture Behavioral of i2s_rx is

    -- Registros para el detector de flancos
    signal bclk_prev : std_logic := '0';
    signal lrck_prev : std_logic := '0';
    
    -- Registro de desplazamiento y contador
    signal shift_reg : std_logic_vector(23 downto 0) := (others => '0');
    signal bit_cnt   : integer range 0 to 31 := 0;

begin

    process(clk_50mhz, reset)
    begin
        if reset = '0' then
            audio_left  <= (others => '0');
            audio_right <= (others => '0');
            data_ready  <= '0';
            bclk_prev   <= '0';
            lrck_prev   <= '0';
            shift_reg   <= (others => '0');
            bit_cnt     <= 0;
            
        elsif rising_edge(clk_50mhz) then
            -- Por defecto, el pulso de listo se mantiene apagado
            data_ready <= '0';
            
            -- Guardamos el estado actual de BCLK para compararlo en el siguiente ciclo
            bclk_prev <= BCLK;
            
            -- ¡Detector de flanco de subida en BCLK! (El momento exacto para capturar el dato)
            if bclk_prev = '0' and BCLK = '1' then
                
                -- Verificamos si hubo un cambio de canal (transición en LRCK)
                if lrck_prev /= LRCK then
                    bit_cnt <= 0; -- Reiniciamos la cuenta de bits por el nuevo canal
                    
                    -- Si LRCK acaba de pasar a '0' (Left), significa que el canal derecho (Right) 
                    -- anterior acaba de terminar. ¡Tenemos un frame estéreo completo!
                    if LRCK = '0' then
                        data_ready <= '1'; -- Disparamos la señal para despertar al Ecualizador (DSP)
                    end if;
                else
                    -- Si no hay cambio de canal, seguimos contando los bits de datos
                    if bit_cnt < 31 then
                        bit_cnt <= bit_cnt + 1;
                    end if;
                    
                    -- El protocolo I2S tiene 1 bit de retraso. 
                    -- Por lo tanto, capturamos los 24 bits desde el bit_cnt = 0 hasta el 23.
                    if bit_cnt >= 0 and bit_cnt < 24 then
                        -- Desplazamos el registro a la izquierda e insertamos el nuevo bit que llegó
                        shift_reg <= shift_reg(22 downto 0) & DIN;
                    end if;
                    
                    -- Cuando llegamos al bit 23, el registro ya armó la palabra completa de 24 bits
                    if bit_cnt = 23 then
                        if LRCK = '0' then
                            -- LRCK en '0' significa Canal Izquierdo
                            audio_left <= shift_reg(22 downto 0) & DIN; 
                        else
                            -- LRCK en '1' significa Canal Derecho
                            audio_right <= shift_reg(22 downto 0) & DIN;
                        end if;
                    end if;
                end if;
                
                -- Actualizamos el estado de LRCK para la comparación del próximo ciclo
                lrck_prev <= LRCK;
                
            end if;
            
        end if;
    end process;

end Behavioral;