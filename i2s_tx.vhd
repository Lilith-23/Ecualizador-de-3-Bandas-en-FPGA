library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2s_tx is
    Port (
        clk_50mhz   : in  STD_LOGIC;  -- Reloj maestro de la FPGA (50 MHz)
        reset       : in  STD_LOGIC;  -- Botón de reinicio (activo en bajo)
        
        -- Señales del Bus I2S (Vienen de tu Master Clock)
        BCLK        : in  STD_LOGIC;
        LRCK        : in  STD_LOGIC;
        
        -- Salida de datos hacia el DAC PCM5102A
        DOUT        : out STD_LOGIC;  -- Conectar al pin DIN del DAC
        
        -- Interfaz de entrada (Viene de tu Módulo DSP)
        data_valid  : in  STD_LOGIC;  -- Pulso que indica que hay nuevos datos listos
        audio_left  : in  STD_LOGIC_VECTOR(23 downto 0);
        audio_right : in  STD_LOGIC_VECTOR(23 downto 0)
    );
end i2s_tx;

architecture Behavioral of i2s_tx is

    -- Registros para el detector de flancos
    signal bclk_prev : std_logic := '0';
    signal lrck_prev : std_logic := '0';
    
    -- Buffers para guardar los datos que manda el DSP
    signal left_buf  : std_logic_vector(23 downto 0) := (others => '0');
    signal right_buf : std_logic_vector(23 downto 0) := (others => '0');
    
    -- Registro de desplazamiento y contador
    signal shift_reg : std_logic_vector(23 downto 0) := (others => '0');
    signal bit_cnt   : integer range 0 to 31 := 0;

begin

    process(clk_50mhz, reset)
    begin
        if reset = '0' then
            DOUT      <= '0';
            bclk_prev <= '0';
            lrck_prev <= '0';
            left_buf  <= (others => '0');
            right_buf <= (others => '0');
            shift_reg <= (others => '0');
            bit_cnt   <= 0;
            
        elsif rising_edge(clk_50mhz) then
            
            -- Guardamos en los buffers la información del DSP en cuanto nos avisa que está lista
            if data_valid = '1' then
                left_buf  <= audio_left;
                right_buf <= audio_right;
            end if;

            -- Guardamos el estado actual de BCLK para el detector de flancos
            bclk_prev <= BCLK;
            
            -- ¡Detector de flanco de bajada en BCLK! (Momento de cambiar el dato en la salida)
            if bclk_prev = '1' and BCLK = '0' then
                
                -- Verificamos si hubo un cambio de canal
                if lrck_prev /= LRCK then
                    bit_cnt <= 0; -- Reiniciamos la cuenta
                    
                    -- Cargamos el registro de desplazamiento con el canal correspondiente
                    -- Nota: Aún no sacamos el dato, esto crea el "retraso de 1 bit" del I2S
                    if LRCK = '0' then
                        shift_reg <= left_buf;
                    else
                        shift_reg <= right_buf;
                    end if;
                    
                else
                    -- Incrementamos el contador de bits
                    if bit_cnt < 31 then
                        bit_cnt <= bit_cnt + 1;
                    end if;
                    
                    -- Transmitimos los 24 bits
                    if bit_cnt >= 0 and bit_cnt < 24 then
                        DOUT <= shift_reg(23); -- Sacamos el bit más significativo (MSB)
                        -- Recorremos el registro a la izquierda rellenando con ceros
                        shift_reg <= shift_reg(22 downto 0) & '0'; 
                    else
                        -- Rellenamos con ceros los últimos 8 bits del frame de 32
                        DOUT <= '0'; 
                    end if;
                end if;
                
                -- Actualizamos el estado de LRCK
                lrck_prev <= LRCK;
                
            end if;
        end if;
    end process;

end Behavioral;