library ieee;                                                                             
use ieee.std_logic_1164.all;                                                              
use ieee.numeric_std.all;                                                                                                 

entity frame_generator is port ( 
    CLK      : in std_logic;    
                                                                                                  
    r_out               : out std_logic_vector(3 downto 0);
    g_out               : out std_logic_vector(3 downto 0);
    b_out               : out std_logic_vector(3 downto 0);
    
    active : in std_logic;
    
    --immagine filtrata
    in_pixel: in std_logic_vector(3 downto 0);
    enable_b : out std_logic;
    add_r : out unsigned(18 downto 0);
    
    -- immagine non filtrata
    in_pixel_nfiltered: in std_logic_vector(3 downto 0);
    enable_b_nfiltered : out std_logic;
    add_r_nfiltered : out unsigned(18 downto 0);
    
    --selezione per vedere immagine reale o filtrata
    switch : in std_logic
    
      );
end frame_generator;

architecture impl of frame_generator is

-- gestione del clock in modo che sia corretto per la vga
signal clk_divider        : unsigned(1  downto 0) := (others => '0');
signal active_buffered : std_logic;

--typedef memoria
type PIXEL is array (1 downto 0) of std_logic_vector (3 downto 0);
type V_SUM is array (639 downto 0) of std_logic_vector (14 downto 0);
type H_SUM is array (479 downto 0) of std_logic_vector (15 downto 0);

signal pixels : PIXEL := (others => (others => '0'));
--mask for object detection 
signal red_pixel : std_logic_vector(3 downto 0) := (others => '0');

signal partial_vertical_sum : V_SUM := (others => (others => '0'));
signal partial_horizontal_sum : H_SUM := (others => (others => '0'));


--trasfermento pixel
    -- Counter normal image
signal p_cnt_normal              : unsigned(18 downto 0) := "0000000000000000001" ;
    -- Counter filtered image
signal p_cnt_filtered              : unsigned(18 downto 0) := "0000000000000000000" ;

--istogramma pixel
    -- columns counter
signal column_counter : unsigned(9 downto 0) := "0000000010";
    -- lines counter
signal line_counter : unsigned(8 downto 0) := "000000000";

    -- start l'elaborazione dei pixels dell'immagine
signal start : std_logic := '0';

    -- indice delle colonne del riquadro
signal sx_column : unsigned(9 downto 0) := "0000000000";
signal dx_column : unsigned(9 downto 0) := "0000010000";
signal buffered_column : unsigned (9 downto 0);

-- indice delle righe del riquadro
signal up_line : unsigned(8 downto 0) := "000000000";
signal down_line : unsigned(8 downto 0) := "000100000";

signal partial_vertical_sum_dx : std_logic_vector (14 downto 0);
signal partial_vertical_sum_sx : std_logic_vector (14 downto 0);
signal partial_vertical_sum_it : std_logic_vector (14 downto 0) := "000000000000000";


signal partial_horizontal_sum_up : std_logic_vector (15 downto 0);
signal partial_horizontal_sum_dw : std_logic_vector (15 downto 0);
signal partial_horizontal_sum_it : std_logic_vector (15 downto 0);
signal partial_horizontal_sum_line : std_logic_vector (15 downto 0);


begin

--vga signals
r_out <= pixels(1);
g_out <= pixels(1);
b_out <= red_pixel;


--standard image
add_r_nfiltered <= TO_UNSIGNED(0,19) when (p_cnt_normal = 640*480 - 1) else p_cnt_normal + 1 ;
enable_b_nfiltered <= '1';

-- filtered image
add_r <= TO_UNSIGNED(0,19) when (p_cnt_filtered = 638*478 - 1) else p_cnt_filtered + 1 ;
enable_b <= '1';

