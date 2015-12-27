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
use work.custom.all;
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
type transfer_reg is array (0 to 4) of std_logic_vector(31 downto 0); 
signal le_reg : noc_reg; -- writen by io_ni, read by leon_ni
signal io_reg : noc_reg; -- writen by leon_ni, read by io_ni
signal io_transfer, le_transfer : transfer_reg;
signal v : ahb_slv_in_type;
signal lef, iof, lev, iov : std_logic; -- full&valid signal
  
begin

leon_ni: process(clk, rst)
--variable le_reg_buffer : std_logic_vector(31 downto 0);
variable queue : integer := 0;
variable index : integer := 27;
variable tindex : integer := 27;
variable basei : std_logic_vector(7 downto 0);
variable t : ahb_slv_out_type;
variable r : ahb_slv_in_type;
begin
	if(rst = '0') then
		t := ahbs_none;
		r := ahbs_in_none;
		lef <= '0';
		le_reg <= (others => (others => '0'));
		leon_slvo <= ahbs_none;
		basei := x"30";
	elsif(clk'event and clk = '1') then
		r := leon_slvi; -- input ahb_slv_in buffer
		if(r.hsel(leon_hindex) = '1') then
			if(t.hresp = "00") then 
				if(r.htrans(1) = '1') then
					---- Write hwdata ----------------------------------------
					if(tindex >= 0 and tindex < 27) then
						le_reg(tindex) <= r.hwdata(31 downto 0);
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
			r := ahbs_in_none; -- slave not selected, no input
		end if;
		leon_slvo <= t; -- output ahb_slv_out buffer
		
		-- Write to IO
		if(iof = '0') then
			le_reg(a2i(x"10"))(7) <= '0';
			if(le_reg(a2i(x"10"))(6) = '1') then
				lev <= '1';
				le_transfer(0) <= le_reg(a2i(x"14"));
				le_transfer(1) <= le_reg(a2i(x"18"));
				le_transfer(2) <= le_reg(a2i(x"1c"));
				le_transfer(3) <= le_reg(a2i(x"20"));
				le_transfer(4) <= le_reg(a2i(x"24"));
				le_reg(a2i(x"10"))(6) <= '0';
			else
				lev <= '0';
			end if;
		else
			le_reg(a2i(x"10"))(7) <= '1';
		end if;
		-- Read from IO
		if(iov = '1') then
			-- find next free LEON RX Buffer
			if(basei = x"30") then basei := x"50";
			elsif(basei = x"50") then basei := x"70";
			elsif(basei = x"70") then basei := x"30";
			end if;
			-- Read Flit to LEON RX Buffer
			if(le_reg(a2i(basei))(7) = '0') then
				le_reg(a2i(basei+x"04")) <= io_transfer(0);
				le_reg(a2i(basei+x"08")) <= io_transfer(1);
				le_reg(a2i(basei+x"0c")) <= io_transfer(2);
				le_reg(a2i(basei+x"10")) <= io_transfer(3);
				le_reg(a2i(basei+x"14")) <= io_transfer(4);
				le_reg(a2i(basei))(7) <= '1';
			end if;
			-- LEON RX Buffer full?
			if(le_reg(a2i(x"30"))(7) = '1' and le_reg(a2i(x"50"))(7) = '1' and le_reg(a2i(x"70"))(7) = '1') then
				lef <= '1';
			else
				lef <= '0';
			end if;
		end if;
	end if;
	
	-- LEON Side AHB Slave
	leon_slvo.hconfig <= hconfig_leon;
  	leon_slvo.hindex  <= leon_hindex;
  	leon_slvo.hsplit   <= (others => '0'); 
  	leon_slvo.hirq    <= (others => '0');
	
end process leon_ni;

io_ni: process(clk, rst)
--variable le_reg_buffer : std_logic_vector(31 downto 0);
variable queue : integer := 0;
variable index : integer := 27;
variable tindex : integer := 27;
variable basei : std_logic_vector(7 downto 0);
variable t : ahb_slv_out_type;
variable r : ahb_slv_in_type;
begin
	if(rst = '0') then
		t := ahbs_none;
		r := ahbs_in_none;
		iof <= '0';
		iov <= '0';
		io_reg <= (others => (others => '0'));
		io_slvo <= ahbs_none;
		basei := x"30";
	elsif(clk'event and clk = '1') then
		r := io_slvi; -- input ahb_slv_in buffer
		if(r.hsel(io_hindex) = '1') then
			if(t.hresp = "00") then 
				if(r.htrans(1) = '1') then
					---- Write hwdata ----------------------------------------
					if(tindex >= 0 and tindex < 27) then
						io_reg(tindex) <= r.hwdata(31 downto 0);
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
								t.hrdata(31 downto 0) := io_reg(index);
								t.hresp := "00";
								tindex := 27; -- deleting index so no illegal write is initiated in write section
								if(dbg='1') then print("ioR00s "&tost(io_reg(index))&" from "&tost(r.haddr(31 downto 0))&" @ "&ptime); end if;
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
		
		-- Write to LEON
		if(lef = '0') then
			io_reg(a2i(x"10"))(7) <= '0';
			if(io_reg(a2i(x"10"))(6) = '1') then
				iov <= '1';
				io_transfer(0) <= io_reg(a2i(x"14"));
				io_transfer(1) <= io_reg(a2i(x"18"));
				io_transfer(2) <= io_reg(a2i(x"1c"));
				io_transfer(3) <= io_reg(a2i(x"20"));
				io_transfer(4) <= io_reg(a2i(x"24"));
				io_reg(a2i(x"10"))(6) <= '0';
			else
				iov <= '0';
			end if;
		else
			io_reg(a2i(x"10"))(7) <= '1';
		end if;
		-- Read from LEON
		if(lev = '1') then
			-- find next free IO RX Buffer
			if(basei = x"30") then basei := x"50";
			elsif(basei = x"50") then basei := x"70";
			elsif(basei = x"70") then basei := x"30";
			end if;
			-- Write Flit to leon RX Buffer
			if(io_reg(a2i(basei))(7) = '0') then
				io_reg(a2i(basei+x"04")) <= le_transfer(0);
				io_reg(a2i(basei+x"08")) <= le_transfer(1);
				io_reg(a2i(basei+x"0c")) <= le_transfer(2);
				io_reg(a2i(basei+x"10")) <= le_transfer(3);
				io_reg(a2i(basei+x"14")) <= le_transfer(4);
				io_reg(a2i(basei))(7) <= '1';
			end if;
			-- IO RX Buffer full?
			if(io_reg(a2i(x"30"))(7) = '1' and io_reg(a2i(x"50"))(7) = '1' and io_reg(a2i(x"70"))(7) = '1') then
				iof <= '1';
			else
				iof <= '0';
			end if;
		end if;
	end if;
	-- IO Side AHB Slave
  	io_slvo.hconfig <= hconfig_io;
  	io_slvo.hindex  <= io_hindex;
  	io_slvo.hsplit   <= (others => '0'); 
  	io_slvo.hirq    <= (others => '0');
	
end process io_ni;

end rtl;
