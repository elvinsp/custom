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
variable index : integer := -1;
begin
	if(rst = '0') then
		slvo <= ahbs_none;
		slreg <= (others => (others => '0'));
	elsif(clk'event and clk = '1') then
		slvo.hready <= '1';
		if(queue = 2) then
			index := address2index(v.haddr(7 downto 0));
			slvo.hrdata(31 downto 0) <= slreg(index);
			slvo.hresp    <= "00";
			queue := 0;
		end if;
		if(v.hsel(hindex) = '1' and v.htrans(1) = '1' and v.hwrite = '1') then -- write requesst
			index := address2index(v.haddr(7 downto 0));	 -- get register index
			if(index >= 0) then
				--slreg_buffer := slvi.hwdata(31 downto 0);
				--slreg(index) <= slreg_buffer;
				slreg(index) <= slvi.hwdata(31 downto 0);
				slvo.hresp    <= "00"; 
				queue := 1;
				--print("Accepted "&tost(slreg_buffer)&" into "&tost(index));
			else														 -- error unknown address
				slvo.hresp    <= "01";
				--print("Unacceptable Address");
			end if;
		end if;
		if(slvi.hsel(hindex) = '1') then
			v <= slvi;
			if(slvi.htrans(1) = '1' and slvi.hwrite = '0') then -- read request
				if(v.hwrite = '1' and slvi.haddr = v.haddr and queue = 1) then -- write back buffer if immediate request of written data
					--slvo.hrdata(31 downto 0) <= slreg_buffer;
					slvo.hready <= '0';
					queue := 2;
				else															 -- get register data
					queue := 0;
					index := address2index(slvi.haddr(7 downto 0));
					if(index >= 0) then
						slvo.hrdata(31 downto 0) <= slreg(index);
						slvo.hresp    <= "00"; 
						--print("Extracted "&tost(slreg(index))&" from "&tost(index));
					else														 -- error unknown address
						slvo.hresp    <= "01";
						--print("Unacceptable Address");
					end if;
				end if;
			end if;
		elsif(v.hsel(hindex) = '1') then
			v <= ahbs_in_none;
		end if;
	end if;
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
