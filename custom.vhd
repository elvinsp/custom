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

component top_noc
	 generic (
    hindex      : integer := 0;
    haddr       : integer := 0;
    hmask       : integer := 16#fff#);
    port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    slvi    : in ahb_slv_in_type;
    slvo    : out  ahb_slv_out_type);
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

type virtioc_hconfig is record
	hindex  : integer := 0;
    hirq    : integer := 0;
    venid   : integer := VENDOR_GAISLER;
    devid   : integer := 0;
    version : integer := 0;
    chprot  : integer := 3;
    incaddr : integer := 0;
end record;

constant virtioc_hconfig_def : virtioc_hconfig := (0, 0, VENDOR_GAISLER, 0, 0, 3, 0);

constant dmai_none : ahb_dma_in_type := ((others => '0'), (others => '0'), '0', '0', '0', '0', '0', (others => '0'));

end custom;