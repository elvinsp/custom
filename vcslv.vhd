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
variable flit_index : integer;
variable bstate : integer range 0 to 1; -- burst status
variable split : integer range 0 to 16;
variable fresp, tx_ready, tx_flag : std_logic;
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
		tx_ready := '0'; -- transmit pending
		tx_flag := '0';
		bstate := 0; -- no bursts
		split := 16;
	elsif(clk'event and clk = '1') then
		-- TX Ready reset (1/2) --
		if(requ_ack = '1') then 
			tx_ready := '0';
			requ <= noc_transfer_none;
		end if;
		---- AHB -----------------------------------------------------------
		rslv := ahbsi;
		if(rslv.hsel(hindex) = '1') then
			if(tslv.hresp = "00" and tslv.hready = '1') then -- check in which response mode the slave is in
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
							bstate := 0;
						end if;
						split := 16; -- clear SPLIT
					-- new AHB request
					else
						-- new Burst has begun, finish up old Burst and start new one if it is a WRITE
						if(bstate = 1) then
							if(conv_integer(noc_tx_reg.len) > 1 and noc_tx_reg.flit(0)(15) = '1') then
								noc_tx_reg.flit(flit_index) := rslv.hwdata(31 downto 0);
								flit_index := flit_index + 1; ---- increase after use and before setting length (index starts at 0, length starts at 1)
								noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
								if(tx_flag = '0') then
									noc_tx_reg.addr := conv_std_logic_vector(1,4); ----- Debug
									requ <= noc_tx_reg;
									tx_ready := '1';
									tx_flag := '1';
									noc_tx_reg := noc_transfer_none;
									tslv.hresp := "00";
									---- save new Request ----
									noc_tx_reg.flit(0)(31 downto 28) := "0010"; ---- ahb_request_header
									noc_tx_reg.flit(0)(27 downto 24) := rslv.hmaster;
									noc_tx_reg.flit(0)(15) := rslv.hwrite;
									noc_tx_reg.flit(0)(14 downto 13) := rslv.htrans;
									noc_tx_reg.flit(0)(12 downto 10) := rslv.hsize;
									noc_tx_reg.flit(0)(9 downto 7) := rslv.hburst;
									noc_tx_reg.flit(0)(6 downto 3) := rslv.hprot;
									noc_tx_reg.flit(1) := rslv.haddr;
									flit_index := 2; ---- start new index at 2 (header and addr already used)
									noc_tx_reg.len := conv_std_logic_vector(2,3);
									noc_tx_reg.addr := conv_std_logic_vector(0,4); -------------------------------------- Replace Addr!!
								else
									tslv.hresp := "11";
									tslv.hready := '0';
									bstate := 0;
									------------------------------------------------------------------------ SPLIT Queue !!

								end if;
								---------------------------------- deal with new Burst !!!!!!
							end if;
						-- Start new AHB Burst and there is no pending Burst
						elsif(bstate = 0 and conv_integer(noc_tx_reg.len) < 1) then
							noc_tx_reg.flit(0)(31 downto 28) := "0010"; ---- ahb_request_header
							noc_tx_reg.flit(0)(27 downto 24) := rslv.hmaster;
							noc_tx_reg.flit(0)(15) := rslv.hwrite;
							noc_tx_reg.flit(0)(14 downto 13) := rslv.htrans;
							noc_tx_reg.flit(0)(12 downto 10) := rslv.hsize;
							noc_tx_reg.flit(0)(9 downto 7) := rslv.hburst;
							noc_tx_reg.flit(0)(6 downto 3) := rslv.hprot;
							noc_tx_reg.flit(1) := rslv.haddr;
							flit_index := 2; ---- start new index at 2 (header and addr already used)
							if(rslv.hwrite = '0') then
								-- Doesn't matter if hburst INCR/WARP/SINGLE all will be handled on remote interface
								noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
								noc_tx_reg.addr := conv_std_logic_vector(0,4); -------------------------------------- Replace Addr!!
								if(tx_flag = '0') then
									noc_tx_reg.addr := conv_std_logic_vector(2,4); ----- Debug
									requ <= noc_tx_reg;
									tx_ready := '1';
									tx_flag := '1';
									noc_tx_reg := noc_transfer_none;
								end if;
								tslv.hresp := "11"; -- initiate SPLIT for read prefetch from remote interface
								tslv.hready := '0';
								bstate := 0;
								------------------------------------------------------------------------ SPLIT Queue !!
							else
								noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
								noc_tx_reg.addr := conv_std_logic_vector(0,4); ---------------------------------- Replace Addr!!
							end if;
							bstate := 1; -- new burst started
						-- (bstate) Busy because a still pending Request
						else
							tslv.hresp := "11";
							tslv.hready := '0';
							bstate := 0;
							------------------------------------------------------------------------ SPLIT Queue !!
						end if;
					end if;
				---- HTRANS: SEQ ----
				elsif(rslv.htrans = "11") then
					-- check if burst was started before
					if(bstate = 1) then
						-- continue caching HWDATA
						if(rslv.hwrite = '1') then
							if(flit_index < 4) then
								noc_tx_reg.flit(flit_index) := rslv.hwdata(31 downto 0);
								flit_index := flit_index + 1; ---- increase after use and before setting length (index starts at 0, length starts at 1)
							elsif(flit_index = 4) then
								-- full packet therefore transmit it
								noc_tx_reg.len := conv_std_logic_vector(5,3);
								noc_tx_reg.addr := conv_std_logic_vector(0,4);
								noc_tx_reg.flit(flit_index) := rslv.hwdata(31 downto 0);
								if(tx_flag = '0') then
									noc_tx_reg.addr := conv_std_logic_vector(3,4); ----- Debug
									requ <= noc_tx_reg;
									tx_ready := '1';
									tx_flag := '1';
									noc_tx_reg := noc_transfer_none;
									noc_tx_reg.len := conv_std_logic_vector(2,3);
									noc_tx_reg.addr := conv_std_logic_vector(0,4); ---------------------------------- Replace Addr!!
									noc_tx_reg.flit(0)(31 downto 28) := "0010"; ---- ahb_request_header
									noc_tx_reg.flit(0)(27 downto 24) := rslv.hmaster;
									noc_tx_reg.flit(0)(15) := rslv.hwrite;
									noc_tx_reg.flit(0)(14 downto 13) := rslv.htrans;
									noc_tx_reg.flit(0)(12 downto 10) := rslv.hsize;
									noc_tx_reg.flit(0)(9 downto 7) := rslv.hburst;
									noc_tx_reg.flit(0)(6 downto 3) := rslv.hprot;
									noc_tx_reg.flit(1) := rslv.haddr;
									flit_index := 2; ---- start new index at 2 (header and addr used)
								else
									tslv.hresp := "11";
									tslv.hready := '0';
									bstate := 0;
									------------------------------------------------------------------------ SPLIT Queue !!
								end if;
								---- flit_index?
							end if;
						end if;
					---- Burst was never started; ERROR ----
					else
						tslv.hresp := "01";
						tslv.hready := '0';
						bstate := 0;
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
				--if(tx_ready = '0') then
					tslv.hready := '1';
				--end if;
			end if;
		---- HSEL inactive ----
		else
			--- handle last write ---------------------------------------------------------------------???
			if(tslv.hresp /= "00" and tslv.hready = '1') then
				tslv := ahbs_none;
			else
				tslv.hready := '1';
			end if;
			---- finish up last AHB Request -----------------------------------------------
			if(conv_integer(noc_tx_reg.len) > 1 and noc_tx_reg.flit(0)(15) = '1' and bstate = 1) then
				noc_tx_reg.flit(flit_index) := rslv.hwdata(31 downto 0);
				flit_index := flit_index + 1; ---- increase after use and before setting length (index starts at 0, length starts at 1)
				noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
			end if;
			---- send last AHB Request
			if(conv_integer(noc_tx_reg.len) > 1 and tx_flag = '0') then
				noc_tx_reg.addr := conv_std_logic_vector(4,4); ----- Debug
				requ <= noc_tx_reg; 
				tx_ready := '1';
				tx_flag := '1';
				noc_tx_reg := noc_transfer_none;
				flit_index := 2;
			end if;
			bstate := 0; --- next NONSEQ flit_index will be reset to 2
		end if;
		---- NoC-Response and SPLIT continuation -----------------------------------
		if(resp_ready = '1' and fresp = '0') then
			resp_ack <= '1';
			fresp := '1';
			if(conv_integer(resp.len) > 1) then
				noc_rx_reg := resp;
				split := conv_integer(noc_rx_reg.flit(0)(27 downto 24)); ------------------------------ SPLIT Queue !!
			else
				fresp := '0';
				split := 16;
			end if;
		end if;
		---- Set/Reset Split indicator --------------------------------------------------------- SPLIT Queue !!
		if(split < 16) then
			tslv.hsplit(split) := '1';
		else
			tslv.hsplit := x"0000";
		end if;
		---- TX Ready reset (2/2) --
		if(requ_ack = '1' and tx_ready = '0') then 
			tx_flag := '0';
		end if;
		---- Reset RX ACK ----
		if(resp_ready = '0') then 
			resp_ack <= '0';
		end if;
		----------------------------------------------------------------------------
		ahbso <= tslv;
		requ_ready <= tx_ready;
	end if;
	---- Gaisler AHB Plug&Play status ---------------------------------------------
	ahbso.hconfig <= hconfig;
  	ahbso.hindex  <= hindex;
	
end process vcslv_proc;

end Behavioral;
