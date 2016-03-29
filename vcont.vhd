----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:27:51 03/11/2016 
-- Design Name: 
-- Module Name:    vcont - Behavioral 
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
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
library gaisler;
use gaisler.custom.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vcont is
	 Generic ( mindex : integer; -- master index
				sindex : integer;   -- slave index
				cindex : integer;   -- config index (slave)
				membar : integer := 16#600#;
				memmask : integer := 16#fff#;
				iobar : integer := 16#B00#;
				iomask : integer := 16#fff#;
				cbar : integer := 16#B08#;
				cmask : integer := 16#fff#);
    Port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  ahbmi : in ahb_mst_in_type;
			  ahbmo : out ahb_mst_out_type;
			  ahbsi : in ahb_slv_in_type;
			  ahbso : out ahb_slv_out_type;
			  ahbco : out ahb_slv_out_type;
			  vcni_r : in std_logic;
			  vcni_a : out std_logic;
			  vcni : in noc_transfer_reg;
			  vcno_r : out std_logic;
			  vcno_a : in std_logic;
			  vcno : out noc_transfer_reg);
end vcont;

architecture Behavioral of vcont is

signal vcmc, vccm, vccs, vcsc : noc_transfer_reg := noc_transfer_none;
signal vcmc_ready, vcmc_ack, vccm_ready, vccm_ack : std_logic := '0'; -- master out, master in
signal vccs_ready, vccs_ack, vcsc_ready, vcsc_ack : std_logic := '0'; -- slave out, slave in

begin

	vcont_mst : vcmst
		generic map(hindex => mindex)
		port map(res, clk, vccm_ready, vccm_ack, vccm, vcmc_ready, vcmc_ack, vcmc, ahbmi, ahbmo);
	vcont_slv: vcslv
		generic map(hindex => sindex, mindex => mindex, membar => membar, memmask => memmask, iobar => iobar, iomask => iomask)
		port map(res, clk, vcsc_ready, vcsc_ack, vcsc, vccs_ready, vccs_ack, vccs, ahbsi, ahbso);
	vcont_vcctrl : vcctrl
		generic map( hindex => cindex, cbar => cbar, cmask => cmask, membar => membar, memmask => memmask, iobar => iobar, iomask => iomask)
		port map( res, clk, ahbsi, ahbco, vcmc_ready, vcmc_ack, vcmc, vccm_ready, vccm_ack, vccm, vcsc_ready, vcsc_ack, vcsc, vccs_ready, vccs_ack, vccs, vcni_r, vcni_a, vcni, vcno_r, vcno_a, vcno);
		
end Behavioral;

