library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity modulo_procesamiento is
    port(
        clk          : in  STD_LOGIC;
        sample_valid : in  STD_LOGIC;
        data_in      : in  STD_LOGIC_VECTOR(23 downto 0);
        g_graves     : in  unsigned(7 downto 0);
        g_medios     : in  unsigned(7 downto 0);
        g_agudos     : in  unsigned(7 downto 0);
        data_out     : out STD_LOGIC_VECTOR(23 downto 0)
    );
end entity;

architecture rtl of modulo_procesamiento is
    -- Línea de retardo de muestras común para los filtros
    type delay_line is array (0 to 2) of signed(23 downto 0);
    signal x : delay_line := (others => (others => '0'));
    
    -- Coeficientes del filtro FIR
    constant C_GRAVES : signed(15 downto 0) := x"2000"; 
    constant C_MEDIOS : signed(15 downto 0) := x"4000"; 
    constant C_AGUDOS : signed(15 downto 0) := x"1500"; 

    signal y_graves, y_medios, y_agudos : signed(39 downto 0);
    signal mezcla : signed(47 downto 0);
begin
    process(clk)
        variable mult_graves : signed(47 downto 0);
        variable mult_medios : signed(47 downto 0);
        variable mult_agudos : signed(47 downto 0);
    begin
        if rising_edge(clk) then
            if sample_valid = '1' then
                -- Desplazamiento de muestras de entrada
                x(2) <= x(1);
                x(1) <= x(0);
                x(0) <= signed(data_in);
                
                -- Operación de Filtrado (Da 40 bits de salida)
                y_graves <= (x(0) * C_GRAVES) + (x(1) * C_GRAVES);
                y_medios <= (x(0) * C_MEDIOS) - (x(2) * C_MEDIOS);
                y_agudos <= (x(0) * C_AGUDOS) + (x(1) * C_AGUDOS);
                
					 
                mult_graves := y_graves(39 downto 0) * signed('0' & g_graves(7 downto 1));
                mult_medios := y_medios(39 downto 0) * signed('0' & g_medios(7 downto 1));
                mult_agudos := y_agudos(39 downto 0) * signed('0' & g_agudos(7 downto 1));
                          
								  
                mezcla <= mult_graves + mult_medios + mult_agudos;
                          
								  
                data_out <= std_logic_vector(mezcla(47 downto 24));
            end if;
        end if;
    end process;
end architecture;