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
variable noc_rx_reg : noc_transfer_reg;
variable flit_index : integer range 2 to 4;
variable bstate : integer range 0 to 1; -- burst state
variable split : integer range 0 to 16;
variable fresp : std_logic;
--generate for split handling
--variable transfers : noc_transfer_reg is array 0 to (nahbmst-1)
begin
	if(res = '0') then
		ahbso <= ahbs_none;
		tslv := ahbs_none;
		noc_tx_reg := noc_transfer_none;
		noc_rx_reg := noc_transfer_none;
		requ_ready <= '0';
		requ <= noc_transfer_none;
		resp_ack <= '0';
		fresp := '0';
		bstate := 0; -- no bursts
		split := 16;
	elsif(clk'event and clk = '1') then
		if(requ_ack = '1') then requ_ready <= '0';
		end if;
		if(resp_ready = '0') then resp_ack <= '0';
		end if;
		---- AHB -----------------------------------------------------------
		rslv := ahbsi;
		if(rslv.hsel(hindex) = '1') then
			if(tslv.hresp = "00") then -- check in which response mode the slave is in
				---- HTRANS: NONSEQ ----
				if(rslv.htrans = "10") then
					-- check if incoming AHB request is an old one which can be served (valid length; ahb_response_header; split id)
					if(conv_integer(noc_rx_reg.len) > 1 and noc_rx_reg.flit(0)(31 downto 28) = "0011" and rslv.hmaster = noc_rx_reg.flit(0)(27 downto 24)) then
						-- it can only be a read request
						if(rslv.hwrite = '0') then
							tslv.hresp := "00";
							tslv.hrdata(31 downto 0) := noc_rx_reg.flit(1);
							if(noc_rx_reg.flit(0)(9 downto 7) = "000") then
								fresp := '0';
								noc_rx_reg := noc_transfer_none;
							end if;
						else
							noc_rx_reg := noc_transfer_none;
							tslv.hresp := "01";
							tslv.hready := '0';
						end if;
						split := 16; -- clear SPLIT
					-- new AHB request
					else
						-- Handle old AHB Burst first, before beginning new Burst
						if(bstate = 1) then
							noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
							noc_tx_reg.addr := conv_std_logic_vector(ioaddr,4);
							requ <= noc_tx_reg;
							requ_ready <= '1';
							tslv.hresp := "11"; -- initiate SPLIT for read prefetch from remote location
							tslv.hready := '0';
						-- Start new AHB Burst
						elsif(bstate = 0) then
							noc_tx_reg.flit(0)(27 downto 24) := rslv.hmaster;
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
									noc_tx_reg.addr := conv_std_logic_vector(ioaddr,4);
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
							bstate := 1; -- new burst started
						end if;
					end if;
				---- HTRANS: SEQ ----
				elsif(rslv.htrans = "11") then
					-- check if burst was started before
					if(bstate = 1) then
						-- continue caching HWDATA
						if(rslv.hwrite = '1') then
							if(flit_index < 5) then
								noc_tx_reg.flit(flit_index) := rslv.hwdata(31 downto 0);
								flit_index := flit_index + 1; ---------------------------------------- 5-Boundary?
							else
								-- full packet therefore transmit it
								noc_tx_reg.len := conv_std_logic_vector(5,3);
								noc_tx_reg.addr := conv_std_logic_vector(ioaddr,4);
								requ <= noc_tx_reg;
								requ_ready <= '1';
								flit_index := 2;
							end if;
						end if;
					---- Burst was never started; ERROR ----
					else
						tslv.hresp := "01";
						tslv.hready := '0';
					end if;
				---- HTRANS: IDLE ----
				elsif(rslv.htrans = "00") then
					-- Burst complete or Error handling complete?
					flit_index := 2;
				end if;
				---- End of HTRANS ----
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
				tslv.hready := '1';
			end if;
		---- HSEL inactive ----
		else
			if(tslv.hresp /= "00" and tslv.hready = '1') then
				tslv := ahbs_none;
			else
				tslv.hready := '1';
			end if;
			if(bstate = 1) then ----------- finish up request and send it!!!!
			end if;
			bstate := 0;
		end if;
		---- NoC-Response and SPLIT continuation -----------------------------------
		if(resp_ready = '1' and fresp = '0') then
			resp_ack <= '1';
			fresp := '1';
			if(conv_integer(resp.len) > 1) then
				noc_rx_reg := resp;
				split := conv_integer(noc_rx_reg.flit(0)(27 downto 24));
			else
				fresp := '0';
				split := 16;
			end if;
		end if;
		---- Set/Reset Split indicator ---------------------------------------------
		if(split < 16) then
			tslv.hsplit(split) := '1';
		else
			tslv.hsplit := x"0000";
		end if;
		----------------------------------------------------------------------------
		ahbso <= tslv;
	end if;
	---- Gaisler AHB Plug&Play status ---------------------------------------------
	ahbso.hconfig <= hconfig;
  	ahbso.hindex  <= hindex;
	
end process vcslv_proc;

end Behavioral;
