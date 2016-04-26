-- The MIT License (MIT)
--
-- Copyright (c) 2016 Jakub Cabal <xcabal05@stud.feec.vutbr.cz>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--
-- Website: https://github.com/jakubcabal/mig_ddr3_wrapper_virtex6
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DATA_GENERATOR is
    Port (
        -- CLOCKS AND RESETS
        CLK              : in  std_logic;
        RST              : in  std_logic;
        -- USER INTERFACE TO UART MODULE
        UART_WR_DATA     : out std_logic_vector(7 downto 0);
        UART_WR_EN       : out std_logic;
        UART_BUSY        : in  std_logic;
        UART_RD_DATA     : in  std_logic_vector(7 downto 0);
        UART_RD_DATA_VLD : in  std_logic;
        UART_FRAME_ERROR : in  std_logic;
        -- MIG WRAPPER INTERFACE
        MIG_ADDR         : out std_logic_vector(24 downto 0);
        MIG_READY        : in  std_logic;
        MIG_RD_EN        : out std_logic;
        MIG_WR_EN        : out std_logic;
        MIG_WR_DATA      : out std_logic_vector(511 downto 0);
        MIG_RD_DATA      : in  std_logic_vector(511 downto 0);
        MIG_RD_DATA_VLD  : in  std_logic
    );
end DATA_GENERATOR;

architecture FULL of DATA_GENERATOR is

    constant TEST_ADDR : unsigned(24 downto 0) := "0000000000000000011111111";
    constant TEST_DATA : std_logic_vector(511 downto 0) 
    := X"00000000111111112222222233333333444444445555555566666666777777778888888899999999AAAAAAAABBBBBBBBCCCCCCCCDDDDDDDDEEEEEEEE01234567";

    signal generator_mode        : std_logic_vector(2 downto 0);
    signal uart_data_reg         : std_logic_vector(31 downto 0);
    signal uart_data_reg_sel     : std_logic_vector(1 downto 0);
    signal uart_data_reg_en      : std_logic;
    signal uart_rd_data_reg      : std_logic_vector(7 downto 0);
    signal uart_rd_data_reg_en   : std_logic;
    signal cnt_rst               : std_logic;
    signal mig_addr_sig          : unsigned(24 downto 0);
    signal cnt_wr_req            : unsigned(31 downto 0);
    signal cnt_rd_req            : unsigned(31 downto 0);
    signal cnt_rd_resp           : unsigned(31 downto 0);
    signal mig_rd_data_part      : std_logic_vector(31 downto 0);
    signal sel_data_part_reg_en  : std_logic;
    signal sel_data_part         : std_logic_vector(3 downto 0);
    signal sel_data_part_int     : integer range 0 to 15;
    signal test_wr_data_for_seq  : unsigned(511 downto 0);
    signal mig_wr_en_sig         : std_logic;
    signal mig_rd_en_sig         : std_logic;

    type state is (idle, one_request, seq_request, load_data, select_data, send_byte_0, send_byte_1, send_byte_2, send_byte_3);
    signal scmdp_pstate : state;
    signal scmdp_nstate : state;

