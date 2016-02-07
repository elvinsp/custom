----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:55:54 01/19/2016 
-- Design Name: 
-- Module Name:    nocside - Behavioral 
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

entity nocside is
	 generic (
				hindex	: integer := 0;
				dbg		: std_logic := '0');
    Port ( 	res : in  STD_LOGIC;
				clk : in  STD_LOGIC;
				irq : out STD_LOGIC;
				oready : out STD_LOGIC;
				oack : in STD_LOGIC;
				otransfer : out transfer_reg;
				iready : in STD_LOGIC;
				iack : out STD_LOGIC;
				itransfer : in transfer_reg;
				slvi  : in   ahb_slv_in_type;
				slvo  : out  ahb_slv_out_type);
end nocside;

architecture Behavioral of nocside is

type noc_reg is array (0 to 26) of std_logic_vector(31 downto 0);  
constant hconfig : ahb_config_type := (
  0 => ahb_device_reg ( 16#01#, 16#020#, 0, 0, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
  4 => ahb_membar(16#400#, '0', '0', 16#fff#), -- ahb_membar(memaddr, '0', '0', memmask), others => X"00000000");
  others => zero32);
--signal io_transfer, le_transfer : std_logic_vector(31 downto 0);
signal obusy, ibusy : std_logic;

begin

x_noc: process(clk, res)
variable datastore : noc_reg; -- writen by io_ni, read by leon_ni
variable queue : integer := 0;
variable index : integer := 27;
variable tindex : integer := 27;
variable len : integer := 0;
variable basei : std_logic_vector(7 downto 0);
variable state : integer range 0 to 1;
variable t : ahb_slv_out_type;
variable r : ahb_slv_in_type;
begin
	if(res = '0') then
		t := ahbs_none;
		r := ahbs_in_none;
		irq <= '0';
		iack <= '0';
		oready <= '0';
		ibusy <= '0';
		obusy <= '0';
		datastore := (others => (others => '0'));
		otransfer <= (others => (others => '0'));
		slvo <= ahbs_none;
		basei := x"30";
	elsif(clk'event and clk = '1') then
		r := slvi; -- input ahb_slv_in buffer
		if(r.hsel(hindex) = '1') then
			state := 1;
			if(t.hresp = "00") then 
				if(r.htrans(1) = '1') then
					---- Write hwdata ----------------------------------------
					if(tindex >= 0 and tindex < 27) then
						datastore(tindex) := r.hwdata(31 downto 0);
						queue := 1;
						if(dbg='1') then print("leW01s "&tost(r.hwdata(31 downto 0))&" @ "&ptime); end if;
					end if;
					---- Read AHBdata ----------------------------------------
					index := a2i(r.haddr(7 downto 0));
					if(index >= 0 and index < 27) then
						-- haddr is legit
						if(r.hwrite = '0') then
							if(queue = 1 and tindex = index) then
								-- immediate readout after write; wait a cycle for legit data
								t.hresp := "00";
								t.hready := '0';
								queue := 0;   -- don't come here again unless there was a write transfer
								tindex := 27; -- deleting index so no illegal write is initiated in write section
								if(dbg='1') then print("leD00s "&tost(r.haddr(31 downto 0))&" @ "&ptime); end if;
							else
								-- Basic read transfer according to AMBA Spec (Rev 2.0)
								t.hready := '1';
								t.hrdata(31 downto 0) := datastore(index);
								t.hresp := "00";
								tindex := 27; -- deleting index so no illegal write is initiated in write section
								if(dbg='1') then print("leR00s "&tost(datastore(index))&" from "&tost(r.haddr(31 downto 0))&" @ "&ptime); end if;
							end if;
						else
							-- preparing write transfer in next cycle according to AMBA Spec (Rev 2.0)
							tindex := index; -- saving index for next cycle
							t.hresp := "00";
							t.hready := '1';
							-- print("W00s "&tost(r.haddr(31 downto 0))&" @ "&ptime);
						end if;
					---- ERROR Handling(1/3) -----------------------------------------
					else
						-- initiating two-cycle response according to AMBA Spec (Rev 2.0) Chapter 3.9.3
						t.hresp := "01";
						t.hready := '0';
						-- invalid address
						tindex := 27;
						index := 27;
						if(dbg='1') then  print("leE01s "&tost(r.haddr(31 downto 0))&" @ "&ptime); end if;
					end if;
				end if;
			---- ERROR Handling(3/3) -----------------------------------------
			elsif(t.hresp /= "00" and t.hready = '1') then
				-- 2nd cycle of two-cycle response according to AMBA Spec (Rev 2.0) Chapter 3.9.3
				if(r.htrans = "00") then
					t.hresp := "00";
				else
					t.hready := '0';
				end if;
			---- ERROR Handling(2/3) -----------------------------------------
			else
				-- 1st cycle of two-cycle response according to AMBA Spec (Rev 2.0) Chapter 3.9.3
				t.hready := '1';
			end if;
		else
			t := ahbs_none;
			if(state = 1) then -- execute last cmd after hsel low
				if(tindex >= 0 and tindex < 27) then -- tindex only in range if last cmd was write
					datastore(tindex) := r.hwdata(31 downto 0);
					t.hresp := "00";
					t.hready := '1';
					if(dbg='1') then print("leW01s "&tost(r.hwdata(31 downto 0))&" @ "&ptime); end if;
				elsif(index >= 0 and index < 27) then -- index only in range if last cmd was read
					t.hrdata(31 downto 0) := datastore(index);
					t.hresp := "00";
					t.hready := '1';
				end if;
				state := 0;
			end if;
			r := ahbs_in_none; -- slave not selected, no input
		end if;
		slvo <= t; -- output ahb_slv_out buffer
		--------------------------------------------------------------------------------------------------------
		-- Transmit
		if(oack = '1') then 
			obusy <= '0'; -- enable new transmit
			datastore(a2i(x"10"))(31) := '0'; -- ready to transmit data
			oready <= '0';
		end if;
		if(obusy = '0') then
			if(datastore(a2i(x"10"))(30) = '1') then
				obusy <= '1'; -- lock new transmit until oack
				otransfer(0)(18 downto 16) <= datastore(a2i(x"10"))(18 downto 16);
				otransfer(1) <= datastore(a2i(x"14"));
				otransfer(2) <= datastore(a2i(x"18"));
				otransfer(3) <= datastore(a2i(x"1c"));
				otransfer(4) <= datastore(a2i(x"20"));
				otransfer(5) <= datastore(a2i(x"24"));
				datastore(a2i(x"10"))(30) := '0';
				datastore(a2i(x"14")) := (others => '0');
				datastore(a2i(x"18")) := (others => '0');
				datastore(a2i(x"1c")) := (others => '0');
				datastore(a2i(x"20")) := (others => '0');
				datastore(a2i(x"24")) := (others => '0');
				datastore(a2i(x"10"))(31) := '1'; -- data not transmitted yet
				oready <= '1'; -- signal valid data
			end if;
		end if;
		-- Receive
		if(iready = '1') then
			if(ibusy = '0') then
				ibusy <= '1'; -- lock RX until iack is reset
				if(datastore(a2i(basei))(31) = '0') then
					datastore(a2i(basei)) 	:= itransfer(0);
					len := conv_integer(itransfer(0)(18 downto 16));
					if(len >= 1) then datastore(a2i(basei+x"04")) := itransfer(1);
					end if;
					if(len >= 2) then datastore(a2i(basei+x"08")) := itransfer(2);
					end if;
					if(len >= 3) then datastore(a2i(basei+x"0c")) := itransfer(3);
					end if;
					if(len >= 4) then datastore(a2i(basei+x"10")) := itransfer(4);
					end if;
					if(len >= 5) then datastore(a2i(basei+x"14")) := itransfer(5);
					end if;
					datastore(a2i(basei))(31) := '1';
					if(basei = x"30") then basei := x"50";
					elsif(basei = x"50") then basei := x"70";
					elsif(basei = x"70") then basei := x"30";
					end if;
					iack <= '1'; -- not full
				else
					iack <= '0';
				end if;
			end if;
		else	-- clear for new RX
			ibusy <= '0';
			iack <= '0';
		end if;
		
		-- RX Buffer empty?
		if(datastore(a2i(x"30"))(31) = '1' or datastore(a2i(x"50"))(31) = '1' or datastore(a2i(x"70"))(31) = '1') then
			irq <= '1';
		else
			irq <= '0';
		end if;
	end if;
	
	-- LEON Side AHB Slave
	slvo.hconfig <= hconfig;
  	slvo.hindex  <= hindex;
  	slvo.hsplit   <= (others => '0'); 
  	slvo.hirq    <= (others => '0');
	
end process x_noc;

end Behavioral;

