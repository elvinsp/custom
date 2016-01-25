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
    rst     : in  std_logic;
    clk     : in  std_logic;
	 le_irq	: out std_logic;
	 io_irq	: out std_logic;
    le_slvi  : in   ahb_slv_in_type;
    le_slvo  : out  ahb_slv_out_type;
	 io_slvi    : in   ahb_slv_in_type;
    io_slvo    : out  ahb_slv_out_type);
end top_noc;

architecture rtl of top_noc is

-- constant VERSION   : amba_version_type := 0;
---- plug&play configuration
-- constant hconfig : ahb_config_type := (
--  0 => ahb_device_reg ( 16#01#, 16#0E1#, 0, VERSION, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
--  4 => ahb_membar(haddr, '0', '0', hmask), -- ahb_membar(memaddr, '0', '0', memmask), others => X"00000000");
--  others => zero32);
 
signal io_transfer, le_transfer : transfer_reg;
signal lef, iof, lev, iov : std_logic; -- full&valid signal
  
begin

le_ni: nocside
	generic map(leon_hindex, '0')
	port map(rst, clk, le_irq, lef, lev, iof, iov, le_transfer, io_transfer, le_slvi, le_slvo);
	
io_ni: nocside
	generic map(io_hindex, '0')
	port map(rst, clk, io_irq, iof, iov, lef, lev, io_transfer, le_transfer, io_slvi, io_slvo);

end rtl;
