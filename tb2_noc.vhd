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
   signal ahbsi : ahb_slv_in_type;
   signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
   signal ahbmi : ahb_mst_in_type;
   signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);
	signal ctrl  : ahbtb_ctrl_type;
	--signal ctrli : ahbtbm_ctrl_in_type;
	--signal ctrlo : ahbtbm_ctrl_out_type;

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: top_noc
	generic map (
    hindex => 0,
    haddr => 16#400#,
    hmask => 16#fff#)
    port map (rstn, clkm, ahbsi, ahbso(0));
		  
	ahb0 : ahbctrl       -- AHB arbiter/multiplexer
				generic map (defmast => 0, split => 0, 
									rrobin => 1, ioaddr => 16#800#,
									ioen => 1, nahbm => 1, nahbs => 16)
				port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);	 

	ahbtbm0 : ahbtbm
		generic map(hindex => 0) -- AMBA master index 0
		port map(rstn, clkm, ctrl.i, ctrl.o, ahbmi, ahbmo(0));

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
	
	ahb_proc: process
	begin
		wait for 40 ns;
		-- Initialize the control signals
		ahbtbminit(ctrl);
      wait for 100 ns;	
		ahbwrite(x"40000014", x"11111111", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbwrite(x"40000018", x"22222222", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbwrite(x"4000001c", x"44444444", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbwrite(x"40000020", x"88888888", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbwrite(x"40000024", x"aaaaaaaa", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbwrite(x"40000010", x"00000040", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbread(x"40000010", x"00000040", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		--wait until clkm'event and clkm='1';
		ahbtbmidle(false, ctrl);
		wait for 100 ns;
		ahbread(x"40000034", x"11111111", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbread(x"40000038", x"22222222", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbread(x"4000003c", x"44444444", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbread(x"40000040", x"88888888", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbread(x"40000044", x"aaaaaaaa", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbread(x"40000010", x"00000040", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbtbmidle(false, ctrl);
		wait for 100 ns;
		-- Stop simulation
		ahbtbmdone(0, ctrl); 
      wait;
   end process;

END;