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

entity TESTBENCH is
end TESTBENCH;

--------------------------------------------------------------------------------
-- THIS TESTBENCH REQUIRES DDR3 MODEL FROM XILINX MIG IP CORE!!!
--------------------------------------------------------------------------------

architecture FULL of TESTBENCH is

    -- DO NOT CHANGE THESE VALUES!
    constant nCS_PER_RANK : integer := 1;  -- # of unique CS outputs per Rank for phy.
    constant BANK_WIDTH   : integer := 3;  -- # of memory Bank Address bits.
    constant CK_WIDTH     : integer := 1;  -- # of CK/CK# outputs to memory.
    constant CKE_WIDTH    : integer := 1;  -- # of CKE outputs to memory.
    constant CS_WIDTH     : integer := 1;  -- # of unique CS outputs to memory.
    constant DM_WIDTH     : integer := 8;  -- # of Data Mask bits.
    constant DQ_WIDTH     : integer := 64; -- # of Data (DQ) bits.
    constant DQS_WIDTH    : integer := 8;  -- # of DQS/DQS# bits.
    constant ROW_WIDTH    : integer := 14; -- # of memory Row Address bits.

    constant MEMORY_WIDTH : integer := 16;
    constant NUM_DDR3     : integer := DQ_WIDTH/MEMORY_WIDTH;

    constant TPROP_DQS         : time := 0 ps;  -- Delay for DQS signal during Write Operation
    constant TPROP_DQS_RD      : time := 0 ps;  -- Delay for DQS signal during Read Operation
    constant TPROP_PCB_CTRL    : time := 0 ps;  -- Delay for Address and Ctrl signals
    constant TPROP_PCB_DATA    : time := 0 ps;  -- Delay for data signal during Write operation
    constant TPROP_PCB_DATA_RD : time := 0 ps;  -- Delay for data signal during Read operation

    component ddr3_model
    port(
        rst_n   : in    std_logic;
        ck      : in    std_logic;
        ck_n    : in    std_logic;
        cke     : in    std_logic;
        cs_n    : in    std_logic;
        ras_n   : in    std_logic;
        cas_n   : in    std_logic;
        we_n    : in    std_logic;
        dm_tdqs : inout std_logic_vector((MEMORY_WIDTH/16) downto 0);
        ba      : in    std_logic_vector(BANK_WIDTH-1 downto 0);
        addr    : in    std_logic_vector(ROW_WIDTH-1 downto 0);
        dq      : inout std_logic_vector(MEMORY_WIDTH-1 downto 0);
        dqs     : inout std_logic_vector((MEMORY_WIDTH/16) downto 0);
        dqs_n   : inout std_logic_vector((MEMORY_WIDTH/16) downto 0);
        tdqs_n  : out   std_logic_vector((MEMORY_WIDTH/16) downto 0);
        odt     : in    std_logic
    );
    end component ddr3_model;

    signal CLK_REF_P     : std_logic := '0';
    signal CLK_REF_N     : std_logic := '1';
    signal RST           : std_logic := '0';
    signal sys_rst_n     : std_logic;

    signal rx_uart       : std_logic := '1';
    signal tx_uart       : std_logic;

    signal ddr3_dq       : std_logic_vector(DQ_WIDTH-1 downto 0);
    signal ddr3_dm       : std_logic_vector(DM_WIDTH-1 downto 0);
    signal ddr3_addr     : std_logic_vector(ROW_WIDTH-1 downto 0);
    signal ddr3_ba       : std_logic_vector(BANK_WIDTH-1 downto 0);
    signal ddr3_ras_n    : std_logic;
    signal ddr3_cas_n    : std_logic;
    signal ddr3_we_n     : std_logic;
    signal ddr3_reset_n  : std_logic;
    signal ddr3_cs_n     : std_logic_vector((CS_WIDTH*nCS_PER_RANK)-1 downto 0);
    signal ddr3_odt      : std_logic_vector((CS_WIDTH*nCS_PER_RANK)-1 downto 0);
    signal ddr3_cke      : std_logic_vector(CKE_WIDTH-1 downto 0);
    signal ddr3_dqs_p    : std_logic_vector(DQS_WIDTH-1 downto 0);
    signal ddr3_dqs_n    : std_logic_vector(DQS_WIDTH-1 downto 0);
    signal ddr3_ck_p     : std_logic_vector(CK_WIDTH-1 downto 0);
    signal ddr3_ck_n     : std_logic_vector(CK_WIDTH-1 downto 0);

    signal phy_init_done : std_logic;

   	constant clk_period  : time := 5 ns;
	constant uart_period : time := 8681 ns;
	constant data_value  : std_logic_vector(7 downto 0) := X"13";
	constant data_value2 : std_logic_vector(7 downto 0) := X"10";

