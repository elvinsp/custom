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

entity vcctrl is
    generic( hindex : integer := 0;
				 cbar : integer := 16#C00#;
				 cmask : integer := 16#fff#;
				 membar : integer := 16#600#;
				 memmask : integer := 16#fff#;
				 iobar : integer := 16#800#;
				 iomask : integer := 16#fff#);
    Port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  ahbsi : in ahb_slv_in_type;
			  ahbso : out ahb_slv_out_type;
			  vcmi_r : in std_logic; -- virtual controller master input ready
			  vcmi_a : out std_logic; -- virtual controller master input acknowledge
			  vcmi : in noc_transfer_reg; -- virutal controller master input
			  vcmo_r : out std_logic;
			  vcmo_a : in std_logic;
			  vcmo : out noc_transfer_reg;
			  vcsi_r : in std_logic;
			  vcsi_a : out std_logic;
			  vcsi : in noc_transfer_reg;
			  vcso_r : out std_logic; -- virtual controller slave output ready
			  vcso_a : in std_logic; -- virutal controller slave output acknowledge
			  vcso : out noc_transfer_reg; -- virtual controller slave output
			  vcni_r : in std_logic; 
			  vcni_a : out std_logic;
			  vcni : in noc_transfer_reg;
			  vcno_r : out std_logic; -- virtual controller network output ready
			  vcno_a : in std_logic; -- virtual controller network output acknowledge
			  vcno : out noc_transfer_reg); -- virtual controller network output
end vcctrl;

architecture Behavioral of vcctrl is

constant hconfig : ahb_config_type := (
  0 => ahb_device_reg ( 16#01#, 16#01B#, 0, 0, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
  4 => ahb_membar(cbar, '0', '0', cmask), -- ahb_membar(memaddr, '0', '0', memmask), others => X"00000000");
  others => zero32);

constant baddr : std_logic_vector(23 downto 0) := conv_std_logic_vector(cbar,12)&x"000"; -- bit 31 downto 8 for compare with haddr
  
type store is array (0 to 63) of std_logic_vector(31 downto 0);
signal datastore : store;

begin

