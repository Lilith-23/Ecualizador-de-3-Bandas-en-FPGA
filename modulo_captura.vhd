library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity modulo_captura is
    port(
        bck       : in  STD_LOGIC;
        lrck      : in  STD_LOGIC;
        din_serie : in  STD_LOGIC;
        data_out  : out STD_LOGIC_VECTOR(23 downto 0);
        strobe    : out STD_LOGIC
    );
end entity;

architecture rtl of modulo_captura is
    signal shift_reg : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal bit_cnt   : integer range 0 to 31 := 0;
begin
    process(bck)
    begin
        if rising_edge(bck) then
            if lrck = '0' then -- Canal Izquierdo (Selección Mono)
                if bit_cnt < 24 then
                    shift_reg(23 downto 1) <= shift_reg(22 downto 0);
                    shift_reg(0) <= din_serie;
                    bit_cnt <= bit_cnt + 1;
                end if;
                strobe <= '0';
            else -- Canal Derecho (Ignorado para mantener procesamiento mono)
                bit_cnt <= 0;
                data_out <= shift_reg;
                strobe <= '1'; -- Avisa al procesador que la muestra está lista
            end if;
        end if;
    end process;
end architecture;