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
    leon_hindex : integer := 0;
    leon_haddr  : integer := 0;
    hmask       : integer := 16#0ff#;
	 io_hindex   : integer := 0;
    io_haddr    : integer := 0;
	 dbg			 : std_logic := '0');
    port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    leon_slvi  : in   ahb_slv_in_type;
    leon_slvo  : out  ahb_slv_out_type;
	 io_slvi    : in   ahb_slv_in_type;
    io_slvo    : out  ahb_slv_out_type);
end top_noc;

architecture rtl of top_noc is

function a2i (
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
end a2i;

constant VERSION   : amba_version_type := 0;
-- plug&play configuration
constant hconfig_leon : ahb_config_type := (
  0 => ahb_device_reg ( 16#01#, 16#0E1#, 0, VERSION, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
  4 => ahb_membar(leon_haddr, '0', '0', hmask), -- ahb_membar(memaddr, '0', '0', memmask), others => X"00000000");
  others => zero32);
  
constant hconfig_io : ahb_config_type := (
  0 => ahb_device_reg ( 16#01#, 16#0E1#, 0, VERSION, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
  4 => ahb_membar(io_haddr, '0', '0', hmask), -- ahb_membar(memaddr, '0', '0', memmask), others => X"00000000");
  others => zero32);

type noc_reg is array (0 to 26) of std_logic_vector(31 downto 0);  
signal leon_slreg, io_slreg : noc_reg;
signal v : ahb_slv_in_type;
  
begin

leon_ni: process(clk, rst)
--variable leon_slreg_buffer : std_logic_vector(31 downto 0);
variable queue : integer := 0;
variable index : integer := 27;
variable tindex : integer := 27;
variable t : ahb_slv_out_type;
variable r : ahb_slv_in_type;
begin
	if(rst = '0') then
		t := ahbs_none;
		r := ahbs_in_none;
		leon_slreg <= (others => (others => '0'));
		leon_slvo <= ahbs_none;
	elsif(clk'event and clk = '1') then
		r := leon_slvi; -- input ahb_slv_in buffer
		if(r.hsel(leon_hindex) = '1') then
			if(t.hresp = "00") then 
				if(r.htrans(1) = '1') then
					---- Write hwdata ----------------------------------------
					if(tindex >= 0 and tindex < 27) then
						leon_slreg(tindex) <= r.hwdata(31 downto 0);
						queue := 1;
						if(dbg='1') then print("leW01s "&tost(r.hwdata(31 downto 0))&" @ "&ptime); end if;
					else
						-- leon_slvo.hresp    <= "01";
						-- print("W01v "&tost(leon_slvi.hwdata(31 downto 0)))&" @ "&ptime);
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
								t.hrdata(31 downto 0) := leon_slreg(index);
								t.hresp := "00";
								tindex := 27; -- deleting index so no illegal write is initiated in write section
								if(dbg='1') then print("leR00s "&tost(leon_slreg(index))&" from "&tost(r.haddr(31 downto 0))&" @ "&ptime); end if;
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
			r := ahbs_in_none; -- slave not selected, no input
		end if;
		leon_slvo <= t; -- output ahb_slv_out buffer
	end if;
	---------------------------------------------------------------------
	if(leon_slreg(a2i(x"10"))(6) = '1') then
		if(io_slreg(a2i(x"30"))(7) = '0') then
			io_slreg(a2i(x"34")) <= leon_slreg(a2i(x"14"));
			io_slreg(a2i(x"38")) <= leon_slreg(a2i(x"18"));
			io_slreg(a2i(x"3c")) <= leon_slreg(a2i(x"1c"));
			io_slreg(a2i(x"40")) <= leon_slreg(a2i(x"20"));
			io_slreg(a2i(x"44")) <= leon_slreg(a2i(x"24"));
			io_slreg(a2i(x"30"))(7) <= '1';
			leon_slreg(a2i(x"10"))(6) <= '0';
			leon_slreg(a2i(x"10"))(7) <= '0';
		elsif(io_slreg(a2i(x"50"))(7) = '0') then
			io_slreg(a2i(x"54")) <= leon_slreg(a2i(x"14"));
			io_slreg(a2i(x"58")) <= leon_slreg(a2i(x"18"));
			io_slreg(a2i(x"5c")) <= leon_slreg(a2i(x"1c"));
			io_slreg(a2i(x"60")) <= leon_slreg(a2i(x"20"));
			io_slreg(a2i(x"64")) <= leon_slreg(a2i(x"24"));
			io_slreg(a2i(x"50"))(7) <= '1';
			leon_slreg(a2i(x"10"))(6) <= '0';
			leon_slreg(a2i(x"10"))(7) <= '0';
		elsif(io_slreg(a2i(x"70"))(7) = '0') then
			io_slreg(a2i(x"74")) <= leon_slreg(a2i(x"14"));
			io_slreg(a2i(x"78")) <= leon_slreg(a2i(x"18"));
			io_slreg(a2i(x"7c")) <= leon_slreg(a2i(x"1c"));
			io_slreg(a2i(x"80")) <= leon_slreg(a2i(x"20"));
			io_slreg(a2i(x"84")) <= leon_slreg(a2i(x"24"));
			io_slreg(a2i(x"70"))(7) <= '1';
			leon_slreg(a2i(x"10"))(6) <= '0';
			leon_slreg(a2i(x"10"))(7) <= '0';
		else
			leon_slreg(a2i(x"10"))(7) <= '1';
		end if;
	else 
	------------- reset full indicator if send is reset
		io_slreg(a2i(x"10"))(7) <= '0';
	end if;
	
	-- LEON Side AHB Slave
	leon_slvo.hconfig <= hconfig_leon;
  	leon_slvo.hindex  <= leon_hindex;
  	leon_slvo.hsplit   <= (others => '0'); 
  	leon_slvo.hirq    <= (others => '0');
	
end process leon_ni;

io_ni: process(clk, rst)
--variable leon_slreg_buffer : std_logic_vector(31 downto 0);
variable queue : integer := 0;
variable index : integer := 27;
variable tindex : integer := 27;
variable t : ahb_slv_out_type;
variable r : ahb_slv_in_type;
begin
	if(rst = '0') then
		t := ahbs_none;
		r := ahbs_in_none;
		io_slreg <= (others => (others => '0'));
		io_slvo <= ahbs_none;
	elsif(clk'event and clk = '1') then
		r := io_slvi; -- input ahb_slv_in buffer
		if(r.hsel(io_hindex) = '1') then
			if(t.hresp = "00") then 
				if(r.htrans(1) = '1') then
					---- Write hwdata ----------------------------------------
					if(tindex >= 0 and tindex < 27) then
						io_slreg(tindex) <= r.hwdata(31 downto 0);
						queue := 1;
						if(dbg='1') then print("ioW01s "&tost(r.hwdata(31 downto 0))&" @ "&ptime); end if;
					else
						-- leon_slvo.hresp    <= "01";
						-- print("W01v "&tost(leon_slvi.hwdata(31 downto 0)))&" @ "&ptime);
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
								if(dbg='1') then print("ioD00s "&tost(r.haddr(31 downto 0))&" @ "&ptime); end if;
							else
								-- Basic read transfer according to AMBA Spec (Rev 2.0)
								t.hready := '1';
								t.hrdata(31 downto 0) := io_slreg(index);
								t.hresp := "00";
								tindex := 27; -- deleting index so no illegal write is initiated in write section
								if(dbg='1') then print("ioR00s "&tost(io_slreg(index))&" from "&tost(r.haddr(31 downto 0))&" @ "&ptime); end if;
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
						if(dbg='1') then print("ioE01s "&tost(r.haddr(31 downto 0))&" @ "&ptime); end if;
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
		io_slvo <= t; -- output ahb_slv_out buffer
	end if;
	---------------------------------------------------------------------
	if(io_slreg(a2i(x"10"))(6) = '1') then
		if(leon_slreg(a2i(x"30"))(7) = '0') then
			leon_slreg(a2i(x"34")) <= io_slreg(a2i(x"14"));
			leon_slreg(a2i(x"38")) <= io_slreg(a2i(x"18"));
			leon_slreg(a2i(x"3c")) <= io_slreg(a2i(x"1c"));
			leon_slreg(a2i(x"40")) <= io_slreg(a2i(x"20"));
			leon_slreg(a2i(x"44")) <= io_slreg(a2i(x"24"));
			leon_slreg(a2i(x"30"))(7) <= '1';
			-----------------------------------
			io_slreg(a2i(x"10"))(6) <= '0';
			io_slreg(a2i(x"10"))(7) <= '0';
		elsif(leon_slreg(a2i(x"50"))(7) = '0') then
			leon_slreg(a2i(x"54")) <= io_slreg(a2i(x"14"));
			leon_slreg(a2i(x"58")) <= io_slreg(a2i(x"18"));
			leon_slreg(a2i(x"5c")) <= io_slreg(a2i(x"1c"));
			leon_slreg(a2i(x"60")) <= io_slreg(a2i(x"20"));
			leon_slreg(a2i(x"64")) <= io_slreg(a2i(x"24"));
			leon_slreg(a2i(x"50"))(7) <= '1';
			-----------------------------------
			io_slreg(a2i(x"10"))(6) <= '0';
			io_slreg(a2i(x"10"))(7) <= '0';
		elsif(leon_slreg(a2i(x"70"))(7) = '0') then
			leon_slreg(a2i(x"74")) <= io_slreg(a2i(x"14"));
			leon_slreg(a2i(x"78")) <= io_slreg(a2i(x"18"));
			leon_slreg(a2i(x"7c")) <= io_slreg(a2i(x"1c"));
			leon_slreg(a2i(x"80")) <= io_slreg(a2i(x"20"));
			leon_slreg(a2i(x"84")) <= io_slreg(a2i(x"24"));
			leon_slreg(a2i(x"70"))(7) <= '1';
			io_slreg(a2i(x"10"))(6) <= '0';
			io_slreg(a2i(x"10"))(7) <= '0';
		else
			io_slreg(a2i(x"10"))(7) <= '1';
		end if;
	else
	------------- reset full indicator if send is reset
		io_slreg(a2i(x"10"))(7) <= '0';
	end if;
	-- IO Side AHB Slave
  	io_slvo.hconfig <= hconfig_io;
  	io_slvo.hindex  <= io_hindex;
  	io_slvo.hsplit   <= (others => '0'); 
  	io_slvo.hirq    <= (others => '0');
	
end process io_ni;

end rtl;
