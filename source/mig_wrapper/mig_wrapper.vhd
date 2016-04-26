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

entity MIG_WRAPPER is
    generic(
        -- DO NOT CHANGE THESE VALUES!
        nCS_PER_RANK        : integer := 1;  -- # of unique CS outputs per Rank for phy.
        BANK_WIDTH          : integer := 3;  -- # of memory Bank Address bits.
        CK_WIDTH            : integer := 1;  -- # of CK/CK# outputs to memory.
        CKE_WIDTH           : integer := 1;  -- # of CKE outputs to memory.
        CS_WIDTH            : integer := 1;  -- # of unique CS outputs to memory.
        DM_WIDTH            : integer := 8;  -- # of Data Mask bits.
        DQ_WIDTH            : integer := 64; -- # of Data (DQ) bits.
        DQS_WIDTH           : integer := 8;  -- # of DQS/DQS# bits.
        ROW_WIDTH           : integer := 14; -- # of memory Row Address bits.
        -- ONLY FOR SIMULATION
        SIM_BYPASS_INIT_CAL : string := "OFF" -- # = "OFF"  - Complete memory init & calibration sequence
                                              -- # = "FAST" - Skip memory init & use abbreviated calib sequence    
    );
    Port (
        -- CLOCKS AND RESETS
        CLK_REF_P       : in    std_logic;
        CLK_REF_N       : in    std_logic;
        ASYNC_RST       : in    std_logic;
        USER_CLK_OUT    : out   std_logic;
        USER_RST_OUT    : out   std_logic;
        -- USER INTERFACE
        MIG_ADDR        : in    std_logic_vector(24 downto 0);
        MIG_READY       : out   std_logic;
        MIG_RD_EN       : in    std_logic;
        MIG_WR_EN       : in    std_logic;
        MIG_WR_DATA     : in    std_logic_vector(511 downto 0);
        MIG_RD_DATA     : out   std_logic_vector(511 downto 0);
        MIG_RD_DATA_VLD : out   std_logic;
        -- DDR3 INTERFACE
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
end MIG_WRAPPER;

architecture FULL of MIG_WRAPPER is

    signal user_clk            : std_logic;
    signal user_rst            : std_logic;
    signal app_cmd_addr        : std_logic_vector(27 downto 0);
    signal app_cmd             : std_logic_vector(2 downto 0);
    signal app_cmd_en          : std_logic;
    signal app_cmd_rdy         : std_logic;
    signal app_wr_data         : std_logic_vector(255 downto 0);
    signal app_wr_data_end     : std_logic;
    signal app_wr_data_vld     : std_logic;
    signal app_wr_data_rdy     : std_logic;
    signal app_full_rdy        : std_logic;
    signal app_rd_data         : std_logic_vector(255 downto 0);
    signal app_rd_data_end     : std_logic;
    signal app_rd_data_vld     : std_logic;
    signal mig_wr_data2_reg_en : std_logic;
    signal mig_wr_data2_reg    : std_logic_vector(255 downto 0);

    type state is (first_state, second_state);
    signal present_state : state;
    signal next_state    : state;

begin

    USER_CLK_OUT <= user_clk;
    USER_RST_OUT <= user_rst;

    app_full_rdy <= app_cmd_rdy AND app_wr_data_rdy;
    app_cmd <= "00" & MIG_RD_EN;
    app_cmd_addr <= MIG_ADDR & "000";
    app_wr_data <= mig_wr_data2_reg WHEN (app_wr_data_end = '1') ELSE MIG_WR_DATA(255 downto 0);

    -- -------------------------------------------------------------------------
    --                        MIG WRAPPER FSM
    -- -------------------------------------------------------------------------

    -- PRESENT STATE REGISTER
    present_state_reg : process (user_clk) 
    begin
        if (rising_edge(user_clk)) then
            if (user_rst = '1') then
                present_state <= first_state;
            else
                present_state <= next_state;
            end if;
        end if;   
    end process;

    -- NEXT STATE AND OUTPUTS LOGIC
    process (present_state, MIG_WR_EN, MIG_RD_EN, app_full_rdy)
    begin

        case present_state is
     
            when first_state =>
                app_wr_data_end <= '0';
                MIG_READY <= app_full_rdy;

                if (MIG_WR_EN = '1' AND app_full_rdy = '1') then
                    app_cmd_en <= '1';
                    app_wr_data_vld <= '1';
                    mig_wr_data2_reg_en <= '1';
                    next_state <= second_state;
                elsif (MIG_RD_EN = '1' AND app_full_rdy = '1') then
                    app_cmd_en <= '1';
                    app_wr_data_vld <= '0';
                    mig_wr_data2_reg_en <= '0';
                    next_state <= first_state;
                else
                    app_cmd_en <= '0';
                    app_wr_data_vld <= '0';
                    mig_wr_data2_reg_en <= '0';
                    next_state <= first_state;
                end if;

            when second_state =>
                app_cmd_en <= '0';
                app_wr_data_end <= '1';
                mig_wr_data2_reg_en <= '0';
                MIG_READY <= '0';

                if (app_full_rdy = '1') then
                    app_wr_data_vld <= '1';
                    next_state <= first_state;
                else
                    app_wr_data_vld <= '0';
                    next_state <= second_state;
                end if;

            when others => 
                app_cmd_en <= '0';
                app_wr_data_end <= '0';
                app_wr_data_vld <= '0';
                mig_wr_data2_reg_en <= '0';
                MIG_READY <= '0';
                next_state <= first_state;
         
        end case;
    end process;

    -- -------------------------------------------------------------------------
    --                        MIG WRAPPER WRITE DATA PART REGISTER
    -- -------------------------------------------------------------------------

    -- MIG SECOND WRITE DATA PART REGISTER
    mig_wr_data2_reg_p : process (user_clk) 
    begin
        if (rising_edge(user_clk)) then
            if (user_rst = '1') then
                mig_wr_data2_reg <= (others => '0');
            elsif (mig_wr_data2_reg_en = '1') then
                mig_wr_data2_reg <= MIG_WR_DATA(511 downto 256);
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --                        MIG WRAPPER READ REGISTERS
    -- -------------------------------------------------------------------------

    -- MIG READ DATA REGISTER
    mig_rd_data_reg_p : process (user_clk) 
    begin
        if (rising_edge(user_clk)) then
            if (user_rst = '1') then
                MIG_RD_DATA <= (others => '0');
            elsif (app_rd_data_vld = '1') then
                if (app_rd_data_end = '1') then
                    MIG_RD_DATA(511 downto 256) <= app_rd_data;
                else
                    MIG_RD_DATA(255 downto 0) <= app_rd_data;
                end if;
            end if;
        end if;
    end process;

    -- MIG READ DATA VALID REGISTER
    mig_rd_data_vld_reg_p : process (user_clk) 
    begin
        if (rising_edge(user_clk)) then
            if (user_rst = '1') then
                MIG_RD_DATA_VLD <= '0';
            else
                MIG_RD_DATA_VLD <= app_rd_data_end AND app_rd_data_vld;
            end if;
        end if;   
    end process;

    -- -------------------------------------------------------------------------
    --                        MIG DDR3 CORE MODULE EDITED FOR ML605 BOARD
    -- -------------------------------------------------------------------------

    mig_ddr3_core_i : entity work.mig_ddr3_core
    generic map(
        REFCLK_FREQ               => 200.0,
        MMCM_ADV_BANDWIDTH        => "OPTIMIZED",
        CLKFBOUT_MULT_F           => 6,
        DIVCLK_DIVIDE             => 1,
        CLKOUT_DIVIDE             => 3,
        nCK_PER_CLK               => 2,
        tCK                       => 2500,
        DEBUG_PORT                => "OFF",
        SIM_BYPASS_INIT_CAL       => SIM_BYPASS_INIT_CAL,
        nCS_PER_RANK              => nCS_PER_RANK,
        DQS_CNT_WIDTH             => 3,
        RANK_WIDTH                => 1,
        BANK_WIDTH                => BANK_WIDTH,
        CK_WIDTH                  => CK_WIDTH,
        CKE_WIDTH                 => CKE_WIDTH,
        COL_WIDTH                 => 10,
        CS_WIDTH                  => CS_WIDTH,
        DQ_WIDTH                  => DQ_WIDTH,
        DM_WIDTH                  => DM_WIDTH,
        DQS_WIDTH                 => DQS_WIDTH,
        ROW_WIDTH                 => ROW_WIDTH,
        BURST_MODE                => "8",
        BM_CNT_WIDTH              => 2,
        ADDR_CMD_MODE             => "1T",
        ORDERING                  => "STRICT",
        WRLVL                     => "ON",
        PHASE_DETECT              => "ON",
        RTT_NOM                   => "60",
        RTT_WR                    => "OFF",
        OUTPUT_DRV                => "HIGH",
        REG_CTRL                  => "OFF",
        nDQS_COL0                 => 3,
        nDQS_COL1                 => 5,
        nDQS_COL2                 => 0,
        nDQS_COL3                 => 0,
        DQS_LOC_COL0              => X"020100",
        DQS_LOC_COL1              => X"0706050403",
        DQS_LOC_COL2              => "0",
        DQS_LOC_COL3              => "0",
        tPRDI                     => 1000000,
        tREFI                     => 7800000,
        tZQI                      => 128000000,
        ADDR_WIDTH                => 28,
        ECC                       => "OFF",
        ECC_TEST                  => "OFF",
        TCQ                       => 100,
        DATA_WIDTH                => 64,
        PAYLOAD_WIDTH             => 64,
        RST_ACT_LOW               => 0,
        IODELAY_GRP               => "IODELAY_MIG",
        INPUT_CLK_TYPE            => "DIFFERENTIAL",
        STARVE_LIMIT              => 2
    )
    port map(
        clk_ref_p                 => CLK_REF_P,
        clk_ref_n                 => CLK_REF_N,
        ddr3_dq                   => DDR3_DQ,
        ddr3_dm                   => DDR3_DM,
        ddr3_addr                 => DDR3_ADDR,
        ddr3_ba                   => DDR3_BA,
        ddr3_ras_n                => DDR3_RAS_N,
        ddr3_cas_n                => DDR3_CAS_N,
        ddr3_we_n                 => DDR3_WE_N,
        ddr3_reset_n              => DDR3_RESET_N,
        ddr3_cs_n                 => DDR3_CS_N,
        ddr3_odt                  => DDR3_ODT,
        ddr3_cke                  => DDR3_CKE,
        ddr3_dqs_p                => DDR3_DQS_P,
        ddr3_dqs_n                => DDR3_DQS_N,
        ddr3_ck_p                 => DDR3_CK_P,
        ddr3_ck_n                 => DDR3_CK_N,
        phy_init_done             => PHY_INIT_DONE,
        app_wdf_wren              => app_wr_data_vld,
        app_wdf_data              => app_wr_data,
        app_wdf_mask              => (others => '0'),
        app_wdf_end               => app_wr_data_end,
        app_addr                  => app_cmd_addr,
        app_cmd                   => app_cmd,
        app_en                    => app_cmd_en,
        app_rdy                   => app_cmd_rdy,
        app_wdf_rdy               => app_wr_data_rdy,
        app_rd_data               => app_rd_data,
        app_rd_data_end           => app_rd_data_end,
        app_rd_data_valid         => app_rd_data_vld,
        ui_clk_sync_rst           => user_rst,
        ui_clk                    => user_clk,
        sys_rst                   => ASYNC_RST
    );

end FULL;