vga_frame: process (CLK)
begin
    if rising_edge(CLK) then
        clk_divider <= clk_divider + 1;
        if clk_divider = 4 - 1 then -- 102Mhz ACLK input clock required
            clk_divider <= (others => '0');  
            if active = '1' then
                red_pixel <= in_pixel_nfiltered;
                pixels(1) <=  in_pixel_nfiltered;
                p_cnt_normal <= p_cnt_normal + 1;
                
                 -- faccio in modo che i pixels in uscita siano quelli dell'immagine filtrata corniciati da tutti pixels neri
                if(switch = '1') then
                pixels(1) <= "0000";
                red_pixel <= "0000";
                end if;
                
                --ridimensionamento per fare in modo che lavori con l'immagine uscente dal filtro
                if(not((p_cnt_normal < 640) or (p_cnt_normal > 640*479 -1  ) or  (column_counter = 639  ) or  (column_counter = 0  ))) then
                    -- faccio in modo che i pixels in uscita siano quelli dell'immagine filtrata
                    if(switch = '1') then
                        pixels(1) <=  in_pixel;
                        red_pixel <= in_pixel;
                    end if;
                    -- counter
                    p_cnt_filtered <= p_cnt_filtered + 1;
                    if( p_cnt_filtered = 638*478 - 1 )then
                        p_cnt_filtered <= (others => '0');
                    end if;
                    --end counter
                end if;
                --fine ridimensionamento

                column_counter <= column_counter +1; 
                if( column_counter = 640 - 1 )then
                    partial_horizontal_sum(TO_INTEGER(line_counter)) <=  std_logic_vector(unsigned(partial_horizontal_sum_line) + unsigned(in_pixel));
                     partial_horizontal_sum_line <= (others => '0');
                    line_counter <= line_counter + 1;
                    column_counter <= (others => '0');
                    if( line_counter = 480 - 1 )then
                        line_counter <= (others => '0');
                    end if;
                else 
                    partial_horizontal_sum_line <=  std_logic_vector(unsigned(partial_horizontal_sum_line) + unsigned(in_pixel));
                end if;
                
                
                if( p_cnt_normal = 640*480 - 1 )then
                    p_cnt_normal <= TO_UNSIGNED(TO_INTEGER(TO_UNSIGNED(0,1)),19);
                end if;
                
                -- creazione delle somme parziali
                if(column_counter = 640 -1) then
                    partial_vertical_sum_it <= partial_vertical_sum(0);
                else
                    partial_vertical_sum_it <= partial_vertical_sum(TO_INTEGER(column_counter + 1));
                end if;

                partial_vertical_sum(TO_INTEGER(column_counter)) <= std_logic_vector(unsigned(partial_vertical_sum_it) + unsigned(in_pixel));
                
                -- sovrascrizione per fare una cornice di grigio
                if((column_counter = sx_column or column_counter = dx_column )and (line_counter >= up_line and line_counter <= down_line))then
                    red_pixel <= "1111";
                    pixels(1) <= "0000";
                end if;
                if((line_counter = up_line or line_counter = down_line )and (column_counter >= sx_column and column_counter <= dx_column))then
                    red_pixel <= "1111";
                    pixels(1) <= "0000";
                end if;                 
            end if; -- active=1
            active_buffered <= active; 
            if(active = '0' and active_buffered = '1' and p_cnt_normal = 0 and line_counter = "000000000")then
                start <= '1';
                column_counter <= column_counter +1;
                partial_vertical_sum_dx <= partial_vertical_sum(TO_INTEGER(column_counter + 1));
                partial_vertical_sum_sx <=  partial_vertical_sum(TO_INTEGER(column_counter + 1));
                partial_vertical_sum_it <= partial_vertical_sum(TO_INTEGER(column_counter + 1));
                partial_horizontal_sum_up <= partial_horizontal_sum(TO_INTEGER(line_counter));
                partial_horizontal_sum_dw <=  partial_horizontal_sum(TO_INTEGER(line_counter));
                partial_horizontal_sum_it <= partial_horizontal_sum(TO_INTEGER(line_counter));
                sx_column <=  column_counter + 1;
                dx_column <=  column_counter + 1;
                up_line <=  line_counter ;
                down_line <=  line_counter;
                active_buffered <= '0';
            end if;
        
        if(start = '1') then
        -- parte di confronto per trovare i due maggiori nelle somme parziali di riga e colonna. successivamente si ordineneranno effettivamente tra dx e sx e up e down
            --somme verticali
       
            if(partial_vertical_sum_it > partial_vertical_sum_sx) then
                sx_column <=  column_counter;
                partial_vertical_sum_sx <=  partial_vertical_sum_it;
           
            elsif(partial_vertical_sum_it > partial_vertical_sum_dx) then
                dx_column <=  column_counter;
                partial_vertical_sum_dx <= partial_vertical_sum_it;
                
            end if;
            -- somme orizzontali
            if(partial_horizontal_sum_it > partial_horizontal_sum_up) then
                up_line <=  line_counter;
                partial_horizontal_sum_up <= partial_horizontal_sum_it;                           
            elsif(partial_horizontal_sum_it > partial_horizontal_sum_dw) then
                down_line <=  line_counter;
                partial_horizontal_sum_dw <=  partial_horizontal_sum_it;   
            end if;

  -- caricamento somma parziale alla colonna e riga +1 in modo che siano sincronizzate con il prossimo ciclo
            if(column_counter = 640 -1) then
                partial_vertical_sum_it <= partial_vertical_sum(0);
            else
                partial_vertical_sum_it <= partial_vertical_sum(TO_INTEGER(column_counter + 1));
            end if;
            if(line_counter  = 480 -1) then
                partial_horizontal_sum_it <= partial_horizontal_sum(0);

            else
                partial_horizontal_sum_it <= partial_horizontal_sum(TO_INTEGER(line_counter + 1));

            end if;
        
            line_counter <= line_counter + 1;
            column_counter <= column_counter +1;
            if( line_counter = 480 - 1 )then
                line_counter <= line_counter;
            end if; 
            if( column_counter = 640 - 1 )then
                column_counter <= (others => '0');
            end if; 
            if( column_counter = "0000000000" )then --  default value iniziale di column counter - 1, se dflt vl = 0 => 359
                column_counter <= "0000000001"; --  default value iniziale di column counter
                line_counter <= (others => '0');
                partial_vertical_sum  <= (others => (others => '0'));
                partial_horizontal_sum <= (others => (others => '0'));                    
                start <= '0';
    -- scambio indici in modo che il minore e il maggiore siano al posto giusto
                if(sx_column > dx_column)then
                    dx_column <= sx_column +1 ;
                    sx_column <= dx_column -1;
                else
                    dx_column <= dx_column +1 ;
                    sx_column <= sx_column -1;
                end if;
                if(up_line > down_line)then
                    up_line <= down_line -1;
                    down_line <= up_line +1; 
                else
                    up_line <= up_line -1;
                    down_line <= down_line +1;
                end if;
            end if;
        end if;
                end if; -- clock divider

    end if; -- rising edge
end process;

end impl;
