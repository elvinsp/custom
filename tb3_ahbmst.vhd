--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   21:58:27 11/21/2015
-- Design Name:   
-- Module Name:   C:/Users/Elvin/OneDrive/GitHub/NoC/tb_noc.vhd
-- Project Name:  NoC
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: top_noc
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
library gaisler;
use gaisler.ahbtbp.all;
use work.custom.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.testlib.all;
use grlib.devices.all;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb3_ahbmst IS
END tb3_ahbmst;
 
ARCHITECTURE test_ahbmst OF tb3_ahbmst IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    
	constant dmai_none : ahb_dma_in_type := ((others => '0'), (others => '0'), '0', '0', '0', '0', '0', (others => '0'));
   --Inputs
   signal rstn : std_logic := '0';
   signal clkm : std_logic := '0';
   signal ahbsi : ahb_slv_in_type;
   signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
   signal ahbmi : ahb_mst_in_type;
   signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);
	signal ctrl  : ahbtb_ctrl_type;
	--signal ctrli : ahbtbm_ctrl_in_type;
	--signal ctrlo : ahbtbm_ctrl_out_type;
	signal mst0_tx, mst0_rx, mst1_tx, mst1_rx, mst2_tx, mst2_rx : noc_transfer_reg := noc_transfer_none;
	signal slv_tx, slv_rx : noc_transfer_reg := noc_transfer_none;
	signal mst0_tx_ready, mst0_tx_ack, mst0_rx_ready, mst0_rx_ack : std_logic := '0';
	signal mst1_tx_ready, mst1_tx_ack, mst1_rx_ready, mst1_rx_ack : std_logic := '0';
	signal mst2_tx_ready, mst2_tx_ack, mst2_rx_ready, mst2_rx_ack : std_logic := '0';
	signal slv_tx_ready, slv_tx_ack, slv_rx_ready, slv_rx_ack : std_logic := '0';

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
BEGIN

	-- Instantiate the Unit Under Test (UUT)
   slv0: vcslv
		generic map(hindex => 0, ioaddr => 7)
		port map(rstn, clkm, slv_tx_ready, slv_tx_ack, slv_tx, slv_rx_ready, slv_rx_ack, slv_rx, ahbsi, ahbso(0));
		  
	ahb0 : ahbctrl       -- AHB arbiter/multiplexer
				generic map (defmast => 0, split => 1, 
									rrobin => 1, ioaddr => 16#800#,
									ioen => 1, nahbm => 3, nahbs => 1)
				port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);	 

