----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:38:40 11/02/2015 
-- Design Name: 
-- Module Name:    top_noc - Behavioral 
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
--use grlib.config_types.all;
--use grlib.config.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top_noc is
	 generic (
    hindex      : integer := 0;
    haddr       : integer := 0;
    hmask       : integer := 16#0ff#);
    port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    slvi    : in   ahb_slv_in_type;
    slvo    : out  ahb_slv_out_type);
end top_noc;

architecture rtl of top_noc is

function address2index (
    haddr : std_logic_vector(7 downto 0))
    return integer is
    variable index : integer;
begin
	case haddr(7 downto 0) is
		when x"00" =>
			return 0;
		when x"04" =>
			return 1;
		when x"08" =>
			return 2;
		when x"10" =>
			return 3;
		when x"14" =>
			return 4;
		when x"18" =>
			return 5;
		when x"1c" =>
			return 6;
		when x"20" =>
			return 7;
		when x"24" =>
			return 8;
		when x"30" =>
			return 9;
		when x"34" =>
			return 10;
		when x"38" =>
			return 11;
		when x"3c" =>
			return 12;
		when x"40" =>
			return 13;
		when x"44" =>
			return 14;
		when x"50" =>
			return 15;
		when x"54" =>
			return 16;
		when x"58" =>
			return 17;
		when x"5c" =>
			return 18;
		when x"60" =>
			return 19;
		when x"64" =>
			return 20;
		when x"70" =>
			return 21;
		when x"74" =>
			return 22;
		when x"78" =>
			return 23;
		when x"7c" =>
			return 24;
		when x"80" =>
			return 25;
		when x"84" =>
			return 26;
		when others =>
			return -1;
	end case;
end address2index;

constant VERSION   : amba_version_type := 0;
-- plug&play configuration
constant hconfig : ahb_config_type := (
  0 => ahb_device_reg ( 16#01#, 16#0E1#, 0, VERSION, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
  4 => ahb_membar(haddr, '0', '0', hmask), -- ahb_membar(memaddr, '0', '0', memmask), others => X"00000000");
  others => zero32);

type noc_reg is array (0 to 26) of std_logic_vector(31 downto 0);  
signal slreg : noc_reg;
signal v : ahb_slv_in_type;
  
begin
process(clk, rst)
--variable slreg_buffer : std_logic_vector(31 downto 0);
variable queue : integer := 0;
variable index : integer := 27;
variable tindex : integer := 27;
variable t : ahb_slv_out_type;
variable r : ahb_slv_in_type;
begin
	if(rst = '0') then
		t := ahbs_none;
		r := ahbs_in_none;
		slreg <= (others => (others => '0'));
		slvo <= ahbs_none;
	elsif(clk'event and clk = '1') then
		r := slvi; -- input ahb_slv_in buffer
		if(r.hsel(hindex) = '1') then
			if(t.hresp = "00") then 
				if(r.htrans(1) = '1') then
					---- Write hwdata ----------------------------------------
					if(tindex >= 0 and tindex < 27) then
						slreg(tindex) <= r.hwdata(31 downto 0);
						queue := 1;
						print("W01s "&tost(r.hwdata(31 downto 0))&" @ "&ptime);
					else
						-- slvo.hresp    <= "01";
						-- print("W01v "&tost(slvi.hwdata(31 downto 0)))&" @ "&ptime);
						-- possible errors were handled last cycle
					end if;
					---- Read AHBdata ----------------------------------------
					index := address2index(r.haddr(7 downto 0));
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
								print("D00s "&tost(r.haddr(31 downto 0))&" @ "&ptime);
							else
								-- Basic read transfer according to AMBA Spec (Rev 2.0)
								t.hready := '1';
								t.hrdata(31 downto 0) := slreg(index);
								t.hresp := "00";
								tindex := 27; -- deleting index so no illegal write is initiated in write section
								print("R00s "&tost(slreg(index))&" from "&tost(r.haddr(31 downto 0))&" @ "&ptime);
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
						print("E01s "&tost(r.haddr(31 downto 0))&" @ "&ptime);
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
			r := ahbs_in_none; -- slave not selected, no input
		end if;
		slvo <= t; -- output ahb_slv_out buffer
	end if;
	---------------------------------------------------------------------
	if(slreg(address2index(x"10"))(6) = '1') then
		if(slreg(address2index(x"30"))(7) = '0') then
			slreg(address2index(x"34")) <= slreg(address2index(x"14"));
			slreg(address2index(x"38")) <= slreg(address2index(x"18"));
			slreg(address2index(x"3c")) <= slreg(address2index(x"1c"));
			slreg(address2index(x"40")) <= slreg(address2index(x"20"));
			slreg(address2index(x"44")) <= slreg(address2index(x"24"));
			slreg(address2index(x"30"))(7) <= '1';
		elsif(slreg(address2index(x"50"))(7) = '0') then
			slreg(address2index(x"54")) <= slreg(address2index(x"14"));
			slreg(address2index(x"58")) <= slreg(address2index(x"18"));
			slreg(address2index(x"5c")) <= slreg(address2index(x"1c"));
			slreg(address2index(x"60")) <= slreg(address2index(x"20"));
			slreg(address2index(x"64")) <= slreg(address2index(x"24"));
			slreg(address2index(x"50"))(7) <= '1';
		elsif(slreg(address2index(x"70"))(7) = '0') then
			slreg(address2index(x"74")) <= slreg(address2index(x"14"));
			slreg(address2index(x"78")) <= slreg(address2index(x"18"));
			slreg(address2index(x"7c")) <= slreg(address2index(x"1c"));
			slreg(address2index(x"80")) <= slreg(address2index(x"20"));
			slreg(address2index(x"84")) <= slreg(address2index(x"24"));
			slreg(address2index(x"70"))(7) <= '1';
		end if;
	end if;
  	slvo.hsplit   <= (others => '0'); 
  	slvo.hirq    <= (others => '0');
  	slvo.hconfig <= hconfig;
  	slvo.hindex  <= hindex;
	
end process;

end rtl;
