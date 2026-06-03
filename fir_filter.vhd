library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fir_filter is
    generic (
        -- Coeficientes del filtro en formato entero (Q15: 32768 = 1.0)
        C0 : integer := 0;
        C1 : integer := 0;
        C2 : integer := 0;
        C3 : integer := 0;
        C4 : integer := 0
    );
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        data_valid : in  STD_LOGIC;  -- Pulso que indica que llegó una nueva muestra
        data_in    : in  STD_LOGIC_VECTOR(23 downto 0);
        data_out   : out STD_LOGIC_VECTOR(23 downto 0)
    );
end fir_filter;

architecture Behavioral of fir_filter is

    -- Línea de retraso (Shift Register) para guardar las muestras pasadas
    type delay_line_type is array (0 to 4) of signed(23 downto 0);
    signal delay_line : delay_line_type := (others => (others => '0'));

    -- Señal para el acumulador final (40 bits para evitar desbordamientos en la suma)
    signal accumulator : signed(39 downto 0) := (others => '0');

begin

    process(clk, reset)
        -- Variables temporales para las multiplicaciones (24 bits * 16 bits = 40 bits)
        variable mult0, mult1, mult2, mult3, mult4 : signed(39 downto 0);
        variable sum : signed(39 downto 0);
    begin
        if reset = '0' then
            delay_line <= (others => (others => '0'));
            accumulator <= (others => '0');
            data_out <= (others => '0');
            
        elsif rising_edge(clk) then
            if data_valid = '1' then
                
                -- 1. Actualizar la línea de retraso (Mover todo una posición)
                delay_line(4) <= delay_line(3);
                delay_line(3) <= delay_line(2);
                delay_line(2) <= delay_line(1);
                delay_line(1) <= delay_line(0);
                delay_line(0) <= signed(data_in); -- Entra la muestra más nueva
                
                -- 2. Multiplicación por los coeficientes genéricos
                mult0 := delay_line(0) * to_signed(C0, 16);
                mult1 := delay_line(1) * to_signed(C1, 16);
                mult2 := delay_line(2) * to_signed(C2, 16);
                mult3 := delay_line(3) * to_signed(C3, 16);
                mult4 := delay_line(4) * to_signed(C4, 16);
                
                -- 3. Sumar todo (Acumulador)
                sum := mult0 + mult1 + mult2 + mult3 + mult4;
                
                -- 4. Escalar de vuelta a 24 bits
                -- Hacemos un corrimiento (shift) de 15 bits a la derecha por el formato Q15
                -- y extraemos los 24 bits correspondientes.
                accumulator <= sum;
                data_out <= std_logic_vector(sum(38 downto 15));
                
            end if;
        end if;
    end process;

end Behavioral;