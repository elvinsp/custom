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
 
ENTITY tb4_vctest IS
END tb4_vctest;
 
ARCHITECTURE test_ahbmst OF tb4_vctest IS 
 
   --Inputs
   signal rstn : std_logic := '0';
   signal clkm : std_logic := '0';
   signal ahb0si : ahb_slv_in_type;
   signal ahb0so : ahb_slv_out_vector := (others => ahbs_none);
   signal ahb0mi : ahb_mst_in_type;
   signal ahb0mo : ahb_mst_out_vector := (others => ahbm_none);
	signal ahb1si : ahb_slv_in_type;
   signal ahb1so : ahb_slv_out_vector := (others => ahbs_none);
   signal ahb1mi : ahb_mst_in_type;
   signal ahb1mo : ahb_mst_out_vector := (others => ahbm_none);
	--signal ctrli : ahbtbm_ctrl_in_type;
	--signal ctrlo : ahbtbm_ctrl_out_type;
	signal mst0_tx, mst0_rx, slv_rx, slv_tx : noc_transfer_reg := noc_transfer_none;
	signal mst0_tx_ready, mst0_tx_ack, mst0_rx_ready, mst0_rx_ack : std_logic := '0';
	signal slv_rx_ready, slv_rx_ack, slv_tx_ready, slv_tx_ack : std_logic := '0';

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
BEGIN

	-- Instantiate the Unit Under Test (UUT)
		  
	leon_ahb0 : ahbctrl       -- AHB arbiter/multiplexer
				generic map (defmast => 0, split => 1, 
									rrobin => 1, ioaddr => 16#800#,
									ioen => 1, nahbm => 1, nahbs => 1)
				port map (rstn, clkm, ahb0mi, ahb0mo, ahb0si, ahb0so);
	leon_mst0 : vcmst
		generic map(hindex => 0)
		port map(rstn, clkm, mst0_rx_ready, mst0_rx_ack, mst0_rx, mst0_tx_ready, mst0_tx_ack, mst0_tx, ahb0mi, ahb0mo(0));
	leon_slv0: vcslv
		generic map(hindex => 0, membar => 16#500#)
		port map(rstn, clkm, '0', slv_tx_ready, slv_tx_ack, slv_tx, slv_rx_ready, slv_rx_ack, slv_rx, ahb0si, ahb0so(0));
	
	io_ahb1 : ahbctrl       -- AHB arbiter/multiplexer
				generic map (defmast => 0, split => 1, 
									rrobin => 1, ioaddr => 16#800#,
									ioen => 1, nahbm => 1, nahbs => 1)
				port map (rstn, clkm, ahb1mi, ahb1mo, ahb1si, ahb1so);	
	io_mst1 : vcmst
		generic map(hindex => 0)
		port map(rstn, clkm, slv_tx_ready, slv_tx_ack, slv_tx, slv_rx_ready, slv_rx_ack, slv_rx, ahb1mi, ahb1mo(0));
	io_slv1: testreg
		generic map(hindex => 0, membar => 16#500#)
		port map(rstn, clkm, ahb1si, ahb1so(0));

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
		mst0_rx.len <= "101";
		mst0_rx.addr <= "0010";
		mst0_rx.flit(0)(15) <= '1';
		mst0_rx.flit(0)(14 downto 12) <= "010"; -- size
		mst0_rx.flit(0)(7 downto 5) <= "001"; -- burst
		mst0_rx.flit(0)(11 downto 8) <= "1110"; -- hprot
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(1) <= x"50000014";
		mst0_rx.flit(2) <= x"12345678";
		mst0_rx.flit(3) <= x"9abcdef0";
		mst0_rx.flit(4) <= x"dead0000";
		mst0_rx.flit(0)(2) <= '1';
		wait until clkm'event and clkm = '1';
		mst0_rx_ready <= '1';
		wait until mst0_rx_ack = '1';
		wait until clkm'event and clkm = '1';
		--mst0_rx <= noc_transfer_none;
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
		mst0_rx.flit(1) <= x"50000010";
		mst0_rx.flit(2) <= x"11111111";
		mst0_rx.flit(3) <= x"22222222";
		mst0_rx.flit(4) <= x"44444444";
		mst0_rx_ready <= '1';
		wait until clkm'event and clkm = '1';
		wait until mst0_rx_ack = '1';
		wait until clkm'event and clkm = '1';
		--mst0_rx <= noc_transfer_none;
		mst0_rx_ready <= '0';
		wait until clkm'event and clkm = '1';
		------------------------------------------
		mst0_rx.len <= "010";
		mst0_rx.addr <= "0010";
		mst0_rx.flit(0)(15) <= '0';
		mst0_rx.flit(0)(14 downto 13) <= "10";
		mst0_rx.flit(0)(14 downto 12) <= "010";
		mst0_rx.flit(0)(7 downto 5) <= "001";
		mst0_rx.flit(0)(11 downto 8) <= "1110";
		mst0_rx.flit(0)(31 downto 28) <= "0010";
		mst0_rx.flit(1) <= x"50000010";
		mst0_rx.flit(2) <= x"11111111";
		mst0_rx.flit(3) <= x"22222222";
		mst0_rx.flit(4) <= x"44444444";
		mst0_rx_ready <= '1';
		wait until clkm'event and clkm = '1';
		wait until mst0_rx_ack = '1';
		wait until clkm'event and clkm = '1';
		--mst0_rx <= noc_transfer_none;
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
		mst0_rx.flit(1) <= x"50000010";
		mst0_rx.flit(2) <= x"00000000";
		mst0_rx.flit(3) <= x"00000000";
		mst0_rx.flit(4) <= x"00000000";
		mst0_rx_ready <= '1';
		wait until clkm'event and clkm = '1';
		wait until mst0_rx_ack = '1';
		wait until clkm'event and clkm = '1';
		--mst0_rx <= noc_transfer_none;
		mst0_rx_ready <= '0';
		wait until clkm'event and clkm = '1';
		------------------------------------------
		wait;
	end process;

END;