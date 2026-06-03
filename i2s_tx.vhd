library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2s_tx is
    Port (
        clk_50mhz   : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        BCLK        : in  STD_LOGIC;
        LRCK        : in  STD_LOGIC;
        DOUT        : out STD_LOGIC;
        data_valid  : in  STD_LOGIC;
        audio_left  : in  STD_LOGIC_VECTOR(23 downto 0);
        audio_right : in  STD_LOGIC_VECTOR(23 downto 0)
    );
end i2s_tx;

architecture Behavioral of i2s_tx is
    signal bclk_prev : std_logic := '0';
    signal lrck_prev : std_logic := '0';
    signal left_buf  : std_logic_vector(23 downto 0) := (others => '0');
    signal right_buf : std_logic_vector(23 downto 0) := (others => '0');
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
            if data_valid = '1' then
                left_buf  <= audio_left;
                right_buf <= audio_right;
            end if;

            bclk_prev <= BCLK;
            if bclk_prev = '1' and BCLK = '0' then -- Flanco de bajada
                if lrck_prev /= LRCK then
                    bit_cnt <= 0;
                    if LRCK = '0' then
                        shift_reg <= left_buf;
                    else
                        shift_reg <= right_buf;
                    end if;
                else
                    if bit_cnt < 31 then
                        bit_cnt <= bit_cnt + 1;
                    end if;
                    if bit_cnt >= 0 and bit_cnt < 24 then
                        DOUT <= shift_reg(23);
                        shift_reg <= shift_reg(22 downto 0) & '0';
                    else
                        DOUT <= '0';
                    end if;
                end if;
                lrck_prev <= LRCK;
            end if;
        end if;
    end process;
end Behavioral;