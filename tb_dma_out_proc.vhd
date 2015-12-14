--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   22:58:00 12/08/2015
-- Design Name:   
-- Module Name:   C:/Users/Elvin/OneDrive/GitHub/Custom_Leon/lib/gaisler/custom/tb_dmab_in_proc.vhd
-- Project Name:  NoC
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: virtioc
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library gaisler;
use gaisler.custom.all;
library grlib;
use grlib.amba.all;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb_dmab_in_proc IS
END tb_dmab_in_proc;
 
ARCHITECTURE behavior OF tb_dmab_in_proc IS 
    
	--constant AHBDW : integer := 32;
	constant bsize : integer := 4;
	type dmai_buffer is array (0 to (2**bsize)-1) of ahb_dma_in_type;

	signal dmai_noc : ahb_dma_in_type;
	signal dmao_noc : ahb_dma_out_type;
	
	signal dmab_in : ahb_dma_in_type;
	signal wr_en, re_en, out_overflow, hwrite : std_logic;
	signal hwdata : std_logic_vector(AHBDW-1 downto 0);

   --Inputs
   signal rst : std_logic := '0';
   signal clk : std_logic := '0';
   signal ahbi_noc : std_logic := '0';

 	--Outputs
   signal ahbo_noc : std_logic;

   -- Clock period definitions
   constant clk_period : time := 20 ns;
 
BEGIN

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   write_proc: process
   begin		
      -- hold reset state for 100 ns.
		rst <= '0';
      wait for 100 ns;
		dmab_in <= dmai_none;
		rst <= '1';
		wait for 100 ns;
		wr_en <= '1';
		
		for I in 1 to 29 loop
			wait until rising_edge(clk);
			--if(clk = '1') then
				if(out_overflow = '0') then
					dmab_in.address(7 downto 0) <= conv_std_logic_vector(I,8);
					dmab_in.wdata(7 downto 0) <= conv_std_logic_vector(I,8);
					dmab_in.start <= '1';
					dmab_in.burst <= '1';
					dmab_in.write <= '1';
					dmab_in.busy <= '1';
					dmab_in.irq <= '0';
					dmab_in.size <= "010";
				--else
					--wait until out_overflow = '0';
				end if;
			--end if;
		end loop;
		wr_en <= '0';
      wait;
   end process;
	
	read_proc: process
	begin
		wait for 100 ns;
		for X in 0 to 3 loop
		wait for 100 ns;
			re_en <= '1';
			wait for 60 ns;
			re_en <= '0';
		end loop;
		re_en <= '1';
		wait;
	end process;
	
	dmab_in_proc : process(clk, rst)
		variable outbuffer : dmai_buffer;
		variable wr_pointer : unsigned(bsize downto 0);
		variable re_pointer : unsigned(bsize downto 0);
	begin
		-----------------------------------------------
		if(rst = '0') then
			dmai_noc <= dmai_none;
			outbuffer := (others => dmai_none);
			wr_pointer := (others => '0');
			re_pointer := (others => '0');
			hwdata <= (others => '0');
			hwrite <= '0';
			--wr_en <= '0';			
			out_overflow <= '0';
		-----------------------------------------------	
		elsif(clk'event and clk = '1') then
			if(re_pointer((bsize-1) downto 0) /= wr_pointer((bsize-1) downto 0) or wr_pointer(bsize) = '0') then
			-- filling buffer and incrementing write pointer
				if(wr_en = '1') then
					outbuffer(conv_integer(wr_pointer((bsize-1) downto 0))) := dmab_in;
					wr_pointer := wr_pointer + '1';
				end if;
			else
				out_overflow <= '1';
			end if;
			----------------------------------------------------------
			if((re_pointer((bsize-1) downto 0) /= wr_pointer((bsize-1) downto 0) or wr_pointer(bsize) = '1')) then 
			-- emptying buffer und incrementing read pointer
				if(re_en = '1') then ----------------------------------------- re_en needs to be removed later
				dmai_noc <= outbuffer(conv_integer(re_pointer)); dmai_noc.wdata <= hwdata;
				hwdata <= outbuffer(conv_integer(re_pointer)).wdata; hwrite <= outbuffer(conv_integer(re_pointer)).write;
				re_pointer := re_pointer + '1';
				out_overflow <= '0';
				if(re_pointer(bsize) = '1' and re_pointer(bsize) = '1') then
				-- read pointer at index 0 again
					wr_pointer(bsize) := '0';
					re_pointer(bsize) := '0';
				end if;
				end if;
			elsif(re_pointer((bsize-1) downto 0) = wr_pointer((bsize-1) downto 0) and wr_pointer(bsize) = '0' and hwrite = '1') then
			-- buffer underflow but a write must be completed
				dmai_noc.wdata <= hwdata;
				hwrite <= '0';
			end if;
		end if;
		-----------------------------------------------
	end process dmab_in_proc;

END;
