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
	type dmai_rom is array (0 to 15) of ahb_dma_in_type;
	signal rom : dmai_rom := (
	(x"40000028", x"1fff0000ffff0000ffff00001fff0000", '1', '0', '1', '0', '0', "010"),
	(x"40000014", x"3fff0000ffff0000ffff00003fff0000", '1', '0', '1', '0', '0', "010"),
	(x"40000018", x"7fff0000ffff0000ffff00007fff0000", '1', '0', '1', '0', '0', "010"),
	(x"40000020", x"00000000ffff0000ffff0000dead0000", '1', '0', '1', '0', '0', "010"),
	(x"40000020", x"00000000ffff0000ffff000000000000", '1', '0', '0', '0', '0', "010"),
	(x"40000018", x"00000000ffff0000ffff000000000000", '1', '0', '0', '0', '0', "010"),
	(x"40000014", x"00000000ffff0000ffff000000000000", '1', '0', '0', '0', '0', "010"),
	(x"40000024", x"def00000ffff0000ffff0000def00000", '1', '0', '1', '0', '0', "010"),
	(x"40000024", x"00000000ffff0000ffff000000000000", '1', '0', '0', '0', '0', "010"),
	(x"40000024", x"11100000ffff0000ffff000011100000", '1', '0', '1', '0', '0', "010"),
	(x"40000028", x"bed00000ffff0000ffff0000bed00000", '1', '0', '1', '0', '0', "010"),
	(x"40000028", x"00000000ffff0000ffff000000000000", '1', '0', '0', '0', '0', "010"),
	dmai_none, dmai_none, dmai_none, dmai_none
	);

	signal dmai_noc : ahb_dma_in_type;
	signal dmao_noc : ahb_dma_out_type;
	
	signal dmab_in : ahb_dma_in_type;
	signal wr_en, re_en, out_overflow, out_underflow, hwrite, hstart : std_logic;
	signal hwdata : std_logic_vector(AHBDW-1 downto 0);

begin

	noc_mst0 : ahbmst
		generic map (hindex => hconfig_noc.hindex, hirq => hconfig_noc.hirq, venid => hconfig_noc.venid,
                 devid => hconfig_noc.devid, version => hconfig_noc.version,
                 chprot => hconfig_noc.chprot, incaddr => hconfig_noc.incaddr)
		port map(rst, clk, dmai_noc, dmao_noc, ahbi_noc, ahbo_noc);
	
	dma_out_proc : process(clk, rst)
		variable outbuffer : dmai_buffer;
		variable wr_pointer : unsigned(bsize downto 0);
		variable re_pointer : unsigned(bsize downto 0);
		variable underflow, overflow : std_logic;
	begin
		-----------------------------------------------
		if(rst = '0') then
			dmai_noc <= dmai_none;
			outbuffer := (others => dmai_none);
			wr_pointer := (others => '0');
			re_pointer := (others => '0');
			hwdata <= (others => '0');
			hwrite <= '0';
			hstart <= '1';
			overflow := '0';
			underflow := '1';
		-----------------------------------------------	
		elsif(clk'event and clk = '1') then
			if(wr_en = '1') then
				if(re_pointer((bsize-1) downto 0) /= wr_pointer((bsize-1) downto 0) or wr_pointer(bsize) = '0') then
				-- filling buffer and incrementing write pointer
					outbuffer(conv_integer(wr_pointer((bsize-1) downto 0))) := dmab_in;
					wr_pointer := wr_pointer + '1';
					underflow := '0';
				else
					overflow := '1';
				end if;
			end if;
			----------------------------------------------------------
			if(underflow = '0') then
				--dmai_noc.start <= '1';
				if((re_pointer((bsize-1) downto 0) /= wr_pointer((bsize-1) downto 0) or wr_pointer(bsize) = '1')) then 
				-- emptying buffer und incrementing read pointer
					if(dmao_noc.ready = '1') then
						re_pointer := re_pointer + '1';
						overflow := '0';
						if(re_pointer(bsize) = '1' and re_pointer(bsize) = '1') then
						-- read pointer at index 0 again
							wr_pointer(bsize) := '0';
							re_pointer(bsize) := '0';
						end if;
					end if;
					dmai_noc <= outbuffer(conv_integer(re_pointer));
					if(dmao_noc.mexc = '0' and dmao_noc.ready = '1') then
						dmai_noc.wdata <= hwdata;
					end if;
					hwdata <= outbuffer(conv_integer(re_pointer)).wdata;
					hwrite <= outbuffer(conv_integer(re_pointer)).write;
				elsif(re_pointer((bsize-1) downto 0) = wr_pointer((bsize-1) downto 0) and wr_pointer(bsize) = '0') then
				-- buffer underflow but a write must be completed
					if(dmao_noc.ready = '1') then
						if(hwrite = '1') then
							dmai_noc.wdata <= hwdata;
							hwrite <= '0';
						end if;
						underflow := '1';
						dmai_noc.start <= '0';
					end if;
					--dmai_noc.start <= '0'; -- closing transfer
				end if;
			end if;
		end if;
		out_overflow <= overflow;
		out_underflow <= underflow;
		-----------------------------------------------
	end process dma_out_proc;
	
	dma_fill: process(clk, rst)
	variable count : unsigned(3 downto 0) := (others => '0'); 
	begin
		if(rst = '0') then
			count := (others => '0');
			wr_en <= '0';
		else
			if(clk'event and clk = '1') then
				if(out_overflow = '0' and rom(conv_integer(count)).start = '1') then
					dmab_in <= rom(conv_integer(count));
					wr_en <= '1';
					count := count + '1';
				else
					wr_en <= '0';
				end if;
			end if;
		end if;
	end process dma_fill;
	
	

end Behavioral;

