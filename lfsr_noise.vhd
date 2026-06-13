library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity lfsr_noise is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        data_valid : in  STD_LOGIC; -- Viene del reloj LRCK (audio_sync)
        noise_out  : out STD_LOGIC_VECTOR(23 downto 0)
    );
end lfsr_noise;

architecture rtl of lfsr_noise is
    -- Semilla inicial (nunca debe ser cero)
    signal lfsr : std_logic_vector(23 downto 0) := x"AB1234"; 
    signal feedback : std_logic;
begin
    -- Polinomio para 24 bits: x^24 + x^23 + x^22 + x^17 + 1
    feedback <= lfsr(23) xor lfsr(22) xor lfsr(21) xor lfsr(16);

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                lfsr <= x"AB1234";
            elsif data_valid = '1' then
                -- Desplazar y aplicar feedback cada nueva muestra de audio
                lfsr <= lfsr(22 downto 0) & feedback;
            end if;
        end if;
    end process;

    -- Escalar el ruido para que no sea ensordecedor (reducimos amplitud)
    noise_out <= lfsr(23) & lfsr(23) & lfsr(23) & lfsr(23 downto 3);
end rtl;