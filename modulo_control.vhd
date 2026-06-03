library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity modulo_control is
    port(
        clk          : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        sel_banda    : in  STD_LOGIC_VECTOR(2 downto 0); 
        btn_up       : in  STD_LOGIC;
        btn_down     : in  STD_LOGIC;
        g_graves     : out unsigned(7 downto 0);
        g_medios     : out unsigned(7 downto 0);
        g_agudos     : out unsigned(7 downto 0);
        vol_graves_o : out unsigned(3 downto 0);
        vol_medios_o : out unsigned(3 downto 0);
        vol_agudos_o : out unsigned(3 downto 0)
    );
end entity;

architecture rtl of modulo_control is
    type t_estados is (IDLE, INC_VOL, DEC_VOL, ESPERA);
    signal estado : t_estados := IDLE;
    
    signal v_graves : integer range 1 to 8 := 4;
    signal v_medios : integer range 1 to 8 := 4;
    signal v_agudos : integer range 1 to 8 := 4;
    
    function vol_a_ganancia(v : integer) return unsigned is
    begin
        case v is
            when 1 => return x"1F"; 
            when 2 => return x"3F";
            when 3 => return x"5F";
            when 4 => return x"7F"; 
            when 5 => return x"9F";
            when 6 => return x"BF";
            when 7 => return x"DF";
            when 8 => return x"FF"; 
            when others => return x"7F";
        end case;
    end function;
begin

    g_graves <= vol_a_ganancia(v_graves);
    g_medios <= vol_a_ganancia(v_medios);
    g_agudos <= vol_a_ganancia(v_agudos);
    
    vol_graves_o <= to_unsigned(v_graves, 4);
    vol_medios_o <= to_unsigned(v_medios, 4);
    vol_agudos_o <= to_unsigned(v_agudos, 4);

    process(clk, reset)
    begin
        if reset = '1' then
            v_graves <= 4;
            v_medios <= 4;
            v_agudos <= 4;
            estado   <= IDLE;
        elsif rising_edge(clk) then
            case estado is
                when IDLE =>
                    
                    if (sel_banda = "001" or sel_banda = "010" or sel_banda = "100") then
                        if btn_up = '0' then 
                            estado <= INC_VOL;     
                        elsif btn_down = '0' then 
                            estado <= DEC_VOL;
                        else 
                            estado <= IDLE;
                        end if;
                    else
                        estado <= IDLE; -- Ignora transiciones erróneas o estados inválidos ("11")
                    end if;
                    
                when INC_VOL =>
                    case sel_banda is
                        when "001" => if v_graves < 8 then v_graves <= v_graves + 1; end if; -- SW0: Graves
                        when "010" => if v_medios < 8 then v_medios <= v_medios + 1; end if; -- SW1: Medios
                        when "100" => if v_agudos < 8 then v_agudos <= v_agudos + 1; end if; -- SW2: Agudos
                        when others => null; -- Protegido contra estados intermedios
                    end case;
                    estado <= ESPERA;
                    
                when DEC_VOL =>
                    case sel_banda is
                        when "001" => if v_graves > 1 then v_graves <= v_graves - 1; end if;
                        when "010" => if v_medios > 1 then v_medios <= v_medios - 1; end if;
                        when "100" => if v_agudos > 1 then v_agudos <= v_agudos - 1; end if;
                        when others => null;
                    end case;
                    estado <= ESPERA;
                    
                when ESPERA =>
                    if btn_up = '1' and btn_down = '1' then 
                        estado <= IDLE;
                    end if;
            end case;
        end if;
   end process;
end architecture;