library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;                                                                                                 

entity SobelFilter is port(
                                                          
    CLK      : in std_logic;
    reset : in std_logic;
    
-- signals BRAM1 -> FILTER
    datain : in std_logic_vector (3 downto 0);
    addrb : out std_logic_vector (18 downto 0);
    enb : out std_logic;
    
-- signals FILTER -> BRAM2
    dataout: out std_logic_vector (3 downto 0);
    ena : out std_logic;
    wea : out std_logic;
    addra : out std_logic_vector (18 downto 0)
    
);
end SobelFilter;

architecture Behavioral of SobelFilter is

--state signals
signal pixel_counter : unsigned (18 downto 0) := (others => '0');
signal column_counter : unsigned(9 downto 0) := (others => '0');
signal operation_time : std_logic := '0'; -- 0 false 1 true
signal ena_signal : std_logic := '0'; -- enable scrittura in uscita
signal addrb_signal :  std_logic_vector (18 downto 0); -- serve ad anticipare la richiesta dei pixel in modo che sia sincronizzato correttamente
signal addra_signal :  std_logic_vector (18 downto 0) := "1001010011101000010";-- serve ad dare l'indirizzo dell'immagine in uscita


--typedef memoria
type PIXELS_ARRAY640 is array (639 downto 0) of unsigned (3 downto 0);
type PIXELS_ARRAY3 is array (2 downto 0) of unsigned (3 downto 0);

--struttura che scorre i pixel in modo da ottenere il 3x3
signal array_line0 : PIXELS_ARRAY640 := (others => (others => '0'));
signal array_line1 : PIXELS_ARRAY640 := (others => (others => '0'));
signal array_line2 : PIXELS_ARRAY3 := (others => (others => '0'));

signal matrice_linea0 : PIXELS_ARRAY3 := (others => (others => '0'));
signal matrice_linea1 : PIXELS_ARRAY3 := (others => (others => '0'));
signal matrice_linea2 : PIXELS_ARRAY3 := (others => (others => '0'));



begin
--gestione protocollo che parla con BRAM1 in lettura
addrb <= addrb_signal; -- in modo da ottenere il pixel giusto rispetto al contatore, il problema è il ritardo della memoria
enb <= '1';

--gestione protocollo che parla con BRAM2 in scrittura
wea <= '1';
ena <= ena_signal;
addra <= addra_signal;
ena_signal <= operation_time;

counter_handler: process(CLK)
begin
    if rising_edge(CLK) then
        pixel_counter <= pixel_counter + 1;
        column_counter <= column_counter + 1; 
        addrb_signal <= (std_logic_vector(pixel_counter + 3)); -- 3 = 2+1;  2 sono i cicli di clock che ci mette e +1 è l'indirizzo usato quando si esce dal processo
        operation_time <= '1';
        addra_signal <= std_logic_vector(unsigned(addra_signal) + 1);
        if(addra_signal = "1001010011101000011") then -- 0b1001010011101000011 = 304964 -1 = ossia i pixels rimanenti dopo il filtro
            addra_signal <= (others => '0');
        end if;
        
        -- gestisce cambio fine-inizio riga e fine-inizio immagine
        if((((1 <  pixel_counter))and((pixel_counter <  ((639+1)*2+3)))) or (column_counter = 2) or (column_counter = 3))then 
            operation_time <= '0';
            addra_signal <= addra_signal;
        end if;
        
        if(pixel_counter =  (640*480)-1)then
            pixel_counter <= (others => '0');
        end if;
        if(column_counter = 639 ) then
            column_counter <= (others => '0');
        end if;
        if(addrb_signal =  "1001010111111111111")then -- 0b1001010111111111111 = 307199 = 640*480 -1
            addrb_signal <= (others => '0');
        end if;
        if(addrb_signal =  "0000000000000000000" or addrb_signal =  "0000000000000000001" )then
            addrb_signal <= std_logic_vector(unsigned(addrb_signal) + 1);
        end if;
    end if;

end process;

--  scorrimento shift registers per la matrixce 3x3
array_handler_shifter: process (CLK)
begin
    if rising_edge(CLK) then
        array_line0(639 downto 0) <= array_line0(638 downto 0) & array_line1(639);
        array_line1(639 downto 0) <= array_line1(638 downto 0) & array_line2(2);
        array_line2(2 downto 0) <= array_line2(1 downto 0) & unsigned(datain);
    end if;
end process;

--  gestisce la matrixce 3x3
array_handler: process (CLK)
begin
    if rising_edge(CLK) then
            matrice_linea0(2) <= array_line0(639) ;
            matrice_linea0(1) <= array_line0(638) ;
            matrice_linea0(0) <= array_line0(637) ;
            matrice_linea1(2) <= array_line1(639) ;
            matrice_linea1(0) <= array_line1(637) ;
            matrice_linea2(2) <= array_line2(2) ; 
            matrice_linea2(1) <= array_line2(1) ;
            matrice_linea2(0) <= array_line2(0) ;
    end if;
end process;


calculations: process (CLK)
-- inizializzo le variabili in modo da fare tutto il calcolo in un solo ciclo di clock
    variable v_edge_positive : natural range 60 downto 0 := 0;
    variable v_edge_negative : natural range 60 downto 0 := 0;
    variable h_edge_positive : natural range 60 downto 0 := 0;
    variable h_edge_negative : natural range 60 downto 0 := 0;
    variable gradient : natural range 120 downto 0 := 0;
begin
    if rising_edge(CLK) then
        --calcola le somme parziali del gradiente verticale e orizzontale
        v_edge_positive := TO_INTEGER( matrice_linea2(0) +  2*matrice_linea2(1) + matrice_linea2(2));
        v_edge_negative := TO_INTEGER( matrice_linea0(0) +  2*matrice_linea0(1) + matrice_linea0(2));
        h_edge_positive :=  TO_INTEGER( matrice_linea2(0) +  2*matrice_linea1(0) + matrice_linea0(0));
        h_edge_negative :=  TO_INTEGER( matrice_linea2(2) +  2*matrice_linea1(2) + matrice_linea0(2));
        
        -- verifica di fare sottrazioni ammissibili e in caso scambia le posizioni in modo da fare in automatico i valori assoluti
        if( v_edge_positive > v_edge_negative ) then
            if( h_edge_positive > h_edge_negative ) then
                gradient := v_edge_positive - v_edge_negative + h_edge_positive - h_edge_negative;
            else
                gradient := v_edge_positive - v_edge_negative + h_edge_negative - h_edge_positive;
            end if;
        else
            if( h_edge_positive > h_edge_negative ) then
                gradient := v_edge_negative - v_edge_positive + h_edge_positive - h_edge_negative;
            else
                gradient := v_edge_negative - v_edge_positive + h_edge_negative - h_edge_positive;
            end if;
        end if;
        
        --cast gradient a dataout imponendo una threshold sui massimi
        if( gradient > 14) then
            dataout <= "1111";
        else
            dataout <= std_logic_vector(to_unsigned(gradient,4));
        end if;
    end if;
end process;

end Behavioral;
