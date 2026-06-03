library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2s_dsp is
    Port (
        clk_50mhz       : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        
        data_ready      : in  STD_LOGIC;
        audio_left_in   : in  STD_LOGIC_VECTOR(23 downto 0);
        audio_right_in  : in  STD_LOGIC_VECTOR(23 downto 0);
        
        -- ¡NUEVO! Vector de 3 switches para el control del Booster (Agudos-Medios-Graves)
        sw_band_ctrl    : in  STD_LOGIC_VECTOR(2 downto 0); 
        
        audio_left_out  : out STD_LOGIC_VECTOR(23 downto 0);
        audio_right_out : out STD_LOGIC_VECTOR(23 downto 0);
        data_valid      : out STD_LOGIC
    );
end i2s_dsp;

architecture Behavioral of i2s_dsp is

    -- Señales para convertir a matemáticas
    signal left_signed  : signed(23 downto 0) := (others => '0');
    signal right_signed : signed(23 downto 0) := (others => '0');

    -- Señales reales que saldrán de los filtros
    signal bass_out    : std_logic_vector(23 downto 0);
    signal mid_out     : std_logic_vector(23 downto 0);
    signal treble_out  : std_logic_vector(23 downto 0);

    -- DECLARAMOS EL COMPONENTE FIR
    component fir_filter is
        generic ( C0, C1, C2, C3, C4 : integer );
        Port ( clk : in STD_LOGIC; reset : in STD_LOGIC; data_valid : in STD_LOGIC;
               data_in : in STD_LOGIC_VECTOR(23 downto 0); data_out : out STD_LOGIC_VECTOR(23 downto 0) );
    end component;

begin
	 -- =========================================================
    -- INSTANCIAMOS LOS 3 FILTROS (Aquí metemos la matemáticas)
    -- =========================================================
    
    -- Filtro Pasa Bajas (Graves) - Coeficientes de ejemplo (Filtro promediador suave)
    Filtro_Graves: fir_filter 
        generic map ( C0 => 6553, C1 => 6553, C2 => 6553, C3 => 6553, C4 => 6553 )
        port map ( clk => clk_50mhz, reset => reset, data_valid => data_ready,
                   data_in => audio_left_in, data_out => bass_out );

    -- Filtro Pasa Banda (Medios) - Coeficientes de ejemplo
    Filtro_Medios: fir_filter 
        generic map ( C0 => -4096, C1 => 8192, C2 => 16384, C3 => 8192, C4 => -4096 )
        port map ( clk => clk_50mhz, reset => reset, data_valid => data_ready,
                   data_in => audio_left_in, data_out => mid_out );

    -- Filtro Pasa Altas (Agudos) - Coeficientes de ejemplo (Diferenciador)
    Filtro_Agudos: fir_filter 
        generic map ( C0 => -8192, C1 => -8192, C2 => 32768, C3 => -8192, C4 => -8192 )
        port map ( clk => clk_50mhz, reset => reset, data_valid => data_ready,
                   data_in => audio_left_in, data_out => treble_out );

    process(clk_50mhz, reset)
        variable temp_left  : signed(23 downto 0);
        variable temp_right : signed(23 downto 0);
        
        -- Variables para aplicar la ganancia de forma independiente
        variable bass_boost   : signed(23 downto 0);
        variable mid_boost    : signed(23 downto 0);
        variable treble_boost : signed(23 downto 0);
    begin
        if reset = '0' then
            audio_left_out  <= (others => '0');
            audio_right_out <= (others => '0');
            data_valid      <= '0';
            
        elsif rising_edge(clk_50mhz) then
            data_valid <= '0';
            
            if data_ready = '1' then
                left_signed <= signed(audio_left_in);
                
                -- En lugar de usar las "bandas" dummy, leemos las salidas de las instancias:
                if sw_band_ctrl = "100" then
                    treble_boost := shift_left(signed(treble_out), 1); 
                else
                    treble_boost := signed(treble_out); 
                end if;
                
                if sw_band_ctrl = "010" then
                    mid_boost := shift_left(signed(mid_out), 1); 
                else
                    mid_boost := signed(mid_out); 
                end if;
                
                if sw_band_ctrl = "001" then
                    bass_boost := shift_left(signed(bass_out), 1); 
                else
                    bass_boost := signed(bass_out); 
                end if;

                -- SUMA FINAL DE LAS BANDAS ECUALIZADAS
                -- Ojo: Al sumar 3 señales, la amplitud crece, el limitador abajo nos salvará.
                temp_left := bass_boost + mid_boost + treble_boost;
                
                -- (Aquí replicarías la misma lógica exacta para el canal RIGHT)
                temp_right := signed(audio_right_in); -- Placeholder directo para ahorrar espacio
                
                -- LIMITADOR DIGITAL (Protección de bocina que ya teníamos)
                temp_left  := shift_right(temp_left, 2);
                temp_right := shift_right(temp_right, 2);
                
                audio_left_out  <= std_logic_vector(temp_left);
                audio_right_out <= std_logic_vector(temp_right);
                data_valid <= '1';
                
            end if;
        end if;
    end process;

end Behavioral;