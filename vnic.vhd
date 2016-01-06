----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:26:53 12/27/2015 
-- Design Name: 
-- Module Name:    vnic - Behavioral 
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
--use ieee.std_logic_unsigned.all;
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

entity vnic is
	 generic (nic_hindex : integer := 0);
    port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  nic_irq : in std_logic;
			  --msti : in  ahb_mst_in_type;
			  --msto : out ahb_mst_out_type;
			  slvi : in ahb_slv_in_type;
			  slvo : out ahb_slv_out_type;
			  nico : in ahb_slv_out_type;
			  nici : out ahb_slv_in_type);
end vnic;

architecture Behavioral of vnic is
--signal start : std_logic;
signal ahb_rx_flit : noc_flit_ahb;
begin

nic_inf: process(clk, res)
variable tnic : ahb_slv_in_type;
variable rnic : ahb_slv_out_type;
variable ahb_flit : noc_flit_ahb;
variable basei : std_logic_vector(31 downto 0);
variable noc_rx : std_logic_vector(31 downto 0);
variable rw, start : std_logic;
variable state : integer range 0 to 7;
begin
	if(res = '0') then
		ahb_rx_flit <= noc_flit_ahb_none;
		ahb_flit := noc_flit_ahb_none;
		tnic := ahbs_in_none;
		rnic := ahbs_none;
		basei := x"60000030";
		noc_rx := x"00000000";
		state := 0;
	elsif(clk'event and clk = '1') then
		rnic := nico;
		if(nic_irq = '1') then
			if(rnic.hresp = "00" and rnic.hready = '1') then -- Slave OKAY Response
				tnic.hsel(nic_hindex) := '1';
				tnic.htrans := "10";
				tnic.hsize := "010";
				if(state = 0) then
					tnic.hwrite := '0';
					tnic.haddr := basei;
					--noc_rx(7) := '0';
					tnic.hwdata(31 downto 0) := x"00000000"; -- reset rx buffer in 2nd round				
					state := 1;
				elsif(state = 1) then
					tnic.hwrite := '0';
					tnic.haddr := basei + x"00000004"; -- vio_header
					noc_rx := rnic.hrdata(31 downto 0);
					state := 2;
				elsif(state = 2) then
					tnic.hwrite := '0';
					tnic.haddr := basei + x"00000008"; -- ahb_header
					ahb_flit.vio_header := rnic.hrdata(31 downto 0); -- vio_header
					state := 3;
				elsif(state = 3) then
					tnic.hwrite := '0';
					tnic.haddr := basei + x"0000000c"; -- ahb_haddr
					ahb_flit.ahb_header := rnic.hrdata(31 downto 0); -- ahb_header
					state := 4;
				elsif(state = 4) then
					tnic.hwrite := '0';
					tnic.haddr := basei  + x"00000010"; -- ahb_hdata
					ahb_flit.ahb_haddr := rnic.hrdata(31 downto 0); -- ahb_haddr
					state := 5;
				elsif(state = 5) then
					tnic.hwrite := '1';
					tnic.haddr := basei; -- reset rx buffer
					ahb_flit.ahb_hdata := rnic.hrdata(31 downto 0); -- ahb_hdata
					ahb_rx_flit <= ahb_flit;
					state := 0; -- start in next Buffer
					-- set next RX Buffer
					if(basei = x"60000030") then basei := x"60000050";
					elsif(basei = x"60000050") then basei := x"60000070";
					elsif(basei = x"60000070") then basei := x"60000030";
					end if;
				end if;
			elsif(rnic.hresp = "01") then
			end if;
		else
			tnic := ahbs_in_none;
			state := 0;
		end if;
	nici <= tnic;
	end if;	
end process nic_inf;

end Behavioral;