--   ahbtbm0 : ahbtbm
--		generic map(hindex => 3, hirq => 0, venid => VENDOR_GAISLER,
--                 devid => GAISLER_LEON3, version => 0,
--                 chprot => 3, incaddr => 0) -- AMBA master index 0
--		port map(rstn, clkm, ctrl.i, ctrl.o, ahbmi, ahbmo(3));
--	
	mst0 : vcmst
		generic map(hindex => 0)
		port map(rstn, clkm, mst0_rx_ready, mst0_rx_ack, mst0_rx, mst0_tx_ready, mst0_tx_ack, mst0_tx, ahbmi, ahbmo(0));
	mst1 : vcmst
		generic map(hindex => 1)
		port map(rstn, clkm, mst1_rx_ready, mst1_rx_ack, mst1_rx, mst1_tx_ready, mst1_tx_ack, mst1_tx, ahbmi, ahbmo(1));
	mst2 : vcmst
		generic map(hindex => 2)
		port map(rstn, clkm, mst2_rx_ready, mst2_rx_ack, mst2_rx, mst2_tx_ready, mst2_tx_ack, mst2_tx, ahbmi, ahbmo(2));

   -- Clock process definitions
   clk_process :process
   begin
		clkm <= '0';
		wait for clk_period/2;
		clkm <= '1';
		wait for clk_period/2;
   end process;
 
   -- Stimulus process
   stim_proc: process
   begin
		rstn <= '0';
		wait for 100 ns;
		rstn <= '1';
		--wait for 60 ns;
		--rstn <= '1';
		wait;
	end process;
	
	slv_proc: process(rstn, clkm)
	variable bnoc : noc_transfer_reg;
	variable rbusy, tbusy : std_logic;
	begin
		if(rstn = '0') then
			rbusy := '0';
			tbusy := '0';
			slv_tx_ack <= '0';
			slv_rx_ready <= '0';
			slv_rx <= noc_transfer_none;
			bnoc := noc_transfer_none;
		elsif(clkm'event and clkm = '1') then
			if(slv_tx_ready = '0') then 
				slv_tx_ack <= '0';
				tbusy := '0';
			end if;
			-------------
			if(slv_rx_ack = '1') then 
				slv_rx_ready <= '0';
			end if;
			-------------
			if(slv_tx_ready = '1' and tbusy = '0') then
				tbusy := '1';
				if(conv_integer(slv_tx.len) > 1) then
					bnoc := slv_tx;
					rbusy := '0';
				end if;
				slv_tx_ack <= '1';
			end if;
			-- respond to read request
			if(bnoc.len /= "000" and bnoc.flit(0)(15) = '0' and rbusy = '0') then
				rbusy := '1';
				bnoc.flit(1) := x"12345678";
				bnoc.flit(2) := x"9abcdef0";
				bnoc.flit(3) := x"dead0000";
				if(bnoc.flit(0)(9 downto 7) = "000") then
					bnoc.len := "010";
				elsif(bnoc.flit(0)(9 downto 7) = "001") then
					bnoc.len := "101";
				end if;
				bnoc.flit(0)(31 downto 28) := "0011";
				slv_rx <= bnoc;
				slv_rx_ready <= '1';
			end if;
		end if;
	end process;
	
	ahb_proc: process
	begin
		wait for 40 ns;
		-- Initialize the control signals
		ahbtbminit(ctrl); -- at 100ns
      wait for 100 ns;
		-------------------------------------------------
--		--wait until clkm'event and clkm='1';
--		--ahbread(x"40000010", x"12345678", "10", 2, false , ctrl);
--		wait until clkm'event and clkm='1';
--		ahbwrite(x"40000014", x"aaaaaaaa", "10", "10", '1', 2, false , ctrl);
--		wait until clkm'event and clkm='1';
--		--ahbwrite(x"40000018", x"88888888", "10", "10", '1', 2, false , ctrl);
--		--wait until clkm'event and clkm='1';
--		--ahbtbmidle(false, ctrl);
--		--wait until clkm'event and clkm='1';
--		ahbwrite(x"4000001c", x"ffffffff", "10", "10", '1', 2, false , ctrl);
--		wait until clkm'event and clkm='1';
--		ahbtbmidle(false, ctrl);
--		wait until clkm'event and clkm='1';
--		ahbwrite(x"40000020", x"44444444", "10", "11", '1', 2, false , ctrl);
--		wait until clkm'event and clkm='1';
--		--ahbread(x"40000010", x"12345678", "10", 2, false , ctrl);
--		--wait until clkm'event and clkm='1';
--		ahbtbmidle(false, ctrl);
		--wait for 200 ns;
		-------------------------------------------------
		-- Stop simulation
		--ahbtbmdone(0, ctrl); 
      wait;
   end process;
	
	mst0_proc: process
	begin
		wait for 140 ns;
		mst0_rx.len <= "100";
		mst0_rx.addr <= "0010";
		mst0_rx.flit(0)(15) <= '1';
		mst0_rx.flit(0)(14 downto 13) <= "10";
		mst0_rx.flit(0)(12 downto 10) <= "010";
		mst0_rx.flit(0)(9 downto 7) <= "001";
		mst0_rx.flit(0)(6 downto 3) <= "1110";
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(1) <= x"40000018";
		mst0_rx.flit(2) <= x"12345678";
		mst0_rx.flit(3) <= x"9abcdef0";
		mst0_rx.flit(4) <= x"dead0000";
		wait until clkm'event and clkm = '1';
		mst0_rx_ready <= '1';
		wait until mst0_rx_ack = '1';
		wait until clkm'event and clkm = '1';
		mst0_rx <= noc_transfer_none;
		mst0_rx_ready <= '0';
		wait until clkm'event and clkm = '1';
		------------------------------------------
		mst0_rx.len <= "011";
		mst0_rx.addr <= "0010";
		mst0_rx.flit(0)(15) <= '0';
		mst0_rx.flit(0)(14 downto 13) <= "10";
		mst0_rx.flit(0)(12 downto 10) <= "010";
		mst0_rx.flit(0)(9 downto 7) <= "000";
		mst0_rx.flit(0)(6 downto 3) <= "1110";
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(1) <= x"40000600";
		mst0_rx.flit(2) <= x"11111111";
		mst0_rx.flit(3) <= x"22222222";
		mst0_rx.flit(4) <= x"44444444";
		mst0_rx_ready <= '1';
		wait until clkm'event and clkm = '1';
		wait until mst0_rx_ack = '1';
		wait until clkm'event and clkm = '1';
		mst0_rx <= noc_transfer_none;
		mst0_rx_ready <= '0';
		wait until clkm'event and clkm = '1';
		------------------------------------------
		mst0_rx.len <= "011";
		mst0_rx.addr <= "0010";
		mst0_rx.flit(0)(15) <= '1';
		mst0_rx.flit(0)(14 downto 13) <= "10";
		mst0_rx.flit(0)(12 downto 10) <= "010";
		mst0_rx.flit(0)(9 downto 7) <= "000";
		mst0_rx.flit(0)(6 downto 3) <= "1110";
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(1) <= x"40000030";
		mst0_rx.flit(2) <= x"88888888";
		mst0_rx.flit(3) <= x"cccccccc";
		mst0_rx.flit(4) <= x"ffffffff";
		mst0_rx_ready <= '1';
		wait until clkm'event and clkm = '1';
		wait until mst0_rx_ack = '1';
		wait until clkm'event and clkm = '1';
		mst0_rx <= noc_transfer_none;
		mst0_rx_ready <= '0';
		wait until clkm'event and clkm = '1';
		------------------------------------------
		wait;
	end process;

	mst1_proc: process
	begin
		wait for 140 ns;
		mst1_rx.len <= "101";
		mst1_rx.addr <= "0010";
		mst1_rx.flit(0)(15) <= '1';
		mst1_rx.flit(0)(14 downto 13) <= "10";
		mst1_rx.flit(0)(12 downto 10) <= "010";
		mst1_rx.flit(0)(9 downto 7) <= "001";
		mst1_rx.flit(0)(6 downto 3) <= "1110";
		mst1_rx.flit(0)(31 downto 28) <= "0010";
		mst1_rx.flit(1) <= x"40000030";
		mst1_rx.flit(2) <= x"12345678";
		mst1_rx.flit(3) <= x"9abcdef0";
		mst1_rx.flit(4) <= x"dead0000";
		wait until clkm'event and clkm = '1';
		--mst1_rx_ready <= '1';
		wait until mst1_rx_ack = '1';
		wait until clkm'event and clkm = '1';
		mst1_rx <= noc_transfer_none;
		mst1_rx_ready <= '0';
		wait until clkm'event and clkm = '1';
		------------------------------------------
		wait;
	end process;

	mst2_proc: process
	begin
		wait for 140 ns;
		mst2_rx.len <= "100";
		mst2_rx.addr <= "0010";
		mst2_rx.flit(0)(15) <= '1';
		mst2_rx.flit(0)(14 downto 13) <= "10";
		mst2_rx.flit(0)(12 downto 10) <= "010";
		mst2_rx.flit(0)(9 downto 7) <= "001";
		mst2_rx.flit(0)(6 downto 3) <= "1110";
		mst2_rx.flit(0)(31 downto 28) <= "0010";
		mst2_rx.flit(1) <= x"40000060";
		mst2_rx.flit(2) <= x"12345678";
		mst2_rx.flit(3) <= x"9abcdef0";
		mst2_rx.flit(4) <= x"dead0000";
		wait until clkm'event and clkm = '1';
		--mst2_rx_ready <= '1';
		wait until mst2_rx_ack = '1';
		wait until clkm'event and clkm = '1';
		mst2_rx <= noc_transfer_none;
		mst2_rx_ready <= '0';
		wait until clkm'event and clkm = '1';
		------------------------------------------
		wait;
	end process;

END;