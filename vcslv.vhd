----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    01:40:16 02/07/2016 
-- Design Name: 
-- Module Name:    vcslv - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
library gaisler;
use gaisler.ahbtbp.all;
use work.custom.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vcslv is
    generic( hindex : integer := 0;
				 nahbmst : integer := 1;
				 memaddr : integer range 0 to 16 := 16;
				 ioaddr : integer range 0 to 16 := 16);
    Port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  requ_ready : out std_logic;
			  requ_ack : in std_logic;
			  requ : out noc_transfer_reg;
			  resp_ready : in std_logic;
			  resp_ack : out std_logic;
			  resp : in noc_transfer_reg;
			  ahbsi : in ahb_slv_in_type;
			  ahbso : out ahb_slv_out_type);
end vcslv;

architecture Behavioral of vcslv is
constant hconfig : ahb_config_type := (
  0 => ahb_device_reg ( 16#01#, 16#020#, 0, 0, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
  4 => ahb_membar(16#400#, '0', '0', 16#fff#), -- ahb_membar(memaddr, '0', '0', memmask), others => X"00000000");
  others => zero32);
begin

vcslv_proc: process(clk, res)
variable rslv : ahb_slv_in_type;
variable tslv : ahb_slv_out_type;
variable noc_tx_reg : noc_transfer_reg;
variable flit_index : integer range 2 to 4;
variable state : integer range 0 to 1;
--generate for split handling
--variable transfers : noc_transfer_reg is array 0 to (nahbmst-1)
begin
	if(res = '0') then
		ahbso <= ahbs_none;
		tslv := ahbs_none;
		noc_tx_reg := noc_transfer_none;
		state := 0;
	elsif(clk'event and clk = '1') then
		rslv := ahbsi;
		if(rslv.hsel(hindex) = '1') then
			if(tslv.hresp = "00") then -- check in which response mode the slave is in
				if(rslv.htrans = "10") then
					-- NONSEQ: Start new transmission
					if(state = 0) then
						noc_tx_reg.flit(0)(15) := rslv.hwrite;
						noc_tx_reg.flit(0)(14 downto 13) := rslv.htrans;
						noc_tx_reg.flit(0)(12 downto 10) := rslv.hsize;
						noc_tx_reg.flit(0)(9 downto 7) := rslv.hburst;
						noc_tx_reg.flit(0)(6 downto 3) := rslv.hprot;
						noc_tx_reg.flit(1) := rslv.haddr;
						if(rslv.hwrite = '1') then
							if(rslv.hburst = "000") then -- SINGLE
								noc_tx_reg.len := conv_std_logic_vector(2,3);
								noc_tx_reg.addr := conv_std_logic_vector(ioaddr,4);
								requ <= noc_tx_reg;
								requ_ready <= '1';
								tslv.hresp := "00";
							else -- INCR/WRAP
								
							end if;
						else
							-- Doesn't matter if hburst INCR/WARP/SINGLE all will be handle on remote master inf
							noc_tx_reg.len := conv_std_logic_vector(2,3);
							noc_tx_reg.addr := conv_std_logic_vector(ioaddr,4);
							requ <= noc_tx_reg;
							requ_ready <= '1';
							tslv.hresp := "11"; -- initiate SPLIT for read prefetch from remote location
							tslv.hready := '0';
						end if;
						state := 1;
					-- NONSEQ: Handle old transmission first, before beginning new one
					elsif(state = 1) then
						noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
						noc_tx_reg.addr := conv_std_logic_vector(ioaddr,4);
						requ <= noc_tx_reg;
						requ_ready <= '1';
						tslv.hresp := "11"; -- initiate SPLIT for read prefetch from remote location
						tslv.hready := '0';
					end if;
				elsif(rslv.htrans = "11") then
					-- SEQ continue transmission for write
					
					if(rslv.hwrite = '1') then
						if(flit_index < 5) then
							noc_tx_reg.flit(flit_index) := rslv.hwdata(31 downto 0);
							flit_index := flit_index + 1;
						else
							-- full packet therefore transmit it
							noc_tx_reg.len := conv_std_logic_vector(5,3);
							noc_tx_reg.addr := conv_std_logic_vector(ioaddr,4);
							requ <= noc_tx_reg;
							requ_ready <= '1';
							flit_index := 2;
						end if;
					end if;
				else
					flit_index := 2;
				end if;
			---- ERROR/SPLIT Handling(3/3) -----------------------------------------
			elsif(tslv.hresp /= "00" and tslv.hready = '1') then
				-- 2nd cycle of two-cycle response according to AMBA Spec (Rev 2.0) Chapter 3.9.3
				if(rslv.htrans = "00") then
					tslv.hresp := "00";
				else
					tslv.hready := '0';
				end if;
			---- ERROR/SPLIT Handling(2/3) -----------------------------------------
			else
				tslv.hready := '0';
			end if;
		else -- if(rslv.hsel(hindex) = '1')
			tslv := ahbs_none;
			state := 0;
			if(state = 1) then
			end if;
		end if;
		ahbso <= tslv;
	end if;
	-- LEON Side AHB Slave
	ahbso.hconfig <= hconfig;
  	ahbso.hindex  <= hindex;
end process vcslv_proc;

end Behavioral;

