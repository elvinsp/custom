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

-- typedefs
type flits is array (0 to 4) of std_logic_vector(31 downto 0);
type noc_transfer_reg is record
	state : std_logic_vector(31 downto 0);
	flit :  flits;
end record;

-- constants
constant flit_none : flits := ((others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'));
constant noc_transfer_none : noc_transfer_reg := ((others => '0'), flit_none);

-- signals
signal noc_rx : noc_transfer_reg; -- data handover register from NI-AHB-Interface to processing
signal noc_rx_ready, noc_rx_ack : std_logic; -- handshake signals for data handover

begin

nic_inf: process(clk, res)
variable tnic : ahb_slv_in_type;
variable rnic : ahb_slv_out_type;
variable noc_reg : noc_transfer_reg;
variable basei : std_logic_vector(31 downto 0);
variable rw, start : std_logic;
variable state : integer range 0 to 7;
variable flit_index : integer range 0 to 4;
begin
	if(res = '0') then
		noc_rx <= noc_transfer_none;
		noc_rx_ready <= '0';
		noc_reg := noc_transfer_none;
		tnic := ahbs_in_none;
		rnic := ahbs_none;
		basei := x"60000070"; -- will be set to x"60000030" immediately
		state := 0;
		flit_index := 0;
	elsif(clk'event and clk = '1') then
		rnic := nico;
		if(nic_irq = '1') then
			if(rnic.hresp = "00" and rnic.hready = '1') then -- Slave OKAY Response
				tnic.hsel(nic_hindex) := '1';
				tnic.htrans := "10";
				tnic.hsize := "010";
				if(state = 0 or state = 7) then
					-- set next RX Buffer
					if(basei = x"60000030") then basei := x"60000050";
					elsif(basei = x"60000050") then basei := x"60000070";
					elsif(basei = x"60000070") then basei := x"60000030"; -- first case after reset
					end if;
					tnic.hwrite := '0';
					tnic.haddr := basei; -- start address for new rx buffer sequence
					if(state = 7) then
						noc_reg.flit(flit_index) := rnic.hrdata(31 downto 0); -- !!!!!!
						noc_rx <= noc_reg;
						noc_rx_ready <= '1';
						----
					end if;
					tnic.hwdata(31 downto 0) := x"00000000"; -- reset rx buffer from previous sequence if there was one			
					state := 1;
					flit_index := 0;
				elsif(state = 1) then
					tnic.hwrite := '0';
					tnic.haddr := basei + x"00000004"; -- Request 1st Flit
					state := 2;
				elsif(state = 2) then
					tnic.hwrite := '0';
					tnic.haddr := basei + x"00000008"; -- Request 2nd Flit
					noc_reg.state := rnic.hrdata(31 downto 0); -- Receive NoC RX State; Determine Flit amount!
					state := 3;
				elsif(state = 3) then
					tnic.hwrite := '0';
					tnic.haddr := basei + x"0000000c"; -- Request 3rd Flit
					noc_reg.flit(flit_index) := rnic.hrdata(31 downto 0);
					flit_index := flit_index + 1;
					state := 4;
				elsif(state = 4) then
					tnic.hwrite := '0';
					tnic.haddr := basei + x"00000010"; -- Request 4th Flit
					noc_reg.flit(flit_index) := rnic.hrdata(31 downto 0); -- ahb_header
					flit_index := flit_index + 1;
					state := 5;
				elsif(state = 5) then
					tnic.hwrite := '1';
					tnic.haddr := basei + x"00000014"; -- Request 5th Flit
					noc_reg.flit(flit_index) := rnic.hrdata(31 downto 0);	
					flit_index := flit_index + 1;
					state := 6; -- start in next Buffer
				elsif(state = 6) then
					tnic.hwrite := '1';
					tnic.haddr := basei; -- Select NoC RX State Register to Set Acknowledge
					noc_reg.flit(flit_index) := rnic.hrdata(31 downto 0);
					flit_index := flit_index + 1;
					state := 7; -- start in next Buffer
				end if;
			elsif(rnic.hresp = "01") then
			end if;
		else
			tnic := ahbs_in_none;
			state := 0;
		end if;
		if(noc_rx_ack = '1') then -- complete noc_rx handshake
			noc_rx_ready <= '0';
		end if;
	nici <= tnic;
	end if;	
end process nic_inf;

end Behavioral;

