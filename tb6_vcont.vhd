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
use gaisler.custom.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.testlib.all;
use grlib.devices.all;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb6_vccont IS
END tb6_vccont;
 
ARCHITECTURE test_ahbmst OF tb6_vccont IS 
 
   --Inputs
   signal rstn : std_logic := '0';
   signal clkm : std_logic := '0';
   signal ahbsi, ahb1si : ahb_slv_in_type;
   signal ahbso, ahb1so : ahb_slv_out_vector := (others => ahbs_none);
   signal ahbmi, ahb1mi : ahb_mst_in_type;
   signal ahbmo, ahb1mo : ahb_mst_out_vector := (others => ahbm_none);
	--signal ctrli : ahbtbm_ctrl_in_type;
	--signal ctrlo : ahbtbm_ctrl_out_type;
	signal mst0_tx, mst0_rx, slv_rx, slv_tx : noc_transfer_reg := noc_transfer_none;
	signal mst0_tx_ready, mst0_tx_ack, mst0_rx_ready, mst0_rx_ack : std_logic := '0';
	signal slv_rx_ready, slv_rx_ack, slv_tx_ready, slv_tx_ack : std_logic := '0';

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
BEGIN

	-- Instantiate the Unit Under Test (UUT)
		  
	leon_ahb : ahbctrl       -- AHB arbiter/multiplexer
				generic map (defmast => 0, split => 1, 
									rrobin => 1, ioaddr => 16#100#,
									ioen => 1, nahbm => 2, nahbs => 2)
				port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);
	io_ahb : ahbctrl       -- AHB arbiter/multiplexer
				generic map (defmast => 0, split => 1, 
									rrobin => 1, ioaddr => 16#100#,
									ioen => 1, nahbm => 1, nahbs => 5)
				port map (rstn, clkm, ahb1mi, ahb1mo, ahb1si, ahb1so);
	leon_mst : vcmst
		generic map(hindex => 0)
		port map(rstn, clkm, mst0_rx_ready, mst0_rx_ack, mst0_rx, mst0_tx_ready, mst0_tx_ack, mst0_tx, ahbmi, ahbmo(0));
	leon_cont: vcont
		generic map(mindex => 1, sindex => 0, cindex => 1, memmask => 16#500#, ioaddr => 16#600#, iomask => 16#ffe#, caddr => 16#70a#, cmask => 16#ffe#)
		port map(rstn, clkm, ahbmi, ahbmo(1), ahbsi, ahbso(0), ahbso(1), slv_rx_ready, slv_rx_ack, slv_rx, slv_tx_ready, slv_tx_ack, slv_tx);
	io_cont: vcont
		generic map(mindex => 0, sindex => 0, cindex => 1)
		port map(rstn, clkm, ahb1mi, ahb1mo(0), ahb1si, ahb1so(0), ahb1so(1), slv_tx_ready, slv_tx_ack, slv_tx, slv_rx_ready, slv_rx_ack, slv_rx);
	io_slv0: testreg
		generic map(hindex => 2, membar => 16#800#, rom => '1')
		port map(rstn, clkm, ahb1si, ahb1so(2));
	io_slv1: testreg
		generic map(hindex => 3, membar => 16#400#)
		port map(rstn, clkm, ahb1si, ahb1so(3));
	io_slv2: testreg
		generic map(hindex => 4, membar => 16#300#)
		port map(rstn, clkm, ahb1si, ahb1so(4));

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
	
	mst0_recv: process(clkm)
	begin
		if(clkm'event and clkm = '1') then
			if(mst0_tx_ready = '1') then
				mst0_tx_ack <= '1';
			else
				mst0_tx_ack <= '0';
			end if;
		end if;
	end process mst0_recv;
	
	mst0_proc: process
	begin
		wait for 140 ns;
		mst0_rx.len <= "010";
		mst0_rx.addr <= "0010";
		mst0_rx.flit(0)(15) <= '1';
		mst0_rx.flit(0)(14 downto 12) <= "010"; -- size
		mst0_rx.flit(0)(7 downto 5) <= "000"; -- burst
		mst0_rx.flit(0)(11 downto 8) <= "1110"; -- hprot
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(0)(2) <= '1';
		mst0_rx.flit(1) <= x"c0a00004";
		mst0_rx.flit(2) <= x"80000008";
		mst0_rx.flit(3) <= x"40000000";
		mst0_rx.flit(4) <= x"50000000";
		--wait until clkm'event and clkm = '1';
		mst0_rx_ready <= '1';
		wait until mst0_rx_ack = '1';
		wait until clkm'event and clkm = '1';
		mst0_rx <= noc_transfer_none;
		mst0_rx_ready <= '0';
		wait until clkm'event and clkm = '1';
		------------------------------------------
		mst0_rx.len <= "010";
		mst0_rx.addr <= "0010";
		mst0_rx.flit(0)(15) <= '1';
		mst0_rx.flit(0)(14 downto 12) <= "010"; -- size
		mst0_rx.flit(0)(7 downto 5) <= "000"; -- burst
		mst0_rx.flit(0)(11 downto 8) <= "1110"; -- hprot
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(1) <= x"c0a00000";--x"c0000024";
		mst0_rx.flit(2) <= x"00800000";
		mst0_rx.flit(3) <= x"70000000";
		mst0_rx.flit(4) <= x"80000000";
		mst0_rx_ready <= '1';
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
		mst0_rx.flit(0)(14 downto 12) <= "010";
		mst0_rx.flit(0)(7 downto 5) <= "000";
		mst0_rx.flit(0)(11 downto 8) <= "1110";
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(1) <= x"6aa2fff0";
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
		mst0_rx.flit(0)(14 downto 12) <= "010";
		mst0_rx.flit(0)(7 downto 5) <= "000";
		mst0_rx.flit(0)(11 downto 8) <= "1110";
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(1) <= x"6000fff0";
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
		mst0_rx.len <= "100";
		mst0_rx.addr <= "0010";
		mst0_rx.flit(0)(15) <= '1';
		mst0_rx.flit(0)(14 downto 13) <= "10";
		mst0_rx.flit(0)(14 downto 12) <= "010";
		mst0_rx.flit(0)(7 downto 5) <= "001";
		mst0_rx.flit(0)(11 downto 8) <= "1110";
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(1) <= x"a0000010";
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
		mst0_rx.len <= "010";
		mst0_rx.addr <= "0010";
		mst0_rx.flit(0)(15) <= '0';
		mst0_rx.flit(0)(14 downto 13) <= "10";
		mst0_rx.flit(0)(14 downto 12) <= "010";
		mst0_rx.flit(0)(7 downto 5) <= "000";
		mst0_rx.flit(0)(11 downto 8) <= "1110";
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(1) <= x"a0000010";
		mst0_rx.flit(2) <= x"00000000";
		mst0_rx.flit(3) <= x"00000000";
		mst0_rx.flit(4) <= x"00000000";
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

END;