begin

    -- -------------------------------------------------------------------------
    --                        SIMPLE CMD PROTOCOL (SCMDP) FSM
    -- -------------------------------------------------------------------------

    -- PRESENT STATE REGISTER
    scmdp_pstate_reg : process (CLK) 
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                scmdp_pstate <= idle;
            else
                scmdp_pstate <= scmdp_nstate;
            end if;
        end if;   
    end process;

    -- NEXT STATE AND OUTPUTS LOGIC
    process (scmdp_pstate, UART_FRAME_ERROR, UART_RD_DATA_VLD, UART_RD_DATA, UART_BUSY, uart_data_reg, uart_rd_data_reg)
    begin
        UART_WR_DATA <= X"00";
        UART_WR_EN <= '0';
        generator_mode <= "000";
        cnt_rst <= '0';
        uart_data_reg_sel <= "00";
        uart_data_reg_en <= '0';
        uart_rd_data_reg_en <= '0';
        sel_data_part_reg_en <= '0';

        case scmdp_pstate is
     
            when idle =>
                if (UART_FRAME_ERROR = '0' AND UART_RD_DATA_VLD = '1') then
                    case UART_RD_DATA(7 downto 4) is
                        when X"0" =>
                            scmdp_nstate <= one_request;
                        when X"1" =>
                            scmdp_nstate <= seq_request;
                        when X"2" =>
                            scmdp_nstate <= load_data;
                        when X"3" =>
                            scmdp_nstate <= select_data;
                        when others => 
                            scmdp_nstate <= idle;
                    end case;
                    uart_rd_data_reg_en <= '1';
                else
                    uart_rd_data_reg_en <= '0';
                    scmdp_nstate <= idle;
                end if;

            when one_request =>
                case uart_rd_data_reg(3 downto 0) is
                    when X"1" => -- ONE WRITE
                        generator_mode <= "001";
                        cnt_rst <= '0';
                    when X"2" => -- ONE READ
                        generator_mode <= "010";
                        cnt_rst <= '0';
                    when X"F" => -- RESET ALL COUNTERS
                        generator_mode <= "000";
                        cnt_rst <= '1';
                    when others => 
                        generator_mode <= "000";
                        cnt_rst <= '0';
                end case;
                scmdp_nstate <= idle;

            when seq_request =>
                case uart_rd_data_reg(3 downto 0) is
                    when X"1" => -- SEQ WRITE
                        generator_mode <= "011";
                    when X"2" => -- SEQ READ
                        generator_mode <= "100";
                    when X"3" => -- SEQ READ AND WRITE (1:1) - SAME ADDRESS FOR ONE READ AND WRITE CYCLE
                        generator_mode <= "101";
                    when others => 
                        generator_mode <= "000";
                end case;
                if (UART_FRAME_ERROR = '0' AND UART_RD_DATA_VLD = '1') then
                    if (UART_RD_DATA = X"10") then -- STOP SEQ TEST
                        scmdp_nstate <= idle;
                    else
                        scmdp_nstate <= seq_request;
                    end if;
                else
                    scmdp_nstate <= seq_request;
                end if;

            when select_data =>
                sel_data_part_reg_en <= '1';
                scmdp_nstate <= idle;

            when load_data =>
                case uart_rd_data_reg(3 downto 0) is
                    when X"1" => -- CNT_WR_REQ
                        uart_data_reg_sel <= "01";
                    when X"2" => -- CNT_RD_REQ
                        uart_data_reg_sel <= "10";
                    when X"3" => -- CNT_RD_RESP
                        uart_data_reg_sel <= "11";
                    when X"4" => -- LAST_RD_DATA_PART
                        uart_data_reg_sel <= "00";
                    when others => 
                        uart_data_reg_sel <= "00";
                end case;
                uart_data_reg_en <= '1';
                scmdp_nstate <= send_byte_0;

            when send_byte_0 =>
                UART_WR_DATA <= uart_data_reg(31 downto 24);
                UART_WR_EN <= '1';

                if (UART_BUSY = '0') then
                    scmdp_nstate <= send_byte_1;
                else
                    scmdp_nstate <= send_byte_0;
                end if;

            when send_byte_1 =>
                UART_WR_DATA <= uart_data_reg(23 downto 16);
                UART_WR_EN <= '1';

                if (UART_BUSY = '0') then
                    scmdp_nstate <= send_byte_2;
                else
                    scmdp_nstate <= send_byte_1;
                end if;

            when send_byte_2 =>
                UART_WR_DATA <= uart_data_reg(15 downto 8);
                UART_WR_EN <= '1';

                if (UART_BUSY = '0') then
                    scmdp_nstate <= send_byte_3;
                else
                    scmdp_nstate <= send_byte_2;
                end if;

            when send_byte_3 =>
                UART_WR_DATA <= uart_data_reg(7 downto 0);
                UART_WR_EN <= '1';

                if (UART_BUSY = '0') then
                    scmdp_nstate <= idle;
                else
                    scmdp_nstate <= send_byte_3;
                end if;

            when others => 
                scmdp_nstate <= idle;
         
        end case;
    end process;

    -- UART READ DATA REGISTER
    uart_rd_data_reg_p : process (CLK) 
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                uart_rd_data_reg <= (others => '0');
            elsif (uart_rd_data_reg_en = '1') then
                uart_rd_data_reg <= UART_RD_DATA;
            end if;
        end if;   
    end process;

    -- UART DATA REGISTER
    uart_data_reg_p : process (CLK) 
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                uart_data_reg <= (others => '0');
            elsif (uart_data_reg_en = '1') then
                case uart_data_reg_sel is
                    when "00" =>
                        uart_data_reg <= mig_rd_data_part;
                    when "01" =>
                        uart_data_reg <= std_logic_vector(cnt_wr_req);
                    when "10" =>
                        uart_data_reg <= std_logic_vector(cnt_rd_req);
                    when "11" =>
                        uart_data_reg <= std_logic_vector(cnt_rd_resp);
                    when others => 
                        uart_data_reg <= (others => '0');
                end case;
            end if;
        end if;   
    end process;

    -- SEL DATA PART REGISTER
    sel_data_part_reg_p : process (CLK) 
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                sel_data_part <= (others => '0');
            elsif (sel_data_part_reg_en = '1') then
                sel_data_part <= uart_rd_data_reg(3 downto 0);
            end if;
        end if;   
    end process;

    -- -------------------------------------------------------------------------
    --                        MIG DATA GENERATOR
    -- -------------------------------------------------------------------------

    MIG_ADDR <= std_logic_vector(mig_addr_sig);
    MIG_WR_EN <= mig_wr_en_sig;
    MIG_RD_EN <= mig_rd_en_sig;
    test_wr_data_for_seq <= cnt_wr_req & cnt_wr_req & cnt_wr_req & cnt_wr_req &
                            cnt_wr_req & cnt_wr_req & cnt_wr_req & cnt_wr_req &
                            cnt_wr_req & cnt_wr_req & cnt_wr_req & cnt_wr_req &
                            cnt_wr_req & cnt_wr_req & cnt_wr_req & cnt_wr_req;

    -- MIG DATA GENERATOR REGISTER
    process (CLK) 
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' OR cnt_rst = '1') then
                mig_addr_sig <= (others => '0');
                MIG_WR_DATA <= (others => '0');
                mig_wr_en_sig <= '0';
                mig_rd_en_sig <= '0';
                cnt_wr_req <= (others => '0');
                cnt_rd_req <= (others => '0');
            elsif (MIG_READY = '1') then
                case generator_mode is

                    when "000" => -- IDLE
                        mig_addr_sig <= (others => '0');
                        MIG_WR_DATA <= (others => '0');
                        mig_wr_en_sig <= '0';
                        mig_rd_en_sig <= '0';
                        cnt_wr_req <= cnt_wr_req;
                        cnt_rd_req <= cnt_rd_req;

                    when "001" => -- ONE WRITE
                        mig_addr_sig <= TEST_ADDR;
                        MIG_WR_DATA <= TEST_DATA;
                        mig_wr_en_sig <= '1';
                        mig_rd_en_sig <= '0';
                        cnt_wr_req <= cnt_wr_req + 1;
                        cnt_rd_req <= cnt_rd_req;

                    when "010" => -- ONE READ
                        mig_addr_sig <= TEST_ADDR;
                        MIG_WR_DATA <= (others => '0');
                        mig_wr_en_sig <= '0';
                        mig_rd_en_sig <= '1';
                        cnt_wr_req <= cnt_wr_req;
                        cnt_rd_req <= cnt_rd_req + 1;

                    when "011" => -- SEQ WRITE
                        mig_addr_sig <= mig_addr_sig + 1; -- SEQ ADDR
                        MIG_WR_DATA <= std_logic_vector(test_wr_data_for_seq);
                        mig_wr_en_sig <= '1';
                        mig_rd_en_sig <= '0';
                        cnt_wr_req <= cnt_wr_req + 1;
                        cnt_rd_req <= cnt_rd_req;

                    when "100" => -- SEQ READ
                        mig_addr_sig <= mig_addr_sig + 1; -- SEQ ADDR
                        MIG_WR_DATA <= (others => '0');
                        mig_wr_en_sig <= '0';
                        mig_rd_en_sig <= '1';
                        cnt_wr_req <= cnt_wr_req;
                        cnt_rd_req <= cnt_rd_req + 1;

                    when "101" => -- SEQ READ AND WRITE (1:1) - SAME ADDRESS FOR ONE READ AND WRITE CYCLE
                        MIG_WR_DATA <= std_logic_vector(test_wr_data_for_seq);

                        if (mig_wr_en_sig = '1') then
                            mig_addr_sig <= mig_addr_sig;
                            mig_wr_en_sig <= '0';
                            mig_rd_en_sig <= '1';
                            cnt_wr_req <= cnt_wr_req;
                            cnt_rd_req <= cnt_rd_req + 1;
                        else
                            mig_addr_sig <= mig_addr_sig + 1;
                            mig_wr_en_sig <= '1';
                            mig_rd_en_sig <= '0';
                            cnt_wr_req <= cnt_wr_req + 1;
                            cnt_rd_req <= cnt_rd_req; 
                        end if ;

                    when others => 
                        mig_addr_sig <= (others => '0');
                        MIG_WR_DATA <= (others => '0');
                        mig_wr_en_sig <= '0';
                        mig_rd_en_sig <= '0';
                        cnt_wr_req <= cnt_wr_req;
                        cnt_rd_req <= cnt_rd_req;
                 
                end case;
            end if;
        end if;   
    end process;

    sel_data_part_int <= to_integer(unsigned(sel_data_part));

    -- MIG DATA RECEIVER REGISTER
    process (CLK) 
    begin
        if (rising_edge(CLK)) then
            if (RST = '1' OR cnt_rst = '1') then
                cnt_rd_resp <= (others => '0');
                mig_rd_data_part <= (others => '0');
            elsif (MIG_RD_DATA_VLD = '1') then
                cnt_rd_resp <= cnt_rd_resp + 1;
                mig_rd_data_part <= MIG_RD_DATA((32*sel_data_part_int)+31 downto (32*sel_data_part_int));            
            end if;
        end if;   
    end process;

end FULL;