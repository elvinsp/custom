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
use gaisler.ahbtbp.all;
use work.custom.all;

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
  0 => ahb_device_reg ( 16#01#, 16#020#, 0, 0, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
  4 => ahb_membar(16#400#, '0', '0', 16#fff#), -- ahb_membar(memaddr, '0', '0', memmask), others => X"00000000");
  others => zero32);
begin
vcmst_proc: process(clk, res)
variable tmst : ahb_mst_out_type;
variable rmst : ahb_mst_in_type;
variable noc_tx_reg, noc_rx_reg : noc_transfer_reg;
variable busy : std_logic;
variable state : integer range 0 to 3;
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
	elsif(clk'event and clk = '1') then
		rmst := ahbmi;
		if(requ_ready = '1' and busy = '0') then
			noc_tx_reg := requ;
			busy := '1'; -- lock on transaction
			requ_ack <= '1';
			state := 1;
			tmst.hbusreq := '1';
		end if;
		if(requ_ready = '0') then requ_ack <= '0';
		end if;
		if(resp_ack = '1') then resp_ready <= '1';
		end if;
		if(state = 0) then
			if(rmst.hready = '1') then 
				tmst := ahbm_none;
			end if;
		elsif(state = 1) then
			tmst.hbusreq := '1';
			if(rmst.hgrant(hindex) = '1' and rmst.hready = '1') then
				if(rmst.hresp = "00") then
					tmst.haddr := noc_tx_reg.flit(1);
					if(noc_tx_reg.flit(0)(15) = '1') then
						tmst.hwrite := '1';
					else
						tmst.hwrite := '0';
					end if;
					tmst.htrans := noc_tx_reg.flit(0)(14 downto 13);
					tmst.hsize := noc_tx_reg.flit(0)(12 downto 10);
					tmst.hburst := noc_tx_reg.flit(0)(9 downto 7);
					tmst.hprot := noc_tx_reg.flit(0)(6 downto 3);
					state := 2;
				end if;
			end if;
		elsif(state = 2) then  -- execute write and then idle; errors will be not detected
			tmst.hbusreq := '0';
			if(noc_tx_reg.flit(0)(15) = '1') then
				tmst := ahbm_none;
				tmst.hwdata(31 downto 0) := noc_tx_reg.flit(2);
				busy := '0'; -- ahb write done; clear transaction
				state := 0;
			else
				state := 3;
			end if;
		elsif(state = 3) then
			if(rmst.hready = '1') then
				tmst := ahbm_none;
				if(rmst.hresp = "11") then
					state := 1;
				else
					busy := '0'; -- ahb read done; clear transaction
					state := 0;
				end if;
			---- ERROR Handling -------------------------------------------
			elsif(rmst.hresp /= "00") then -- TODO: SPLIT/RETRY Handling!!!!
				tmst.htrans := "00";
				resp.flit(0) <= noc_tx_reg.flit(0);
				resp.flit(0)(1 downto 0) <= "00";
				if(rmst.hresp = "00") then
					resp.flit(1) <= rmst.hrdata(31 downto 0);
				elsif(rmst.hresp = "01") then
					resp.flit(0)(1 downto 0) <= "01";
				end if;
				resp_ready <= '1';
			end if;
		end if;
		ahbmo <= tmst;
	end if;
	ahbmo.hconfig <= hconfig;
  	ahbmo.hindex  <= hindex;
end process vcmst_proc;

end Behavioral;

