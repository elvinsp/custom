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
use grlib.devices.all;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb3_ahbmst IS
END tb3_ahbmst;
 
ARCHITECTURE test_ahbmst OF tb3_ahbmst IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    

   --Inputs
   signal rstn : std_logic := '0';
   signal clkm : std_logic := '0';
   signal ahbsi : ahb_slv_in_type;
   signal ahbso : ahb_slv_out_vector := (others => ahbs_none);
   signal ahbmi : ahb_mst_in_type;
   signal ahbmo : ahb_mst_out_vector := (others => ahbm_none);
	signal dmai : ahb_dma_in_type := dmai_none;
   signal dmao : ahb_dma_out_type;
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
									ioen => 1, nahbm => 2, nahbs => 16)
				port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);	 

	ahbmst1 : ahbmst
		generic map (hindex => 1, hirq => 1, venid => VENDOR_GAISLER,
                 devid => GAISLER_LEON3, version => 0,
                 chprot => 3, incaddr => 0)
		port map(rstn, clkm, dmai, dmao, ahbmi, ahbmo(1));

   ahbtbm0 : ahbtbm
		generic map(hindex => 0, hirq => 0, venid => VENDOR_GAISLER,
                 devid => GAISLER_LEON3, version => 0,
                 chprot => 3, incaddr => 0) -- AMBA master index 0
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
		--wait for 60 ns;
		--rstn <= '1';
		wait;
	end process;
	
	ahb_proc: process
	begin
		--wait for 40 ns;
		-- Initialize the control signals
		ahbtbminit(ctrl); -- at 100ns
      wait for 100 ns;
		wait until clkm'event and clkm='1';
		-----------------------------------------------
		dmai.address <= x"40000014";
		dmai.wdata(31 downto 0) <= x"f1234000";
		dmai.burst <= '0';
		dmai.write <= '1';
		dmai.busy <= '0';
		dmai.irq <= '0';
		dmai.size <= "010";
		dmai.start <= '1';
		wait until clkm'event and clkm='1';
		wait until dmao.active = '1';
		------------------------------------------------
		dmai.address <= x"40000018";
		--dmai.wdata(31 downto 0) <= x"fffff000";
		dmai.burst <= '0';
		dmai.write <= '0';
		dmai.busy <= '0';
		dmai.irq <= '0';
		dmai.size <= "010";
		wait until clkm'event and clkm='1';
		dmai.wdata(31 downto 0) <= x"fffff000";
		wait until clkm'event and clkm='1';
		dmai.start <= '0';
		-------------------------------------------------
		wait for 200 ns;
		ahbread(x"40000014", x"f1234000", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbread(x"40000018", x"fffff000", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		ahbtbmidle(false, ctrl);
		wait for 200 ns;
		-------------------------------------------------
		dmai.address <= x"40000014";
		dmai.wdata(31 downto 0) <= x"aaaaaaaa";
		dmai.write <= '0';
		dmai.start <= '1';
		wait until dmao.active = '1';
		wait until clkm'event and clkm='1';
		--dmai.start <= '0';
		--wait until clkm'event and clkm='1';
		dmai.address <= x"40000004";
		dmai.wdata(31 downto 0) <= x"bbbbbbbb";
		dmai.write <= '0';
		dmai.start <= '1';
		wait until dmao.active = '1';
		wait until clkm'event and clkm='1';
		--dmai.start <= '0';
		wait until clkm'event and clkm='1';
		dmai.start <= '0';
		-- Stop simulation
		--ahbtbmdone(0, ctrl); 
      wait;
   end process;

END;