----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:35:58 03/30/2016 
-- Design Name: 
-- Module Name:    ahbtst - Behavioral 
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
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

entity ahbtst is
    Port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  tstin_r : in std_logic;
			  tstin_a : out std_logic;
			  tstin : in std_logic_vector(67 downto 0);
			  tstout_r : out std_logic;
			  tstout : out std_logic_vector(67 downto 0));
end ahbtst;

architecture Behavioral of ahbtst is
begin

process(res, clk)
variable tmst : ahb_mst_out_type;
variable rmst : ahb_mst_in_type;
begin
	if(res = '0') then
	elsif(clk'event and clk = '1') then
		---- AHB -----------------------------------------------------------
		if(rmst.hgrant(hindex) = '1') then
			if(rmst.hready = '1') then
				if(rmst.hresp = "00") then
					if(conv_integer(noc_rx_reg.len) > 1) then
						---- AHB RX/TX handling --------------------------------
						if(state = 0) then
							tmst := ahbm_none;
						--------------------------------------------------------
						elsif(state = 1) then
							tmst.htrans := "10";
							tmst.hwrite := noc_rx_reg.flit(0)(15);
							tmst.hsize := noc_rx_reg.flit(0)(14 downto 12);
							tmst.hburst := noc_rx_reg.flit(0)(7 downto 5);
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
							if(noc_rx_reg.flit(0)(15) = '0') then
								noc_tx_reg.len := conv_std_logic_vector(2,3);
								noc_tx_reg.flit(0) := noc_rx_reg.flit(0);
								if(noc_tx_reg.flit(0)(31 downto 28) = "0010") then
									noc_tx_reg.flit(0)(31 downto 28) := "0011";
								elsif(noc_tx_reg.flit(0)(31 downto 28) = "0100") then
									noc_tx_reg.flit(0)(31 downto 28) := "0101";
								end if;
							end if;
							tmst.haddr := noc_rx_reg.flit(1);
							tmst.haddr(9 downto 0) := conv_std_logic_vector(vaddr+vincr*flit_index,10);
							flit_index := flit_index + 1;
							state := 2;
						---------------------------------------------------------
						elsif(state = 2) then
							---- in case of burst write next addr to Bus ---------
							state := 3;
							if(noc_rx_reg.flit(0)(7 downto 5) /= "000") then
								tmst.htrans := "11";
								tmst.haddr := noc_rx_reg.flit(1);
								tmst.haddr(9 downto 0) := conv_std_logic_vector(vaddr+vincr*flit_index,10);
								---- send write data in case of write request -------
								if(noc_rx_reg.flit(0)(15) = '1') then
									tmst.hwdata(31 downto 0) := noc_rx_reg.flit(flit_index+1);
								end if;
							else
								tmst := ahbm_none;
								---- send write data in case of write request -------
								if(noc_rx_reg.flit(0)(15) = '1') then
									tmst.hwdata(31 downto 0) := noc_rx_reg.flit(flit_index+1);
									state := 0;
									busy := '0';
								else
									state := 4;
								end if;
							end if;
							flit_index := flit_index + 1;
						--------------------------------------------------------
						elsif(state = 3) then
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
							else
								if(noc_rx_reg.flit(0)(15) = '1') then
									tmst.haddr := noc_rx_reg.flit(1);
									tmst.haddr(9 downto 0) := conv_std_logic_vector(vaddr+vincr*flit_index,10);
									if(flit_index+2 < conv_integer(noc_rx_reg.len)) then
										tmst.hwdata(31 downto 0) := noc_rx_reg.flit(flit_index+1);
										--flit_index := flit_index + 1;
									else
										tmst := ahbm_none;
										tmst.hwdata(31 downto 0) := noc_rx_reg.flit(flit_index+1);
										state := 0;
										busy := '0';
									end if;
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
							noc_tx_reg.flit(flit_index-1) := rmst.hrdata(31 downto 0);
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
								resp_ready <= '1';
								tready := '1';
								busy := '0';
							end if;
							state := 0;
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
			if(state = 4) then
				noc_tx_reg.flit(flit_index-1) := rmst.hrdata(31 downto 0);
				noc_tx_reg.len := conv_std_logic_vector(flit_index,3);
				tmst := ahbm_none;
				if(tready = '0') then
					resp <= noc_tx_reg;
					resp_ready <= '1';
					tready := '1';
					busy := '0';
				end if;
				state := 0;
			end if;
			if(tmst.hbusreq = '1') then
				state := 1;
			else
				busy := '0';
				state := 0;
			end if;
		end if;
		---- hgrant - AHB --------------------------------------------------
		ahbmo <= tmst;
	end if;
end process;
end Behavioral;