vni_proc: process (clk, res)
variable mo_r, so_r : std_logic; -- master out, slave out;
begin
	if(res = '0') then
		mo_r := '0';
		so_r := '0';
		vcmo_r <= '0';
		vcso_r <= '0';
		vcni_a <= '0';
	elsif(clk'event and clk = '1') then
		if(vcni_r = '1') then
			if(vcni.flit(0)(31 downto 28) = "0010" and mo_r = '0') then
				vcmo <= vcni;
				mo_r := '1';
				vcni_a <= '1';
			elsif(vcni.flit(0)(31 downto 28) = "0011" and so_r = '0') then
				vcso <= vcni;
				so_r := '1';
				vcni_a <= '1';
			end if;
		end if;
		------------------------------------
		if(vcni_r = '0') then
			vcni_a <= '0';
		end if;
		if(vcmo_a = '1') then
			mo_r := '0';
		end if;
		if(vcso_a = '1') then
			so_r := '0';
		end if;
		------------------------------------
		vcso_r <= so_r;
		vcmo_r <= mo_r;
	end if;
end process vni_proc;

vno_proc: process (clk, res)
variable no_r, mo_r, so_r, rr : std_logic;
variable mcmp, iocmp, tmp1, tmp2 : std_logic_vector(11 downto 0);
variable pagenr : std_logic_vector(2 downto 0);
variable index, sum : integer;
begin
	if(res = '0') then
		pagenr := "000";
		mcmp := (others => '0');
		iocmp := (others => '0');
		tmp1 := (others => '0');
		tmp2 := (others => '0');
		index := 0;
		sum := 0;
		rr := '0';
		no_r := '0';
		mo_r := '0';
		so_r := '0';
		vcmo <= noc_transfer_none;
		vcmi_a <= '0';
		vcmo <= noc_transfer_none;
		vcsi_a <= '0';
		vcso <= noc_transfer_none;
		vcno_r <= '0';
		vcno <= noc_transfer_none;
	elsif(clk'event and clk = '1') then
		if(rr = '1' and vcsi_r = '0') then
			rr := '0';
		end if;
		if(vcmi_r = '1' and no_r = '0' and rr = '0') then
			rr := '1';
			vcno <= vcmi;
			no_r := '1';
			vcmi_a <= '1';
		elsif(vcsi_r = '1' and no_r = '0') then
			index := 0;
			sum := 0;
			tmp1 := vcsi.flit(1)(31 downto 20);
			---- get compare value which page table Memory/IO ----
			tmp2 := conv_std_logic_vector(iomask,12);
			for I in 0 to 11 loop
				iocmp(I) := tmp1(I) and tmp2(I);
			end loop;
			tmp2 := conv_std_logic_vector(memmask,12);
			for I in 0 to 11 loop
				mcmp(I) := tmp1(I) and tmp2(I);
			end loop;
			---- find out value which page table Memory/IO ----
			if(mcmp = conv_std_logic_vector(membar,12)) then
				for I in 20 to 31 loop
					if(datastore(0)(I) = '1') then
						sum := sum + 1;
					end if;
				end loop;
				if(sum /= 0) then
					--index := conv_integer(vcsi.flit(1)(index+2 downto index));
					vcno <= vcsi;
					for I in 31 downto 20 loop
						-- (page entry and not page mask) or (page mask and haddr)
						vcno.flit(1)(I) <= (datastore(1)(I) and datastore(0)(I)) or (not datastore(0)(I) and vcsi.flit(1)(I));
					end loop;
					no_r := '1';
				else
					
				end if;
				vcsi_a <= '1';
			elsif(iocmp = conv_std_logic_vector(iobar,12)) then
				vcno <= vcsi;
				for I in 31 downto 8 loop
					-- (page entry and not page mask) or (page mask and haddr)
					vcno.flit(1)(I) <= (datastore(10)(I) and datastore(9)(I)) or (not datastore(9)(I) and vcsi.flit(1)(I)); 
				end loop;
				no_r := '1';
				vcsi_a <= '1';
			else
				---- return error if read else dump it without notice if no ack required
				vcsi_a <= '1';
			end if;
		end if;
		---------------------------------
		if(vcno_a = '1') then
			no_r := '0';
		end if;
		---------------------------------
		if(vcmi_r = '0') then
			vcmi_a <= '0';
		end if;
		---------------------------------
		if(vcsi_r = '0') then
			vcsi_a <= '0';
		end if;
		---------------------------------
		vcno_r <= no_r;
	end if;
end process vno_proc;

vcctrl_proc: process(clk, res)
variable rslv : ahb_slv_in_type;
variable tslv : ahb_slv_out_type;
variable bstate : integer range 0 to 1; -- burst status
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
		datastore <= (others => (others => '0'));
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
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 24) <= rslv.hwdata(31 downto 24);
								elsif(vaddr(1 downto 0) = "01") then
									datastore(conv_integer(vaddr(7 downto 2)))(23 downto 16) <= rslv.hwdata(23 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 8) <= rslv.hwdata(15 downto 8);
								elsif(vaddr(1 downto 0) = "11") then
									datastore(conv_integer(vaddr(7 downto 2)))(7 downto 0) <= rslv.hwdata(7 downto 0);
								end if;
							---- HALFWORD
							elsif(vincr = 2) then
								if(vaddr(1 downto 0) = "00") then
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 16) <= rslv.hwdata(31 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 0) <= rslv.hwdata(15 downto 0);
								end if;
							---- WORD
							elsif(vincr = 4) then
								datastore(conv_integer(vaddr(7 downto 2))) <= rslv.hwdata(31 downto 0);
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
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 24) <= rslv.hwdata(31 downto 24);
								elsif(vaddr(1 downto 0) = "01") then
									datastore(conv_integer(vaddr(7 downto 2)))(23 downto 16) <= rslv.hwdata(23 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 8) <= rslv.hwdata(15 downto 8);
								elsif(vaddr(1 downto 0) = "11") then
									datastore(conv_integer(vaddr(7 downto 2)))(7 downto 0) <= rslv.hwdata(7 downto 0);
								end if;
							elsif(vincr = 2) then
								if(vaddr(1 downto 0) = "00") then
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 16) <= rslv.hwdata(31 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 0) <= rslv.hwdata(15 downto 0);
								end if;
							elsif(vincr = 4) then
								datastore(conv_integer(vaddr(7 downto 2))) <= rslv.hwdata(31 downto 0);
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
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 24) <= rslv.hwdata(31 downto 24);
								elsif(vaddr(1 downto 0) = "01") then
									datastore(conv_integer(vaddr(7 downto 2)))(23 downto 16) <= rslv.hwdata(23 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 8) <= rslv.hwdata(15 downto 8);
								elsif(vaddr(1 downto 0) = "11") then
									datastore(conv_integer(vaddr(7 downto 2)))(7 downto 0) <= rslv.hwdata(7 downto 0);
								end if;
							elsif(vincr = 2) then
								if(vaddr(1 downto 0) = "00") then
									datastore(conv_integer(vaddr(7 downto 2)))(31 downto 16) <= rslv.hwdata(31 downto 16);
								elsif(vaddr(1 downto 0) = "10") then
									datastore(conv_integer(vaddr(7 downto 2)))(15 downto 0) <= rslv.hwdata(15 downto 0);
								end if;
							elsif(vincr = 4) then
								datastore(conv_integer(vaddr(7 downto 2))) <= rslv.hwdata(31 downto 0);
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
	
end process vcctrl_proc;

end Behavioral;
