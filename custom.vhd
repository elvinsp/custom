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

-- typedef
type transfer_reg is array (0 to 5) of std_logic_vector(31 downto 0);

type flits is array (0 to 4) of std_logic_vector(31 downto 0);

type noc_transfer_reg is record
	len : std_logic_vector(2 downto 0);
	addr : std_logic_vector(3 downto 0);
	flit :  flits;
end record;

--type noc_flit_ahb is record
--	vio_header : std_logic_vector(31 downto 0); -- Virtual Controller Infos
--	ahb_header : std_logic_vector(31 downto 0); -- AHB Control Signals
--	ahb_haddr : std_logic_vector(31 downto 0);  -- AHB Address
--	ahb_hdata : std_logic_vector(31 downto 0);  -- AHB Data
--end record;
--
--type noc_io_config is record
--	vio_header : std_logic_vector(31 downto 0);
--	io_resource : std_logic_vector(31 downto 0);
--	io_state : std_logic_vector(31 downto 0);
--end record;

-- constants
--constant noc_io_config_none : noc_io_config := ((others => '0'), (others => '0'), (others => '0'));
--constant noc_flit_ahb_none : noc_flit_ahb := ((others => '0'), (others => '0'), (others => '0'), (others => '0'));
constant flit_none : flits := ((others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'));
constant noc_transfer_none : noc_transfer_reg := ((others => '0'), (others => '0'), flit_none);

component vcmst
	 generic( hindex : integer := 0);
    port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  requ_ready : in std_logic;
			  requ_ack : out std_logic;
			  requ : in noc_transfer_reg;
			  resp_ready : out std_logic;
			  resp_ack : in std_logic;
			  resp : out noc_transfer_reg;
			  ahbmi : in ahb_mst_in_type;
			  ahbmo : out ahb_mst_out_type);
end component;

component vcslv is
    generic( hindex : integer := 0;
				 nahbmst : integer := 1;
				 memaddr : integer range 0 to 16 := 16;
				 ioaddr : integer range 0 to 16 := 16);
    port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  requ_ready : out std_logic;
			  requ_ack : in std_logic;
			  requ : out noc_transfer_reg;
			  resp_ready : in std_logic;
			  resp_ack : out std_logic;
			  resp : in noc_transfer_reg;
			  ahbsi : in ahb_slv_in_type;
			  ahbso : out ahb_slv_out_type);
end component;

component vnic
	generic (nic_hindex : integer := 0);
   port (  res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  nic_irq : in std_logic;
			  nici : out ahb_slv_in_type;
			  nico : in ahb_slv_out_type;
			  --msti : in  ahb_mst_in_type;
			  --msto : out ahb_mst_out_type;
			  slvi : in ahb_slv_in_type;
			  slvo : out ahb_slv_out_type);
end component;

component nocside
	 generic (
				hindex	: integer := 0;
				dbg		: std_logic := '0');
    Port ( 	res : in  STD_LOGIC;
				clk : in  STD_LOGIC;
				irq : out STD_LOGIC;
				oready : out STD_LOGIC;
				oack : in STD_LOGIC;
				otransfer : out transfer_reg;
				iready : in STD_LOGIC;
				iack : out STD_LOGIC;
				itransfer : in transfer_reg;
				slvi  : in   ahb_slv_in_type;
				slvo  : out  ahb_slv_out_type);
end component;

component top_noc
	 generic (
    leon_hindex : integer := 0;
    leon_haddr  : integer := 16#200#;
    hmask       : integer := 16#0ff#;
	 io_hindex   : integer := 0;
    io_haddr    : integer := 16#200#;
	 dbg			 : std_logic := '0');
    port (
    rst     : in  std_logic;
    clk     : in  std_logic;
	 le_irq	: out std_logic;
	 io_irq	: out std_logic;
    le_slvi  : in   ahb_slv_in_type;
    le_slvo  : out  ahb_slv_out_type;
	 io_slvi    : in   ahb_slv_in_type;
    io_slvo    : out  ahb_slv_out_type);
end component;

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