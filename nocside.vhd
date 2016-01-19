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
				ofull : out STD_LOGIC;
				ovalid : out STD_LOGIC;
				ifull : in STD_LOGIC;
				ivalid : in STD_LOGIC;
				slvi  : in   ahb_slv_in_type;
				slvo  : out  ahb_slv_out_type);
end nocside;

architecture Behavioral of nocside is

type noc_reg is array (0 to 26) of std_logic_vector(31 downto 0); 
type transfer_reg is array (0 to 4) of std_logic_vector(31 downto 0); 
signal le_reg : noc_reg; -- writen by io_ni, read by leon_ni
signal io_reg : noc_reg; -- writen by leon_ni, read by io_ni
signal io_transfer, le_transfer : std_logic_vector(31 downto 0);
--signal v : ahb_slv_in_type;

begin

leon_ni: process(clk, rst)
--variable le_reg_buffer : std_logic_vector(31 downto 0);
variable queue : integer := 0;
variable index : integer := 27;
variable tindex : integer := 27;
variable basei : std_logic_vector(7 downto 0);
variable state : integer range 0 to 1;
variable t : ahb_slv_out_type;
variable r : ahb_slv_in_type;
begin
	if(res = '0') then
		t := ahbs_none;
		r := ahbs_in_none;
		irq <= '0';
		ofull <= '0';
		ovalid <= '0';
		le_reg <= (others => (others => '0'));
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
						le_reg(tindex) <= r.hwdata(31 downto 0);
						queue := 1;
						if(dbg='1') then print("leW01s "&tost(r.hwdata(31 downto 0))&" @ "&ptime); end if;
					else
						-- slvo.hresp    <= "01";
						-- print("W01v "&tost(slvi.hwdata(31 downto 0)))&" @ "&ptime);
						-- possible errors were handled last cycle
					end if;
					---- Read AHBdata ----------------------------------------
					index := a2i(r.haddr(7 downto 0));
					if(index >= 0 and index < 27) then
						-- haddr is legit
						if(r.hwrite = '0') then
							if(queue = 1 and tindex = index) then
								-- immediate readout after write; wait for legit data; not within AMBA Spec
								-- t.hresp <= "10";
								t.hresp := "10";
								t.hready := '0';
								queue := 0;   -- don't come here again unless there was a write transfer
								tindex := 27; -- deleting index so no illegal write is initiated in write section
								if(dbg='1') then print("leD00s "&tost(r.haddr(31 downto 0))&" @ "&ptime); end if;
							else
								-- Basic read transfer according to AMBA Spec (Rev 2.0)
								t.hready := '1';
								t.hrdata(31 downto 0) := le_reg(index);
								t.hresp := "00";
								tindex := 27; -- deleting index so no illegal write is initiated in write section
								if(dbg='1') then print("leR00s "&tost(le_reg(index))&" from "&tost(r.haddr(31 downto 0))&" @ "&ptime); end if;
							end if;
						else
							-- preparing write transfer in next cycle according to AMBA Spec (Rev 2.0)
							tindex := index; -- saving index for next cycle
							t.hresp := "00";
							t.hready := '1';
							-- print("W00s "&tost(r.haddr(31 downto 0))&" @ "&ptime);
						end if;
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
					-- 2nd cycle of two-cycle response according to AMBA Spec (Rev 2.0) Chapter 3.9.3
			elsif(t.hresp /= "00" and t.hready = '1') then --------
				if(r.htrans = "00") then
					t.hresp := "00";
				end if;
					-- 1st cycle of two-cycle response according to AMBA Spec (Rev 2.0) Chapter 3.9.3
			else 	-------
				t.hready := '1';
			end if;
		else
			t := ahbs_none;
			if(state = 1) then -- execute last cmd after hsel low
				if(tindex >= 0 and tindex < 27) then -- tindex only in range if last cmd was write else read
					le_reg(tindex) <= r.hwdata(31 downto 0);
					t.hresp := "00";
					t.hready := '1';
					if(dbg='1') then print("leW01s "&tost(r.hwdata(31 downto 0))&" @ "&ptime); end if;
				else 
					t.hrdata(31 downto 0) := le_reg(index);
					t.hresp := "00";
					t.hready := '1';
				end if;
				state := 0;
			end if;
			r := ahbs_in_none; -- slave not selected, no input
		end if;
		slvo <= t; -- output ahb_slv_out buffer
		--------------------------------------------------------------------------------------------------------
		-- Write to IO
		if(ifull = '0') then
			le_reg(a2i(x"10"))(7) <= '0'; -- IO Side ready
			if(le_reg(a2i(x"10"))(6) = '1') then
				ovalid <= '1'; -- transfer data valid for IO Side
				le_transfer(0) <= le_reg(a2i(x"14"));
				le_transfer(1) <= le_reg(a2i(x"18"));
				le_transfer(2) <= le_reg(a2i(x"1c"));
				le_transfer(3) <= le_reg(a2i(x"20"));
				le_transfer(4) <= le_reg(a2i(x"24"));
				le_reg(a2i(x"10"))(6) <= '0';
			else
				ovalid <= '0'; -- transfer data invalid for IO Side
			end if;
		else
			le_reg(a2i(x"10"))(7) <= '1';
		end if;
		-- Read from IO
		if(ivalid = '1') then
			-- Read Flit to LEON RX Buffer
			if(le_reg(a2i(basei))(7) = '0') then
				--if(conv_integer(io_reg(a2i(basei))(7)) >= 1)
				le_reg(a2i(basei+x"04")) <= io_transfer(0);
				le_reg(a2i(basei+x"08")) <= io_transfer(1);
				le_reg(a2i(basei+x"0c")) <= io_transfer(2);
				le_reg(a2i(basei+x"10")) <= io_transfer(3);
				le_reg(a2i(basei+x"14")) <= io_transfer(4);
				le_reg(a2i(basei))(7) <= '1';
				ofull <= '0'; -- not full
			else
				ofull <= '1'; -- full
			end if;
			-- LEON RX Buffer full?
			--if(le_reg(a2i(x"30"))(7) = '1' and le_reg(a2i(x"50"))(7) = '1' and le_reg(a2i(x"70"))(7) = '1') then
			--	ofull <= '1';
			--else
			--	ofull <= '0';
			--end if;
			-- find next free LEON RX Buffer
			if(basei = x"30") then basei := x"50";
			elsif(basei = x"50") then basei := x"70";
			elsif(basei = x"70") then basei := x"30";
			end if;
		end if;
		-- LEON RX Buffer empty?
		if(le_reg(a2i(x"30"))(7) = '1' or le_reg(a2i(x"50"))(7) = '1' or le_reg(a2i(x"70"))(7) = '1') then
			irq <= '1';
		else
			irq <= '0';
		end if;
	end if;
	
	-- LEON Side AHB Slave
	--slvo.hconfig <= hconfig_leon;
  	slvo.hindex  <= hindex;
  	slvo.hsplit   <= (others => '0'); 
  	slvo.hirq    <= (others => '0');
	
end process leon_ni;

end Behavioral;

