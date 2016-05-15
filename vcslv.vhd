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
use gaisler.custom.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vcslv is
    generic( hindex : integer := 0;
				 memaddr : integer := 16#600#;
				 memmask : integer := 16#fff#;
				 ioaddr : integer := 16#800#;
				 iomask : integer := 16#fff#;
				 mindex : integer := 16);
    Port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  acwr : in std_logic;
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
  0 => ahb_device_reg ( 16#01#, 16#01B#, 0, 0, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
  4 => ahb_membar(ioaddr, '0', '0', iomask), -- ahb_memaddr(memaddr, '0', '0', memmask), others => X"00000000");
  --5 => ahb_membar(memaddr, '0', '0', memmask),
  --5 => ahb_iobar(16#500#, 16#f00#),
  others => zero32);
  
type reg16 is array (0 to 15) of std_logic_vector(3 downto 0);

begin

vcslv_proc: process(clk, res)
variable rslv : ahb_slv_in_type;
variable tslv : ahb_slv_out_type;
variable noc_tx_reg : noc_transfer_reg;
variable noc_rx_reg : noc_transfer_reg;
variable flit_index : integer;
variable bstate : integer range 0 to 1; -- burst status
variable split : integer range 0 to 16;
variable fresp, tx_r, tready : std_logic;
variable split_reg : reg16;
variable sread : std_logic_vector(3 downto 0);
variable swrite : std_logic_vector(4 downto 0);
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
		tx_r := '0'; -- transmit pending
		tready := '0';
		bstate := 0; -- no bursts
		split := 16;
		split_reg := (others => (others => '0'));
		sread := "1111";
		swrite := "01111";
	elsif(clk'event and clk = '1') then
		-- TX Ready reset (1/2) --
		if(requ_ack = '1') then 
			tx_r := '0';
			--requ <= noc_transfer_none;
		end if;
		---- AHB -----------------------------------------------------------
		rslv := ahbsi;
		if(rslv.hsel(hindex) = '1') then
			if(tslv.hresp = "00" and tslv.hready = '1') then -- check in which response mode the slave is in
				if(conv_integer(rslv.hmaster) /= mindex) then -- prevent controller ahb loops
					if(conv_integer(rslv.hmaster) = conv_integer(split_reg(conv_integer(sread))) 
												and ((swrite(4) = '0' and conv_integer(sread) < conv_integer(swrite(3 downto 0))) 
												or (swrite(4) = '1' and conv_integer(sread) >= conv_integer(swrite(3 downto 0))))) then
						sread := sread + '1';
						if(sread = "0000") then
							swrite(4) := '0';
						end if;
						tslv.hsplit := (others => '0');
						split := 16; -- split has been resolved, clear HSPLIT
					end if;
					---- HTRANS: NONSEQ ----
					if(rslv.htrans = "10") then
						-- check if incoming AHB response is an old one which can be served (valid length; ahb_response_header; split id)
						if(conv_integer(noc_rx_reg.len) > 1 and rslv.hmaster = noc_rx_reg.flit(0)(27 downto 24)) then
							-- it can only be a read request
							if(rslv.hwrite = '0') then -- redo if write confirm
								if(noc_rx_reg.flit(1) = x"ffffffff" and noc_rx_reg.flit(0)(1 downto 0) = "01") then
									tslv.hresp := "01";
									tslv.hready := '0';
									fresp := '0';
									noc_rx_reg := noc_transfer_none;
								else
									tslv.hresp := "00";
									tslv.hrdata(31 downto 0) := noc_rx_reg.flit(1);
									flit_index := 2;
									if(noc_rx_reg.flit(0)(7 downto 5) = "000") then
										fresp := '0';
										noc_rx_reg := noc_transfer_none;
									else
										bstate := 1; -- go into burst mode
									end if;
								end if;
							elsif(noc_rx_reg.flit(0)(2) = '1' and noc_rx_reg.flit(0)(1 downto 0) = "00") then
								--if(noc_rx_reg.flit(0)(1 downto 0) = "00") then -- dead code covered by elsif above
									tslv.hresp := "00";
									fresp := '0';
									noc_rx_reg := noc_transfer_none;
									---- start new transmission for next after burst
									if(rslv.hburst /= "000") then
										flit_index := 1; ---- start new index at 2 (header and addr already used)
										bstate := 1;
										noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
										noc_tx_reg.flit(0)(31 downto 28) := "0010"; ---- ahb_request_header
										noc_tx_reg.flit(0)(27 downto 24) := rslv.hmaster;
										noc_tx_reg.flit(0)(15) := rslv.hwrite;
										noc_tx_reg.flit(0)(14 downto 12) := rslv.hsize;
										noc_tx_reg.flit(0)(7 downto 5) := "000"; -- SINGLE
										noc_tx_reg.flit(0)(11 downto 8) := rslv.hprot;
										if(acwr = '0') then
											noc_tx_reg.flit(0)(2) := '1';
										end if;
										flit_index := flit_index + 1;
									end if;
								--else -- unused code
								--	tslv.hresp := "01";
								--	tslv.hready := '0';
								--end if;
								-- line below does the thing
							else
							-- internal error of slave
								noc_rx_reg := noc_transfer_none;
								tslv.hresp := "01";
								tslv.hready := '0';
								fresp := '0';
								bstate := 0;
							end if;
							tslv.hsplit := (others => '0');
							split := 16; -- clear SPLIT
						-- new AHB request
						else
							-- new Burst has begun, finish up old Burst and start new one
							if(bstate = 1) then
								if(conv_integer(noc_tx_reg.len) > 1 and noc_tx_reg.flit(0)(15) = '1') then
								--------------------------------------------------------------------------------------acwr
									noc_tx_reg.flit(flit_index) := rslv.hwdata(31 downto 0);
									flit_index := flit_index + 1; ---- increase after use and before setting length (index starts at 0, length starts at 1)
									noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
									if(tready = '0') then
										-- send off old ahb request and start new one
										requ <= noc_tx_reg;
										tx_r := '1';
										tready := '1';
										noc_tx_reg := noc_transfer_none;
										tslv.hresp := "00";
										---- save new Request ----
										noc_tx_reg.flit(0)(31 downto 28) := "0010"; ---- ahb_request_header
										noc_tx_reg.flit(0)(27 downto 24) := rslv.hmaster;
										noc_tx_reg.flit(0)(15) := rslv.hwrite;
										noc_tx_reg.flit(0)(14 downto 12) := rslv.hsize;
										if(rslv.hburst /= "000") then
											noc_tx_reg.flit(0)(7 downto 5) := "001"; -- INCR
										else
											noc_tx_reg.flit(0)(7 downto 5) := "000"; -- SINGLE
										end if;
										noc_tx_reg.flit(0)(11 downto 8) := rslv.hprot;
										noc_tx_reg.flit(1) := rslv.haddr;
										flit_index := 2; ---- start new index at 2 (header and addr already used)
										noc_tx_reg.len := conv_std_logic_vector(2,3);
										noc_tx_reg.addr := conv_std_logic_vector(0,4); -------------------------------------- Replace Addr!!
									else
										--- don't start new burst until old one is send off
										split_reg(conv_integer(swrite)) := rslv.hmaster;
										swrite := swrite + '1';
										tslv.hresp := "11";
										tslv.hready := '0';
										bstate := 0;
									end if;
									---------------------------------- deal with new Burst !!!!!!
								end if;
							-- Start new AHB Burst and there is no pending Burst
							elsif(bstate = 0 and conv_integer(noc_tx_reg.len) < 1) then
								noc_tx_reg.flit(0)(31 downto 28) := "0010"; ---- ahb_request_header
								noc_tx_reg.flit(0)(27 downto 24) := rslv.hmaster;
								noc_tx_reg.flit(0)(15) := rslv.hwrite;
								noc_tx_reg.flit(0)(14 downto 12) := rslv.hsize;
								if(rslv.hburst /= "000") then
									noc_tx_reg.flit(0)(7 downto 5) := "001"; -- INCR
								else
									noc_tx_reg.flit(0)(7 downto 5) := "000"; -- SINGLE
								end if;
								noc_tx_reg.flit(0)(11 downto 8) := rslv.hprot;
								noc_tx_reg.flit(1) := rslv.haddr;
								flit_index := 2; ---- start new index at 2 (header and addr already used)
								if(rslv.hwrite = '0') then
									-- Doesn't matter if hburst INCR/WARP/SINGLE all will be handled on remote interface
									noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
									noc_tx_reg.addr := conv_std_logic_vector(0,4); -------------------------------------- Replace Addr!!
									if(tready = '0') then
										requ <= noc_tx_reg;
										tx_r := '1';
										tready := '1';
										noc_tx_reg := noc_transfer_none;
									end if;
									--split_reg(conv_integer(swrite)) := rslv.hmaster;
									--swrite := swrite + '1';
									tslv.hresp := "11"; -- initiate SPLIT for read prefetch from remote interface
									tslv.hready := '0';
									bstate := 0;
									------------------------------------------------------------------------ SPLIT Queue !!
								else
									noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
									if(acwr = '0') then
										noc_tx_reg.flit(0)(2) := '1';
										noc_tx_reg.flit(0)(7 downto 5) := "000";
										tslv.hresp := "11";
										tslv.hready := '0';
									end if;
								end if;
								bstate := 1; -- new burst started
							-- (bstate) Busy because a still pending Request
							else
								split_reg(conv_integer(swrite)) := rslv.hmaster; -- setting SPLIT-Queue
								swrite := swrite + '1';
								tslv.hresp := "11";
								tslv.hready := '0';
								bstate := 0;
							end if;
						end if;
					---- HTRANS: SEQ ----
					elsif(rslv.htrans = "11") then
						-- check if burst was started before
						if(bstate = 1) then
							-- continue caching HWDATA
							if(rslv.hwrite = '1') then ---- insert: and write_ack = '1' ---------------------------------- !!
								if(acwr = '0') then
									noc_tx_reg.flit(1) := rslv.haddr;
									noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
									--flit_index := flit_index + 1;
									tslv.hresp := "11";
									tslv.hready := '0';
								else
									if(flit_index < 4) then
										noc_tx_reg.flit(flit_index) := rslv.hwdata(31 downto 0);
										flit_index := flit_index + 1; ---- increase after use and before setting length (index starts at 0, length starts at 1)
									elsif(flit_index = 4) then
										-- full packet therefore transmit it
										noc_tx_reg.len := conv_std_logic_vector(5,3);
										noc_tx_reg.addr := conv_std_logic_vector(0,4);
										noc_tx_reg.flit(flit_index) := rslv.hwdata(31 downto 0);
										if(tready = '0') then
											noc_tx_reg.addr := conv_std_logic_vector(3,4); ----- Debug
											requ <= noc_tx_reg;
											tx_r := '1';
											tready := '1';
											noc_tx_reg := noc_transfer_none;
											noc_tx_reg.len := conv_std_logic_vector(2,3);
											noc_tx_reg.addr := conv_std_logic_vector(0,4); ---------------------------------- Replace Addr!!
											noc_tx_reg.flit(0)(31 downto 28) := "0010"; ---- ahb_request_header
											noc_tx_reg.flit(0)(27 downto 24) := rslv.hmaster;
											noc_tx_reg.flit(0)(15) := rslv.hwrite;
											noc_tx_reg.flit(0)(14 downto 12) := rslv.hsize;
											if(rslv.hburst /= "000") then
												noc_tx_reg.flit(0)(7 downto 5) := "001"; -- INCR
											else
												noc_tx_reg.flit(0)(7 downto 5) := "000"; -- SINGLE
											end if;
											noc_tx_reg.flit(0)(11 downto 8) := rslv.hprot;
											noc_tx_reg.flit(1) := rslv.haddr;
											flit_index := 2; ---- start new index at 2 (header and addr used)
										else
											split_reg(conv_integer(swrite)) := rslv.hmaster;
											swrite := swrite + '1';
											tslv.hresp := "11";
											tslv.hready := '0';
											bstate := 0;
											------------------------------------------------------------------------ SPLIT Queue !!
										end if;
										---- flit_index?
									end if;
								end if;
							-- read
							else
								if(flit_index = 4) then
									if(noc_rx_reg.flit(flit_index) = x"ffffffff" and noc_rx_reg.flit(0)(1 downto 0) = "01") then
										tslv.hresp := "01";
										tslv.hready := '1';
									else
										tslv.hrdata(31 downto 0) := noc_rx_reg.flit(flit_index);
									end if;
									fresp := '0';
									noc_rx_reg := noc_transfer_none;
								else
									if(noc_rx_reg.flit(flit_index) = x"ffffffff" and noc_rx_reg.flit(0)(1 downto 0) = "01") then
										tslv.hresp := "01";
										tslv.hready := '1';
										fresp := '0';
										noc_rx_reg := noc_transfer_none; 
									else
										tslv.hrdata(31 downto 0) := noc_rx_reg.flit(flit_index);
										flit_index := flit_index + 1;
									end if;
								end if;
							end if;
							---- HWRITE ----
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
						bstate := 0;
					else
						-- nothing
					end if;
					---- End of HTRANS ----
				---- Error due to Bridge Looping (mindex)----
				else
					tslv.hresp := "01";
					tslv.hready := '0';
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
				tslv.hready := '1';
				if(acwr = '0' and conv_integer(noc_tx_reg.len) > 1) then
					noc_tx_reg.flit(2) := rslv.hwdata(31 downto 0);
					noc_tx_reg.len := conv_std_logic_vector(3,3);
					-------------------------------------------!!!
					if(tready = '0') then
						requ <= noc_tx_reg;
						tx_r := '1';
						tready := '1';
						noc_tx_reg := noc_transfer_none;
					end if;
				end if;
			end if;
		---- HSEL inactive ----
		else
			--- handle last write ---------------------------------------------------------------------acwr
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
			if(conv_integer(noc_tx_reg.len) > 1 and tready = '0') then
				requ <= noc_tx_reg; 
				tx_r := '1';
				tready := '1';
				noc_tx_reg := noc_transfer_none;
				flit_index := 2;
			end if;
			bstate := 0; --- next NONSEQ flit_index will be reset to 2
		end if;
		---- NoC-Response and SPLIT continuation -----------------------------------
		if(resp_ready = '1' and fresp = '0') then
			resp_ack <= '1';
			fresp := '1';
			if(conv_integer(resp.len) > 1 and resp.flit(0)(31 downto 28) = "0011") then
				noc_rx_reg := resp;
				split := conv_integer(noc_rx_reg.flit(0)(27 downto 24));
			else
				fresp := '0';
				split := 16;
			end if;
		---- call masters which where splitted because vcslv was busy -------
		elsif(tx_r = '0' and ((swrite(4) = '0' and conv_integer(sread) < conv_integer(swrite(3 downto 0))) 
												or (swrite(4) = '1' and conv_integer(sread) >= conv_integer(swrite(3 downto 0))))) then
			split := conv_integer(split_reg(conv_integer(sread)));
		end if;
		---- Set/Reset Split indicator --------------------------------------------------------- SPLIT Queue !!
		if(split < 16) then
			tslv.hsplit(split) := '1';
		else
			tslv.hsplit := x"0000";---??
		end if;
		---- TX Ready reset (2/2) --
		if(requ_ack = '1' and tx_r = '0') then 
			tready := '0';
		end if;
		---- Reset RX ACK ----
		if(resp_ready = '0') then 
			resp_ack <= '0';
		end if;
		----------------------------------------------------------------------------
		ahbso <= tslv;
		requ_ready <= tx_r;
	end if;
	---- Gaisler AHB Plug&Play status ---------------------------------------------
	ahbso.hconfig <= hconfig;
  	ahbso.hindex  <= hindex;
	
end process vcslv_proc;

end Behavioral;
