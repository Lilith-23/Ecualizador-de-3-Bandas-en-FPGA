library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity modulo_salida is
    port(
        bck        : in  STD_LOGIC;
        lrck       : in  STD_LOGIC;
        data_in    : in  STD_LOGIC_VECTOR(23 downto 0);
        dout_serie : out STD_LOGIC
    );
end entity;

architecture rtl of modulo_salida is
    signal shift_out : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal bit_cnt   : integer range 0 to 31 := 0;
begin
    process(bck)
    begin
        if falling_edge(bck) then -- El DAC lee datos estables en los flancos de subida de bck
            if lrck = '0' then 
                if bit_cnt = 0 then
                    shift_out <= data_in; -- Carga la muestra ecualizada
                else
                    shift_out(23 downto 1) <= shift_out(22 downto 0);
                end if;
                dout_serie <= shift_out(23);
                bit_cnt <= bit_cnt + 1;
            else
                dout_serie <= '0'; -- Canal derecho a cero para mantener el formato mono
                bit_cnt <= 0;
            end if;
        end if;
    end process;
end architecture;