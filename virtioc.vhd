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
    hconfig_per  : virtioc_hconfig := virtioc_hconfig_def;
	 ); 
   port (
      rst  : in  std_ulogic;
      clk  : in  std_ulogic;
      ahbi_noc : in  ahb_mst_in_type;
      ahbo_noc : out ahb_mst_out_type;
		ahbi_per : in  ahb_mst_in_type;
		ahbo_per : out ahb_mst_out_type
      );
end virtioc;

architecture Behavioral of virtioc is

	signal noc_dmai, per_dmai : ahb_dmai_in_type;
	signal noc_dmao, per_damo : ahb_dmao_out_type;

begin

	noc_mst0 : ahbmst
		generic map (hindex => hconfig_noc.hindex, hirq => hconfig_noc.hirq, venid => hconfig_noc.venid,
                 devid => hconfig_noc.devid, version => hconfig_noc.version,
                 chprot => hconfig_noc.chprot, incaddr => hconfig_noc.incaddr)
		port map(rst, clk, noc_dmai, noc_dmao, noc_ahbi, noc_ahbo);
		
	per_mst1 : ahbmst
		generic map (hindex => hconfig_per.hindex, hirq => hconfig_per.hirq, venid => hconfig_per.venid,
                 devid => hconfig_per.devid, version => hconfig_per.version,
                 chprot => hconfig_per.chprot, incaddr => hconfig_per.incaddr)
		port map(rst, clk, per_dmai, per_dmao, ahbi, ahbo);

end Behavioral;

