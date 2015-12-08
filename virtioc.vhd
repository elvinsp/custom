----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:57:41 12/05/2015 
-- Design Name: 
-- Module Name:    virtioc - Behavioral 
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library gaisler;
use gaisler.custom.all;
library grlib;
use grlib.amba.all;
--use grlib.devices.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity virtioc is
	generic (
    hconfig_noc  : virtioc_hconfig := virtioc_hconfig_def;
	 bsize : integer := 4
	 ); 
   port (
      rst  : in  std_ulogic;
      clk  : in  std_ulogic;
      ahbi_noc : in  ahb_mst_in_type;
      ahbo_noc : out ahb_mst_out_type
      );
end virtioc;

architecture Behavioral of virtioc is

	type dmai_buffer is array (0 to (2**bsize)-1) of ahb_dma_in_type;

	signal dmai_noc : ahb_dma_in_type;
	signal dmao_noc : ahb_dma_out_type;
	
	signal dma_out : ahb_dma_in_type;
	signal wr_en, out_overflow : std_logic;

begin

	noc_mst0 : ahbmst
		generic map (hindex => hconfig_noc.hindex, hirq => hconfig_noc.hirq, venid => hconfig_noc.venid,
                 devid => hconfig_noc.devid, version => hconfig_noc.version,
                 chprot => hconfig_noc.chprot, incaddr => hconfig_noc.incaddr)
		port map(rst, clk, dmai_noc, dmao_noc, ahbi_noc, ahbo_noc);
	
	dma_out_proc : process(clk, rst)
		variable outbuffer : dmai_buffer;
		variable wr_pointer : unsigned(bsize downto 0);
		variable re_pointer : unsigned((bsize-1) downto 0);
		variable stop : std_logic;
		variable hwdata : std_logic_vector(AHBDW-1 downto 0);
		constant base : unsigned((bsize-1) downto 0) := (others => '0');
	begin
		-----------------------------------------------
		if(rst = '0') then
			dmai_noc <= dmai_none;
			outbuffer := (others => dmai_none);
			wr_pointer := (others => '0');
			re_pointer := (others => '0');
			stop := '0';
			hwdata := (others => '0');
			wr_en <= '0';
			out_overflow <= '0';
		-----------------------------------------------	
		elsif(clk'event and clk = '1') then
			if(wr_en = '1' and stop = '0') then
				outbuffer(conv_integer(wr_pointer)) := dma_out;
				wr_pointer := wr_pointer + '1';
				-- if pointers aren't on the same place and carrier isn't set
				if(re_pointer = wr_pointer((bsize-1) downto 0) and wr_pointer(bsize) = '1') then
					-- write pointer is equal read pointer and came from behind
					stop := '1';
					out_overflow <= '1';
				end if;
			end if;
			-- if pointers aren't on the same place and carrier isn't set
			if(re_pointer /= wr_pointer((bsize-1) downto 0) or wr_pointer(bsize) = '0') then 
				dmai_noc <= outbuffer(conv_integer(re_pointer));
				dmai_noc.wdata <= hwdata;
				hwdata := outbuffer(conv_integer(re_pointer)).wdata;
				re_pointer := re_pointer + '1';
				if(re_pointer /= wr_pointer((bsize-1) downto 0) and wr_pointer(bsize) = '1') then
				-- write pointer is behind read pointer
					stop := '0';
					out_overflow <= '0';
				end if;
				if(re_pointer = base) then wr_pointer(bsize) := '0';
				end if;
			end if;
		end if;
		-----------------------------------------------
	end process dma_out_proc;
	
	

end Behavioral;

