----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:26:37 01/31/2016 
-- Design Name: 
-- Module Name:    vcmst - Behavioral 
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
use gaisler.custom.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vcmst is
	generic( hindex : integer := 0);
    Port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  requ_ready : in std_logic;
			  requ_ack : out std_logic;
			  requ : in noc_transfer_reg;
			  resp_ready : out std_logic;
			  resp_ack : in std_logic;
			  resp : out noc_transfer_reg;
			  ahbmi : in ahb_mst_in_type;
			  ahbmo : out ahb_mst_out_type);
end vcmst;

architecture Behavioral of vcmst is
constant hconfig : ahb_config_type := (
  0 => ahb_device_reg ( 16#01#, 16#007#, 0, 0, 0), --ahb_device_reg (VENDOR_GAISLER, GAISLER_AHBUART, 0, 0, 0)
  others => zero32);

begin
vcmst_proc: process(clk, res)
variable tmst : ahb_mst_out_type;
variable rmst : ahb_mst_in_type;
variable noc_tx_reg, noc_rx_reg : noc_transfer_reg;
variable vaddr, vincr : integer;
variable busy, tready : std_logic; -- master busy , transmit port ready
variable state : integer range 0 to 4;
variable flit_index : integer;
begin
	if(res = '0') then
		resp <= noc_transfer_none;
		ahbmo <= ahbm_none;
		tmst := ahbm_none;
		rmst := ahbm_in_none;
		ahbmo <= ahbm_none;
		requ_ack <= '0';
		resp_ready <= '0';
		noc_rx_reg := noc_transfer_none;
		noc_tx_reg := noc_transfer_none;
		state := 0;
		busy := '0';
		tready := '0';
		vaddr := 0;
		vincr := 0;
		flit_index := 0;
	elsif(clk'event and clk = '1') then
		rmst := ahbmi;
		if(requ_ready = '1' and busy = '0') then
			noc_rx_reg := requ;
			-- master busy no new packets til tready = 0 for new packet transmission
			busy := '1';
			requ_ack <= '1';
			state := 1;
			flit_index := 0; -- start new packet
			vaddr := 0;
			vincr := 0;
			tmst.hbusreq := '1';
		end if;
		if(requ_ready = '0') then requ_ack <= '0';
		end if;
		if(resp_ack = '1') then 
			resp_ready <= '0';
			resp <= noc_transfer_none;
			tready := '0';
		end if;
		---- AHB -----------------------------------------------------------
		if(rmst.hgrant(hindex) = '1') then
			if(rmst.hready = '1') then
				if(rmst.hresp = "00") then
					if((noc_rx_reg.flit(0)(15) = '0' and conv_integer(noc_rx_reg.len) = 2) or (noc_rx_reg.flit(0)(15) = '1' and conv_integer(noc_rx_reg.len) > 2)) then
						---- AHB RX/TX handling --------------------------------
						if(state = 0) then
							tmst := ahbm_none;
							busy := '0';
						---- 1st Address ---------------------------------------
						elsif(state = 1) then
							tmst.htrans := "10";
							tmst.hwrite := noc_rx_reg.flit(0)(15);
							tmst.hsize := noc_rx_reg.flit(0)(14 downto 12);
							tmst.hprot := noc_rx_reg.flit(0)(11 downto 8);
							---- save haddr and hsize in case of burst for later increment ----
							---- only 10 bit for 1kB burst boundary according to AMBA Spec Rev 2.0 Chapter 3.6 ----
							vaddr := conv_integer(noc_rx_reg.flit(1)(9 downto 0)); -- if(noc_rx_reg.flit(1)(9 downto 4) = "111111") then ---- check 1kB alignment
							---- hsize and haddr alignment check ----
							if(noc_rx_reg.flit(0)(14 downto 12) = "000") then
								vincr := 1;
							elsif(noc_rx_reg.flit(0)(14 downto 12) = "001" and noc_rx_reg.flit(1)(0) = '0') then
								vincr := 2;
							elsif(noc_rx_reg.flit(0)(14 downto 12) = "010" and noc_rx_reg.flit(1)(1 downto 0) = "00") then
								vincr := 4;
							end if;
							---- prepare response packet
							if(noc_rx_reg.flit(0)(15) = '0' or noc_rx_reg.flit(0)(2) = '1') then
								noc_tx_reg.len := conv_std_logic_vector(2,3);
								noc_tx_reg.flit(0) := noc_rx_reg.flit(0);
								noc_tx_reg.flit(1) := x"ffffffff";
								if(noc_tx_reg.flit(0)(31 downto 28) = "0010") then
									noc_tx_reg.flit(0)(31 downto 28) := "0011";
								elsif(noc_tx_reg.flit(0)(31 downto 28) = "0100") then
									noc_tx_reg.flit(0)(31 downto 28) := "0101";
								end if;
							end if;
							tmst.haddr := noc_rx_reg.flit(1);
							tmst.haddr(9 downto 0) := conv_std_logic_vector(vaddr+vincr*flit_index,10);
							flit_index := flit_index + 1;
							if(noc_rx_reg.flit(0)(15) = '1') then
								if(flit_index+2 < conv_integer(noc_rx_reg.len)) then
									tmst.hburst := noc_rx_reg.flit(0)(7 downto 5);
								else
									tmst.hburst := "000";
								end if;
							else
								tmst.hburst := noc_rx_reg.flit(0)(7 downto 5);
							end if;
							state := 2;
						---- 1st write, 2nd Address -----------------------------
						elsif(state = 2) then
							---- in case of burst write next addr to Bus ---------
							if(noc_rx_reg.flit(0)(7 downto 5) /= "000") then
								if(flit_index+2 < conv_integer(noc_rx_reg.len) or noc_rx_reg.flit(0)(15) = '0') then
									tmst.htrans := "11";
									tmst.haddr := noc_rx_reg.flit(1);
									tmst.haddr(9 downto 0) := conv_std_logic_vector(vaddr+vincr*flit_index,10);
									state := 3;
								else
									tmst := ahbm_none;
									if(noc_rx_reg.flit(0)(2) = '1') then
										state := 4;
									else
										state := 0;
										--busy := '0';
									end if;
								end if;
								---- send write data in case of write request -------
								if(noc_rx_reg.flit(0)(15) = '1') then
									tmst.hwdata(31 downto 0) := noc_rx_reg.flit(flit_index+1);
								end if;
							---- SINGLE ----
							else
								tmst := ahbm_none;
								---- send write data in case of write request -------
								if(noc_rx_reg.flit(0)(15) = '1') then
									tmst.hwdata(31 downto 0) := noc_rx_reg.flit(flit_index+1);
									if(noc_rx_reg.flit(0)(2) = '0') then
										state := 0;
										--busy := '0';
									else
										state := 4;
									end if;
								else
									state := 4;
								end if;
							end if;
							flit_index := flit_index + 1;
						-------- 2nd write or 1st Read --------------------------
						elsif(state = 3) then
							---- SINGLE
							if(noc_rx_reg.flit(0)(7 downto 5) = "000") then
								---- only read possible here ----
								if(noc_rx_reg.flit(0)(15) = '0') then
									noc_tx_reg.flit(flit_index-1) := rmst.hrdata(31 downto 0);
									noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
									if(tready = '0') then
										resp <= noc_tx_reg;
										resp_ready <= '1';
										tready := '1';
										busy := '0';
									end if;
								end if;
								state := 0;
							------- INCR
							else
								---- write
								if(noc_rx_reg.flit(0)(15) = '1') then
									tmst.haddr := noc_rx_reg.flit(1);
									tmst.haddr(9 downto 0) := conv_std_logic_vector(vaddr+vincr*flit_index,10);
									---- len valid from 1 to 5; noc_rx_reg.flit array from 0 to 4;
									if(flit_index+2 < conv_integer(noc_rx_reg.len)) then
										tmst.hwdata(31 downto 0) := noc_rx_reg.flit(flit_index+1);
										--flit_index := flit_index + 1;
									else
										tmst := ahbm_none;
										tmst.hwdata(31 downto 0) := noc_rx_reg.flit(flit_index+1);
										if(noc_rx_reg.flit(0)(2) = '1') then
											state := 4; -- wait for hresp
										else
											-- finish up and go home
											state := 0;
											--busy := '0';
										end if;
									end if;
								---- Read
								else
									if(flit_index < 5) then
										noc_tx_reg.flit(flit_index-1) := rmst.hrdata(31 downto 0);
										noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
										if(flit_index = 4) then
											tmst := ahbm_none;
											state := 4;
										else
											tmst.haddr := noc_rx_reg.flit(1);
											tmst.haddr(9 downto 0) := conv_std_logic_vector(vaddr+vincr*flit_index,10);
										end if;
										--flit_index := flit_index + 1;
									end if;
									-- read
								end if;
							end if;
							flit_index := flit_index + 1;
						elsif(state = 4) then
							if(noc_rx_reg.flit(0)(15) = '0') then
								noc_tx_reg.flit(flit_index-1) := rmst.hrdata(31 downto 0);
							elsif(noc_rx_reg.flit(0)(2) = '1') then
								noc_tx_reg.flit(0)(1 downto 0) := "00";
							end if;
							noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
							tmst := ahbm_none;
							if(tready = '0') then
								resp <= noc_tx_reg;
								resp_ready <= '1';
								tready := '1';
								busy := '0';
							end if;
							state := 0;
						else
						end if;
						---- state ---------------------------------------------
					else
						state := 0;
						noc_rx_reg := noc_transfer_none;
						busy := '0';
					end if;
					---- noc_rx_reg.len ---------------------------------------
				end if;
				---- hresp ---------------------------------------------------
			---- hready inactive --------------------------------------------
			else
				if(rmst.hresp /= "00") then
					tmst := ahbm_none;
					if(rmst.hresp = "01") then
						if(noc_rx_reg.flit(0)(15) = '0' or noc_rx_reg.flit(0)(2) = '1') then
							noc_tx_reg.flit(0)(1 downto 0) := rmst.hresp;
							noc_tx_reg.flit(flit_index-1) := x"ffffffff";
							noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
							if(tready = '0') then
								resp <= noc_tx_reg;
								noc_tx_reg := noc_transfer_none;
								resp_ready <= '1';
								tready := '1';
								busy := '0';
							end if;
							state := 0;
						else
							busy := '0';
							noc_tx_reg := noc_transfer_none;
						end if;
					else
						tmst.hbusreq := '1';
						flit_index := flit_index - 2; -- only possible when flit_index increase after each state transition
						state := 1;
					end if;
				end if;
				---- hresp ---------------------------------------------------
			end if;
			---- hready -----------------------------------------------------
		---- hgrant inactive -----------------------------------------------
		else
			if(conv_integer(noc_tx_reg.len) > 0 and busy = '1') then
				if(tready = '0') then
					resp <= noc_tx_reg;
					resp_ready <= '1';
					tready := '1';
					busy := '0';
				end if;
			end if;
		end if;
--		else
--			if(state = 4) then
--				if(noc_rx_reg.flit(0)(15) = '0') then
--					noc_tx_reg.flit(flit_index-1) := rmst.hrdata(31 downto 0);
--				elsif(noc_rx_reg.flit(0)(2) = '1') then
--					noc_tx_reg.flit(0)(1 downto 0) := "00";
--				end if;
--				noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
--				tmst := ahbm_none;
--				if(tready = '0') then
--					resp <= noc_tx_reg;
--					resp_ready <= '1';
--					tready := '1';
--					busy := '0';
--				end if;
--				state := 0;
--			end if;
--			if(tmst.hbusreq = '1') then
--				state := 1;
--			else
--				--busy := '0';
--				state := 0;
--			end if;
--		end if;
		---- hgrant - AHB --------------------------------------------------
		ahbmo <= tmst;
	end if;
	----- clk -------------------------------------------------------------
	ahbmo.hconfig <= hconfig;
  	ahbmo.hindex  <= hindex;
end process vcmst_proc;

end Behavioral;

