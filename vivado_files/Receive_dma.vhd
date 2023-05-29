library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_unsigned.all;




entity recive_dma is
  port (
    --uscite to BRAM
    douta: out std_logic_vector(7 downto 0);
    enable_a : out std_logic;
    wea : out std_logic;
    addra : out unsigned(17 downto 0);
    
    -- axi stream ports
    s_axis_clk    : in  std_logic;
    s_axis_tvalid : in std_logic;
    s_axis_tdata : in std_logic_vector(31 downto 0);
    s_axis_tstrb : in std_logic_vector(3 downto 0);
    s_axis_tlast : in std_logic;  
    s_axis_tready	: out	std_logic;
    
    --entrate di controllo
    switch_format : in std_logic

  );
end recive_dma;


architecture rtl of recive_dma is

  -- Define the states of state machine                                             
  type    state is (IDLE, RECIVE_STREAM);          

  signal  sm_state : state := IDLE;                                                   

  -- AXI Stream internal signals
  signal datain :  std_logic_vector (31 downto 0) := (others => '1'); -- memorizza i dati in ingresso
  signal dataout : std_logic_vector (7 downto 0) := (others => '1');
  signal dataout2 : std_logic_vector (7 downto 0) := (others => '1');
  signal p2_cnt : unsigned(17 downto 0) := ("111111111111111111"); --in modo da compensare il ritardo dei dati in uscita (ritardono di 1 ciclo dall'ingresso) e far coincidere indirizzo e colore del pixel preciso
  signal enable : std_logic:= '0';

begin
    datain <= s_axis_tdata;
    douta <= dataout when switch_format = '0' else dataout2;
    wea <= '1';
    addra <= p2_cnt;
    enable_a <= enable;
    
  -- Control state machine implementation                                               
  sm_pr : process(s_axis_clk)                                                                        
  begin        
    if (rising_edge (s_axis_clk)) then                                                       
        case (sm_state) is
                                                                      
        when IDLE => -- sto aspettando di ricevere dati
            s_axis_tready <= '1';
            
            -- start receiving 
            if (s_axis_tvalid = '1') then -- se valid è 1 i valori sono validi
            
                --gestione stato
                sm_state <= RECIVE_STREAM; -- cambio stato
                
                -- gestione dati e conversione
                dataout <= datain(31 downto 28 ) & datain(15 downto 12); 
                dataout2 <= datain(23 downto 20 ) & datain(7 downto 4); 
                
                enable <= s_axis_tvalid; -- t_valid out
                p2_cnt <= p2_cnt + 1 ;  -- conta i dati in arrivo 
                if(p2_cnt = 640*480/2 - 1) then -- reset a fine immagine
                    p2_cnt <= (others => '0');
                end if;
            end if;
                                                                                                                  
        when RECIVE_STREAM  => 
            if (s_axis_tvalid = '1') then
            
                -- gestione stato
                if ( s_axis_tlast = '1' ) then -- se è l'ultimo dato cambio stato
                    sm_state <= IDLE;   
                end if;
                
                --gestione dati
                dataout <= datain(31 downto 28 ) & datain(15 downto 12);
                dataout2 <= datain(23 downto 20 ) & datain(7 downto 4);
                
                enable <= s_axis_tvalid; -- t_valid out
                p2_cnt <= p2_cnt + 1 ;  -- conta i dati in arrivo 
                if(p2_cnt = 640*480/2 - 1) then -- reset a fine immagine
                    p2_cnt <= (others => '0');
                end if;
          end if;
                                                                                                               
        when others =>                                                                   
          sm_state <= IDLE;   
                                                                                                                                                              
      end case;                                                                             
    end if; 
  end process sm_pr;                                                                                
end rtl;                                                      
