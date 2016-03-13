----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    01:40:16 02/07/2016 
-- Design Name: 
-- Module Name:    vcslv - Behavioral 
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

entity testreg is
    generic( hindex : integer := 0;
				 membar : integer := 16#C00#;
				 memmask : integer := 16#fff#);
    Port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  ahbsi : in ahb_slv_in_type;
			  ahbso : out ahb_slv_out_type);
end testreg;

architecture Behavioral of testreg is
constant hconfig : ahb_config_type := (
  0 => ahb_device_reg ( 16#01#, 16#01B#, 0, 0, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
  4 => ahb_membar(membar, '0', '0', memmask), -- ahb_membar(memaddr, '0', '0', memmask), others => X"00000000");
  others => zero32);

constant baddr : std_logic_vector(23 downto 0) := conv_std_logic_vector(membar,12)&x"000";
  
type store is array (0 to 63) of std_logic_vector(31 downto 0);

begin

testreg_proc: process(clk, res)
variable rslv : ahb_slv_in_type;
variable tslv : ahb_slv_out_type;
variable bstate : integer range 0 to 1; -- burst status
variable datastore : store;
variable vaddr : std_logic_vector(7 downto 0);
variable vincr : integer;
variable vwrite : std_logic;
begin
	if(res = '0') then
		ahbso <= ahbs_none;
		tslv := ahbs_none;
		bstate := 0; -- no bursts
		vaddr := x"00";
		vincr := 0;
		vwrite := '0';
		datastore := (others => (others => '0'));
	elsif(clk'event and clk = '1') then
		---- AHB -----------------------------------------------------------
		rslv := ahbsi;
		if(rslv.hsel(hindex) = '1') then
			if(tslv.hresp = "00" and tslv.hready = '1') then -- check in which response mode the slave is in
				---- HTRANS: NONSEQ ----
				if(rslv.htrans = "10") then
					-- new Burst has begun, finish up old Burst and start new one if it is a WRITE
					bstate := 0;
					if(bstate = 0) then
						bstate := 1;
						vwrite := rslv.hwrite;
						tslv.hready := '1';
						if(rslv.haddr(31 downto 8) = baddr) then
							vaddr := rslv.haddr(7 downto 0);
							---- BYTE
							if(rslv.hsize = "000") then
								vincr := 1;
							---- HALFWORD
							elsif(rslv.hsize = "001" and rslv.haddr(0) = '0') then
								vincr := 2;
							---- WORD
							elsif(rslv.hsize = "010" and rslv.haddr(1 downto 0) = "00") then
								vincr := 4;
							else
								tslv.hresp := "01";
								tslv.hready := '0';
							end if;
						else
							tslv.hresp := "01";
							tslv.hready := '0';
						end if;
						if(vwrite = '0') then
							---- BYTE
							if(vincr = 1) then
								if(vaddr(1 downto 0) = "00") then
									tslv.hrdata(31 downto 24) := datastore(conv_integer(vaddr(7 downto 2)))(31 downto 24);
								elsif(vaddr(1 downto 0) = "01") then
									tslv.hrdata(23 downto 16) := datastore(conv_integer(vaddr(7 downto 2)))(23 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									tslv.hrdata(15 downto 8) := datastore(conv_integer(vaddr(7 downto 2)))(15 downto 8);
								elsif(vaddr(1 downto 0) = "11") then
									tslv.hrdata(7 downto 0) := datastore(conv_integer(vaddr(7 downto 2)))(7 downto 0);
								end if;
							---- HALFWORD
							elsif(vincr = 2) then
								if(vaddr(1 downto 0) = "00") then
									tslv.hrdata(31 downto 16) := datastore(conv_integer(vaddr(7 downto 2)))(31 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									tslv.hrdata(15 downto 0) := datastore(conv_integer(vaddr(7 downto 2)))(15 downto 0);
								end if;
							---- WORD
							elsif(vincr = 4) then
								tslv.hrdata(31 downto 0) := datastore(conv_integer(vaddr(7 downto 2)));
							end if;
						end if;
					end if;
				---- HTRANS: SEQ ----
				elsif(rslv.htrans = "11") then
					if(bstate = 1) then
						tslv.hready := '1';
						if(vwrite = '1') then
							---- BYTE
							if(vincr = 1) then
								if(vaddr(1 downto 0) = "00") then
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 24) := rslv.hwdata(31 downto 24);
								elsif(vaddr(1 downto 0) = "01") then
									datastore(conv_integer(vaddr(7 downto 2)))(23 downto 16) := rslv.hwdata(23 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 8) := rslv.hwdata(15 downto 8);
								elsif(vaddr(1 downto 0) = "11") then
									datastore(conv_integer(vaddr(7 downto 2)))(7 downto 0) := rslv.hwdata(7 downto 0);
								end if;
							---- HALFWORD
							elsif(vincr = 2) then
								if(vaddr(1 downto 0) = "00") then
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 16) := rslv.hwdata(31 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 0) := rslv.hwdata(15 downto 0);
								end if;
							---- WORD
							elsif(vincr = 4) then
								datastore(conv_integer(vaddr(7 downto 2))) := rslv.hwdata(31 downto 0);
							end if;
						end if;
						if(rslv.haddr(31 downto 8) = baddr) then
							if(conv_integer(rslv.haddr(7 downto 0)) = conv_integer(vaddr)+vincr) then
								---- increment if incoming SEQ addr is coresponding with NONSEQ start addr
								vaddr := conv_std_logic_vector(conv_integer(vaddr)+vincr,8);
								if(vwrite = '0') then
									---- BYTE
									if(vincr = 1) then
										if(vaddr(1 downto 0) = "00") then
											tslv.hrdata(31 downto 24) := datastore(conv_integer(vaddr(7 downto 2)))(31 downto 24);
										elsif(vaddr(1 downto 0) = "01") then
											tslv.hrdata(23 downto 16) := datastore(conv_integer(vaddr(7 downto 2)))(23 downto 16);
										elsif(vaddr(1 downto 0) = "10") then
											tslv.hrdata(15 downto 8) := datastore(conv_integer(vaddr(7 downto 2)))(15 downto 8);
										elsif(vaddr(1 downto 0) = "11") then
											tslv.hrdata(7 downto 0) := datastore(conv_integer(vaddr(7 downto 2)))(7 downto 0);
										end if;
									---- HALFWORD
									elsif(vincr = 2) then
										if(vaddr(1 downto 0) = "00") then
											tslv.hrdata(31 downto 16) := datastore(conv_integer(vaddr(7 downto 2)))(31 downto 16);
										elsif(vaddr(1 downto 0) = "10") then
											tslv.hrdata(15 downto 0) := datastore(conv_integer(vaddr(7 downto 2)))(15 downto 0);
										end if;
									---- WORD
									elsif(vincr = 4) then
										tslv.hrdata(31 downto 0) := datastore(conv_integer(vaddr(7 downto 2)));
									end if;
								end if;
							end if;
						else
							tslv.hresp := "01";
							tslv.hready := '0';
						end if;
					else
						tslv.hresp := "01";
						tslv.hready := '1';
					end if;
				---- HTRANS: IDLE ----
				elsif(rslv.htrans = "00") then
					tslv := ahbs_none;
					if(bstate = 1) then
						if(vwrite = '1') then
							if(vincr = 1) then
								if(vaddr(1 downto 0) = "00") then
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 24) := rslv.hwdata(31 downto 24);
								elsif(vaddr(1 downto 0) = "01") then
									datastore(conv_integer(vaddr(7 downto 2)))(23 downto 16) := rslv.hwdata(23 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 8) := rslv.hwdata(15 downto 8);
								elsif(vaddr(1 downto 0) = "11") then
									datastore(conv_integer(vaddr(7 downto 2)))(7 downto 0) := rslv.hwdata(7 downto 0);
								end if;
							elsif(vincr = 2) then
								if(vaddr(1 downto 0) = "00") then
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 16) := rslv.hwdata(31 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 0) := rslv.hwdata(15 downto 0);
								end if;
							elsif(vincr = 4) then
								datastore(conv_integer(vaddr(7 downto 2))) := rslv.hwdata(31 downto 0);
							end if;
						end if;
					end if;
					vaddr := x"00";
					vincr := 0;
					vwrite := '0';
				end if;
				---- End of HTRANS ----
			---- ERROR/SPLIT Handling(3/3) -----------------------------------------
			elsif(tslv.hresp /= "00" and tslv.hready = '1') then
				-- 2nd cycle of two-cycle response according to AMBA Spec (Rev 2.0) Chapter 3.9.3
				if(rslv.htrans = "00") then
					tslv.hresp := "00";
				else
					tslv.hready := '0';
				end if;
			---- ERROR/SPLIT Handling(2/3) -----------------------------------------
			else
				tslv.hready := '1';
				if(tslv.hresp = "10") then
					bstate := 0;
				end if;
			end if;
		---- HSEL inactive ----
		else
			--- handle last write ---------------------------------------------------------------------???
			if(tslv.hresp /= "00" and tslv.hready = '1') then
				tslv := ahbs_none;
			elsif(tslv.hresp = "00" and tslv.hready = '1') then
				---- HTRANS: IDLE ----
				if(rslv.htrans = "00") then
					tslv := ahbs_none;
					if(bstate = 1) then
						if(vwrite = '1') then
							if(vincr = 1) then
								if(vaddr(1 downto 0) = "00") then
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 24) := rslv.hwdata(31 downto 24);
								elsif(vaddr(1 downto 0) = "01") then
									datastore(conv_integer(vaddr(7 downto 2)))(23 downto 16) := rslv.hwdata(23 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 8) := rslv.hwdata(15 downto 8);
								elsif(vaddr(1 downto 0) = "11") then
									datastore(conv_integer(vaddr(7 downto 2)))(7 downto 0) := rslv.hwdata(7 downto 0);
								end if;
							elsif(vincr = 2) then
								if(vaddr(1 downto 0) = "00") then
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 16) := rslv.hwdata(31 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 0) := rslv.hwdata(15 downto 0);
								end if;
							elsif(vincr = 4) then
								datastore(conv_integer(vaddr(7 downto 2))) := rslv.hwdata(31 downto 0);
							end if;
							---- vincr ----
						end if;
						---- vwrite ----
					end if;
					---- bstate ----
					vaddr := x"00";
					vincr := 0;
					vwrite := '0';
				end if;
				----  rslv.htrans -----
			---- tslv.hresp -----
			else
				tslv.hready := '1';
			end if;
		end if;	
		----------------------------------------------------------------------------
		ahbso <= tslv;
	end if;
	---- Gaisler AHB Plug&Play status ---------------------------------------------
	ahbso.hconfig <= hconfig;
  	ahbso.hindex  <= hindex;
	
end process testreg_proc;

end Behavioral;
