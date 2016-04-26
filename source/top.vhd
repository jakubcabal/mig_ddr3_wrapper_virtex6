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

entity TOP is
    generic(
        -- DO NOT CHANGE THESE VALUES!
        nCS_PER_RANK    : integer := 1;  -- # of unique CS outputs per Rank for phy.
        BANK_WIDTH      : integer := 3;  -- # of memory Bank Address bits.
        CK_WIDTH        : integer := 1;  -- # of CK/CK# outputs to memory.
        CKE_WIDTH       : integer := 1;  -- # of CKE outputs to memory.
        CS_WIDTH        : integer := 1;  -- # of unique CS outputs to memory.
        DM_WIDTH        : integer := 8;  -- # of Data Mask bits.
        DQ_WIDTH        : integer := 64; -- # of Data (DQ) bits.
        DQS_WIDTH       : integer := 8;  -- # of DQS/DQS# bits.
        ROW_WIDTH       : integer := 14; -- # of memory Row Address bits.
        -- ONLY FOR SIMULATION
        SIM_BYPASS_INIT_CAL : string := "OFF"
    );
    Port (
        ASYNC_RST       : in    std_logic;
        CLK_REF_P       : in    std_logic;
        CLK_REF_N       : in    std_logic;
        -- UART INTERFACE
        UART_TX         : out   std_logic;
        UART_RX         : in    std_logic;
        -- DDR3
        DDR3_DQ         : inout std_logic_vector(DQ_WIDTH-1 downto 0);
        DDR3_DM         : out   std_logic_vector(DM_WIDTH-1 downto 0);
        DDR3_ADDR       : out   std_logic_vector(ROW_WIDTH-1 downto 0);
        DDR3_BA         : out   std_logic_vector(BANK_WIDTH-1 downto 0);
        DDR3_RAS_N      : out   std_logic;
        DDR3_CAS_N      : out   std_logic;
        DDR3_WE_N       : out   std_logic;
        DDR3_RESET_N    : out   std_logic;
        DDR3_CS_N       : out   std_logic_vector((CS_WIDTH*nCS_PER_RANK)-1 downto 0);
        DDR3_ODT        : out   std_logic_vector((CS_WIDTH*nCS_PER_RANK)-1 downto 0);
        DDR3_CKE        : out   std_logic_vector(CKE_WIDTH-1 downto 0);
        DDR3_DQS_P      : inout std_logic_vector(DQS_WIDTH-1 downto 0);
        DDR3_DQS_N      : inout std_logic_vector(DQS_WIDTH-1 downto 0);
        DDR3_CK_P       : out   std_logic_vector(CK_WIDTH-1 downto 0);
        DDR3_CK_N       : out   std_logic_vector(CK_WIDTH-1 downto 0);
        PHY_INIT_DONE   : out   std_logic
    );
end TOP;

architecture FULL of TOP is

    -- USER CLOCK AND RESET
    signal user_clk        : std_logic;
    signal user_rst        : std_logic;
    -- UART SIGNALS
    signal uart_data_out   : std_logic_vector(7 downto 0);
    signal uart_data_vld   : std_logic;
    signal uart_error      : std_logic;
    signal uart_data_in    : std_logic_vector(7 downto 0);
    signal uart_data_en    : std_logic;
    signal uart_busy       : std_logic;
    -- MIG WRAPPER SIGNALS
    signal mig_addr        : std_logic_vector(24 downto 0);
    signal mig_ready       : std_logic;
    signal mig_wr_data     : std_logic_vector(511 downto 0);
    signal mig_wr_en       : std_logic;
    signal mig_rd_en       : std_logic;
    signal mig_rd_data     : std_logic_vector(511 downto 0);
    signal mig_rd_data_vld : std_logic;