begin

    utt: entity work.TOP
    generic map(
        nCS_PER_RANK    => nCS_PER_RANK,
        BANK_WIDTH      => BANK_WIDTH,
        CK_WIDTH        => CK_WIDTH,
        CKE_WIDTH       => CKE_WIDTH,
        CS_WIDTH        => CS_WIDTH,
        DQ_WIDTH        => DQ_WIDTH,
        DM_WIDTH        => DM_WIDTH,
        DQS_WIDTH       => DQS_WIDTH,
        ROW_WIDTH       => ROW_WIDTH,
        SIM_BYPASS_INIT_CAL => "FAST"
    )
    port map (
        ASYNC_RST     => RST,
        CLK_REF_P     => CLK_REF_P,
        CLK_REF_N     => CLK_REF_N,
        -- UART INTERFACE
        UART_TX       => tx_uart,
        UART_RX       => rx_uart,
        -- DDR3 INTERFACE
        DDR3_DQ       => ddr3_dq,
        DDR3_DM       => ddr3_dm,
        DDR3_ADDR     => ddr3_addr,
        DDR3_BA       => ddr3_ba,
        DDR3_RAS_N    => ddr3_ras_n,
        DDR3_CAS_N    => ddr3_cas_n,
        DDR3_WE_N     => ddr3_we_n,
        DDR3_RESET_N  => ddr3_reset_n,
        DDR3_CS_N     => ddr3_cs_n,
        DDR3_ODT      => ddr3_odt,
        DDR3_CKE      => ddr3_cke,
        DDR3_DQS_P    => ddr3_dqs_p,
        DDR3_DQS_N    => ddr3_dqs_n,
        DDR3_CK_P     => ddr3_ck_p,
        DDR3_CK_N     => ddr3_ck_n,
        PHY_INIT_DONE => phy_init_done
    );

    -- DDR3 MODEL FROM XILINX MIG IP CORE
    gen_ddr3_mem : for i in 0 to NUM_DDR3-1 generate
        ddr3_model_i : ddr3_model
        port map(
            rst_n   => ddr3_reset_n,
            ck      => ddr3_ck_p((i*MEMORY_WIDTH)/72),
            ck_n    => ddr3_ck_n((i*MEMORY_WIDTH)/72),
            cke     => ddr3_cke((i*MEMORY_WIDTH)/72),
            cs_n    => ddr3_cs_n((i*MEMORY_WIDTH)/72),
            ras_n   => ddr3_ras_n,
            cas_n   => ddr3_cas_n,
            we_n    => ddr3_we_n,
            dm_tdqs => ddr3_dm((2*(i+1)-1) downto (2*i)),
            ba      => ddr3_ba,
            addr    => ddr3_addr,
            dq      => ddr3_dq(16*(i+1)-1 downto 16*(i)),
            dqs     => ddr3_dqs_p((2*(i+1)-1) downto (2*i)),
            dqs_n   => ddr3_dqs_n((2*(i+1)-1) downto (2*i)),
            tdqs_n  => open,
            odt     => ddr3_odt((i*MEMORY_WIDTH)/72)
        );
    end generate;

    clk_process : process
    begin
        CLK_REF_P <= '0';
        CLK_REF_N <= '1';
        wait for clk_period/2;
        CLK_REF_P <= '1';
        CLK_REF_N <= '0';
        wait for clk_period/2;
    end process;

    test_rx_uart : process
    begin
        rx_uart <= '1';
        RST <= '1';
        wait for 50 ns;
        RST <= '0';

        wait for uart_period;

        rx_uart <= '0'; -- start bit
        wait for uart_period;

        for i in 0 to 7 loop
        	rx_uart <= data_value(i); -- data bits
        	wait for uart_period;
        end loop;

        rx_uart <= '1'; -- parity bit
        wait for uart_period;

        rx_uart <= '1'; -- stop bit
        wait for uart_period;

        wait for 750 ns;

        rx_uart <= '0'; -- start bit
        wait for uart_period;

        for i in 0 to 7 loop
        	rx_uart <= data_value2(i); -- data bits
        	wait for uart_period;
        end loop;

        rx_uart <= '1'; -- parity bit
        wait for uart_period;

        rx_uart <= '1'; -- stop bit
        wait for uart_period;

        wait;
    end process;

end FULL;
