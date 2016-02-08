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
	signal mst_tx, mst_rx : noc_transfer_reg := noc_transfer_none;
	signal slv_tx, slv_rx : noc_transfer_reg := noc_transfer_none;
	signal mst_tx_ready, mst_tx_ack, mst_rx_ready, mst_rx_ack : std_logic := '0';
	signal slv_tx_ready, slv_tx_ack, slv_rx_ready, slv_rx_ack : std_logic := '0';

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
BEGIN

	-- Instantiate the Unit Under Test (UUT)
   slv0: vcslv
		generic map(hindex => 0)
		port map(rstn, clkm, slv_tx_ready, slv_tx_ack, slv_tx, slv_rx_ready, slv_rx_ack, slv_rx, ahbsi, ahbso(0));
		  
	ahb0 : ahbctrl       -- AHB arbiter/multiplexer
				generic map (defmast => 0, split => 1, 
									rrobin => 1, ioaddr => 16#800#,
									ioen => 1, nahbm => 3, nahbs => 1)
				port map (rstn, clkm, ahbmi, ahbmo, ahbsi, ahbso);	 

   ahbtbm0 : ahbtbm
		generic map(hindex => 1, hirq => 0, venid => VENDOR_GAISLER,
                 devid => GAISLER_LEON3, version => 0,
                 chprot => 3, incaddr => 0) -- AMBA master index 0
		port map(rstn, clkm, ctrl.i, ctrl.o, ahbmi, ahbmo(1));
	
	mst1 : vcmst
		generic map(hindex => 2)
		port map(rstn, clkm, mst_rx_ready, mst_rx_ack, mst_tx, mst_tx_ready, mst_tx_ack, mst_tx, ahbmi, ahbmo(2));
		
	ahbmo(0) <= ahbm_none;

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
	variable busy : std_logic;
	begin
		if(rstn = '0') then
			busy := '0';
			slv_tx_ack <= '0';
			slv_rx_ready <= '0';
			slv_rx <= noc_transfer_none;
			bnoc := noc_transfer_none;
		elsif(clkm'event and clkm = '1') then
			if(slv_tx_ready = '0') then 
				slv_tx_ack <= '0';
				busy := '0';
			end if;
			if(slv_rx_ack = '1') then slv_rx_ready <= '0';
			end if;
			if(slv_tx_ready = '1' and busy = '0') then
				if(conv_integer(slv_tx.len) > 1) then
					busy := '1';
					bnoc := slv_tx;
				end if;
				slv_tx_ack <= '1';
			end if;
			-- respond to read request
			if(bnoc.len /= "000" and bnoc.flit(0)(15) = '0' and bnoc.flit(0)(9 downto 7) = "000") then
				bnoc.flit(1) := x"12345678";
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
		wait until clkm'event and clkm='1';
		ahbread(x"40000014", x"f1234000", "10", 2, false , ctrl);
		wait until clkm'event and clkm='1';
		--ahbread(x"40000018", x"fffff000", "10", 2, false , ctrl);
		--wait until clkm'event and clkm='1';
		ahbtbmidle(false, ctrl);
		--wait for 200 ns;
		-------------------------------------------------
		-- Stop simulation
		--ahbtbmdone(0, ctrl); 
      wait;
   end process;

END;