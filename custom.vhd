--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;

package custom is

-- type <new_type> is
--  record
--    <type_name>        : std_logic_vector( 7 downto 0);
--    <type_name>        : std_logic;
-- end record;
--
-- Declare constants
--
-- constant <constant_name>		: time := <time_unit> ns;
-- constant <constant_name>		: integer := <value;
--
-- Declare functions and procedure
--
-- function <function_name>  (signal <signal_name> : in <type_declaration>) return <type_declaration>;
-- procedure <procedure_name> (<type_declaration> <constant_name>	: in <type_declaration>);
--


type virtioc_hconfig is record
	 hindex  : integer;
    hirq    : integer;
    venid   : integer;
    devid   : integer;
    version : integer;
    chprot  : integer;
    incaddr : integer;
end record;

constant virtioc_hconfig_def : virtioc_hconfig := (0, 0, VENDOR_GAISLER, 0, 0, 3, 0);
--constant dmai_none : ahb_dma_in_type := ((others => '0'), (others => '0'), '0', '0', '0', '0', '0', (others => '0'));

component top_noc
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
end component;

component virtioc
	generic (
    hconfig_noc  : virtioc_hconfig := virtioc_hconfig_def;
	 bsize 		  : integer := 4); 
   port (
      rst  : in  std_ulogic;
      clk  : in  std_ulogic;
      ahbi_noc : in  ahb_mst_in_type;
      ahbo_noc : out ahb_mst_out_type
      );
end component;

type noc_transfer is record
	src	 : integer range 0 to 3;
	dst	 : integer range 0 to 3;
	len	 : integer range 1 to 5;
   df0    : std_logic_vector(31 downto 0);
   df1    : std_logic_vector(31 downto 0);
   df2	 : std_logic_vector(31 downto 0);
   df3    : std_logic_vector(31 downto 0);
   df4    : std_logic_vector(31 downto 0);
end record;

function a2i(haddr : std_logic_vector(7 downto 0))
  return integer;

end custom;

package body custom is

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

end custom;