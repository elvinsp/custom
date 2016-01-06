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
use gaisler.uart.all;
use work.custom.all;
library grlib;
use grlib.amba.all;
use grlib.testlib.all;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb2_noc IS
END tb2_noc;
 
ARCHITECTURE noc_simple_transfer OF tb2_noc IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    

   --Inputs
   signal rstn : std_logic := '0';
   signal clkm : std_logic := '0';
	signal nic_irq : std_logic := '0';
	signal apbi  : apb_slv_in_type;
	signal apbo  : apb_slv_out_vector := (others => apb_none);
	signal vn_ahbsi : ahb_slv_in_type;
	signal vn_ahbso : ahb_slv_out_type;
   signal le_ahbsi, io_ahbsi : ahb_slv_in_type;
   signal le_ahbso, io_ahbso : ahb_slv_out_vector := (others => ahbs_none);
   signal le_ahbmi, io_ahbmi : ahb_mst_in_type;
   signal le_ahbmo, io_ahbmo : ahb_mst_out_vector := (others => ahbm_none);
	signal le_ctrl, io_ctrl  : ahbtb_ctrl_type;
	--signal le_ctrli : ahbtbm_le_ctrl_in_type;
	--signal le_ctrlo : ahbtbm_le_ctrl_out_type;
	signal u1i, dui : uart_in_type;
	signal u1o, duo : uart_out_type;

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: top_noc
	generic map (
    leon_hindex => 0,
    leon_haddr => 16#400#,
	 io_hindex => 0,
	 io_haddr => 16#600#,
    hmask => 16#fff#)
    port map (rstn, clkm, nic_irq, le_ahbsi, le_ahbso(0), vn_ahbsi, vn_ahbso);
	 
	vnic0 : vnic
	generic map(nic_hindex => 0)
	port map(rstn, clkm, nic_irq, io_ahbsi, io_ahbso(0), vn_ahbsi, vn_ahbso);
		  
	leon_ahb0 : ahbctrl       -- AHB arbiter/multiplexer
				generic map (defmast => 0, split => 0, 
									rrobin => 1, ioaddr => 16#800#,
									ioen => 1, nahbm => 1, nahbs => 16)
				port map (rstn, clkm, le_ahbmi, le_ahbmo, le_ahbsi, le_ahbso);	 
	io_ahb0 : ahbctrl       -- AHB arbiter/multiplexer
				generic map (defmast => 1, split => 0, 
									rrobin => 1, ioaddr => 16#800#,
									ioen => 1, nahbm => 1, nahbs => 16)
				port map (rstn, clkm, io_ahbmi, io_ahbmo, io_ahbsi, io_ahbso);	 

	leon_ahbtbm0 : ahbtbm
		generic map(hindex => 0) -- AMBA master index 0
		port map(rstn, clkm, le_ctrl.i, le_ctrl.o, le_ahbmi, le_ahbmo(0));
	io_ahbtbm0 : ahbtbm
		generic map(hindex => 1) -- AMBA master index 0
		port map(rstn, clkm, io_ctrl.i, io_ctrl.o, io_ahbmi, io_ahbmo(1));
		
	--apb0 : apbctrl            -- AHB/APB bridge
		--generic map (hindex => 1, haddr => 16#800#, nslaves => 8)
		--port map (rstn, clkm, io_ahbsi, io_ahbso(1), apbi, apbo );
		
	--uart1 : apbuart         -- UART 1
		--generic map (pindex => 1, paddr => 1,  pirq => 2, console => 0, fifosize => 8)
		--port map (rstn, clkm, apbi, apbo(1), u1i, u1o);
		
		--u1i.extclk <= '0';
		--u1i.ctsn <= '0';
		--rxd1_pad : inpad generic map (tech => padtech) port map (rxd1, u1i.rxd); 
		--txd1_pad : outpad generic map (tech => padtech) port map (txd1, u1o.txd);

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
		wait for 60 ns;
		rstn <= '1';
		wait;
	end process;
	
	leon_proc: process
	begin
		wait for 40 ns;
		-- Initialize the control signals
		ahbtbminit(le_ctrl);
		wait until clkm'event and clkm='1';
		ahbtbmidle(false, le_ctrl);
      wait for 200 ns;	
		ahbwrite(x"40000014", x"11111111", "10", 2, false , le_ctrl);
		wait until clkm'event and clkm='1';
		ahbwrite(x"40000010", x"10000040", "10", 2, false , le_ctrl);
		wait until clkm'event and clkm='1';
		ahbtbmidle(false, le_ctrl);
		wait until clkm'event and clkm='1';
		wait until clkm'event and clkm='1';
		ahbwrite(x"40000018", x"44444444", "10", 2, false , le_ctrl);
		wait until clkm'event and clkm='1';
		ahbwrite(x"40000010", x"10000040", "10", 2, false , le_ctrl);
		wait until clkm'event and clkm='1';
		ahbread(x"40000014", x"11111111", "10", 2, false , le_ctrl);
		wait until clkm'event and clkm='1';
		ahbread(x"40000010", x"10000000", "10", 2, false , le_ctrl);
		wait until clkm'event and clkm='1';
		--wait until clkm'event and clkm='1';
		ahbtbmidle(false, le_ctrl);
		wait for 100 ns;
		wait for 100 ns;
		-- Stop simulation
		ahbtbmdone(0, le_ctrl); 
      wait;
   end process;
	
	io_proc: process
	begin
		wait for 40 ns;
		-- Initialize the control signals
      ahbtbminit(io_ctrl);
      wait for 300 ns;	
		ahbwrite(x"60000014", x"11111111", "10", 2, false , io_ctrl);
		wait until clkm'event and clkm='1';
		ahbread(x"60000010", x"00000080", "10", 2, false , io_ctrl);
		wait until clkm'event and clkm='1';
		--wait until clkm'event and clkm='1';
		ahbtbmidle(false, io_ctrl);
		wait for 100 ns;
		wait for 100 ns;
		-- Stop simulation
		ahbtbmdone(0, io_ctrl); 
      wait;
   end process;

END;