begin

    -- -------------------------------------------------------------------------
    --                        UART MODULE
    -- -------------------------------------------------------------------------

    uart_i: entity work.UART
    generic map (
        BAUD_RATE   => 115200,
        DATA_BITS   => 8,
        PARITY_BIT  => "even",
        CLK_FREQ    => 200e6,
        INPUT_FIFO  => False, -- Attention, FIFO does not yet work properly!
        FIFO_DEPTH  => 256
    )
    port map (
        CLK         => user_clk,
        RST         => user_rst,
        -- UART INTERFACE
        TX_UART     => UART_TX,
        RX_UART     => UART_RX,
        -- USER DATA OUTPUT INTERFACE
        DATA_OUT    => uart_data_out,
        DATA_VLD    => uart_data_vld,
        FRAME_ERROR => uart_error,
        -- USER DATA INPUT INTERFACE
        DATA_IN     => uart_data_in,
        DATA_SEND   => uart_data_en,
        BUSY        => uart_busy
    );

    -- -------------------------------------------------------------------------
    --                        DATA GENERATOR MODULE
    -- -------------------------------------------------------------------------

    data_generator_i: entity work.DATA_GENERATOR
    port map (
        -- CLOCK AND RESETS
        CLK              => user_clk,
        RST              => user_rst,
        -- USER INTERFACE TO UART MODULE
        UART_WR_DATA     => uart_data_in,
        UART_WR_EN       => uart_data_en,
        UART_BUSY        => uart_busy,
        UART_RD_DATA     => uart_data_out,
        UART_RD_DATA_VLD => uart_data_vld,
        UART_FRAME_ERROR => uart_error,
        -- MIG WRAPPER INTERFACE
        MIG_ADDR         => mig_addr,
        MIG_READY        => mig_ready,
        MIG_RD_EN        => mig_rd_en,
        MIG_WR_EN        => mig_wr_en,
        MIG_WR_DATA      => mig_wr_data,
        MIG_RD_DATA      => mig_rd_data,
        MIG_RD_DATA_VLD  => mig_rd_data_vld
    );

    -- -------------------------------------------------------------------------
    --                        MIG DDR3 WRAPPER MODULE
    -- -------------------------------------------------------------------------

    mig_wrapper_i : entity work.MIG_WRAPPER
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
        SIM_BYPASS_INIT_CAL => SIM_BYPASS_INIT_CAL
    )
    port map(
        -- CLOCK AND RESETS
        CLK_REF_P       => CLK_REF_P,
        CLK_REF_N       => CLK_REF_N,
        ASYNC_RST       => ASYNC_RST,
        USER_CLK_OUT    => user_clk,
        USER_RST_OUT    => user_rst,
        -- USER INTERFACE
        MIG_ADDR        => mig_addr,
        MIG_READY       => mig_ready,
        MIG_RD_EN       => mig_rd_en,
        MIG_WR_EN       => mig_wr_en,
        MIG_WR_DATA     => mig_wr_data,
        MIG_RD_DATA     => mig_rd_data,
        MIG_RD_DATA_VLD => mig_rd_data_vld,
        -- DDR3 INTERFACE
        DDR3_DQ         => DDR3_DQ,
        DDR3_DM         => DDR3_DM,
        DDR3_ADDR       => DDR3_ADDR,
        DDR3_BA         => DDR3_BA,
        DDR3_RAS_N      => DDR3_RAS_N,
        DDR3_CAS_N      => DDR3_CAS_N,
        DDR3_WE_N       => DDR3_WE_N,
        DDR3_RESET_N    => DDR3_RESET_N,
        DDR3_CS_N       => DDR3_CS_N,
        DDR3_ODT        => DDR3_ODT,
        DDR3_CKE        => DDR3_CKE,
        DDR3_DQS_P      => DDR3_DQS_P,
        DDR3_DQS_N      => DDR3_DQS_N,
        DDR3_CK_P       => DDR3_CK_P,
        DDR3_CK_N       => DDR3_CK_N,
        PHY_INIT_DONE   => PHY_INIT_DONE
    );

end FULL;