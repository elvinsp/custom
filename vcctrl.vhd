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
				 caddr : integer := 16#C00#;
				 cmask : integer := 16#fff#;
				 memaddr : integer := 16#600#;
				 memmask : integer := 16#fff#;
				 ioaddr : integer := 16#800#;
				 iomask : integer := 16#fff#);
    Port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  acwr : out std_logic;
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
  0 => ahb_device_reg ( 16#01#, 16#016#, 0, 0, 0), --ahb_device_reg (VENDOR_EXAMPLE, EXAMPLE_AHBRAM, 0, 0, 0)
  4 => ahb_membar(caddr, '0', '0', cmask), -- ahb_memaddr(memaddr, '0', '0', memmask), others => X"00000000");
  others => zero32);

constant baddr : std_logic_vector(23 downto 0) := conv_std_logic_vector(caddr,12)&x"000"; -- bit 31 downto 8 for compare with haddr
  
type store is array (0 to 63) of std_logic_vector(31 downto 0);
signal datastore : store;
constant storemask : store := (0 => x"ffbfffff", 1 => x"ffffffff", 2 => x"ffffffff", 3 => x"ffffffff", 4 => x"ffffffff", others => (others => '0'));
constant pagebase : integer := 8;
signal co_r, co_a, eo_r, eo_a : std_logic;
signal co, eo : noc_transfer_reg;

begin

vni_proc: process (clk, res)
variable mo_r, so_r, cready, mready, sready : std_logic; -- master out, slave out;
begin
	if(res = '0') then
		mready := '0';
		sready := '0';
		cready := '0';
		co_r <= '0';
		co <= noc_transfer_none;
		eo_a <= '0';
		mo_r := '0';
		so_r := '0';
		vcmo_r <= '0';
		vcmo <= noc_transfer_none;
		vcso_r <= '0';
		vcso <= noc_transfer_none;
		vcni_a <= '0';
	elsif(clk'event and clk = '1') then
		if(co_r = '1') then
			cready := '1';
		end if;
		if(mo_r = '1') then
			mready := '1';
		end if;
		if(so_r = '1') then
			sready := '1';
		end if;
		if(eo_r = '1') then
			vcso <= eo;
			so_r := '1';
			sready := '0';
			eo_a <= '1';
		elsif(vcni_r = '1') then
			if((vcni.flit(0)(31 downto 28) = "0100" or vcni.flit(0)(31 downto 28) = "0101" or vcni.flit(0)(31 downto 28) = "0011") and vcni.flit(0)(27 downto 24) = "1111") then
				---- for vcctrl internal use
				if(co_r = '0') then
					co <= vcni;
					co_r <= '1';
					cready := '0';
					vcni_a <= '1';
				end if;
			elsif((vcni.flit(0)(31 downto 28) = "0010" or vcni.flit(0)(31 downto 28) = "0100") and mo_r = '0') then
				vcmo <= vcni;
				mo_r := '1';
				mready := '0';
				vcni_a <= '1';
			elsif(vcni.flit(0)(31 downto 28) = "0011" and so_r = '0') then
				----- inject timeout here
				vcso <= vcni;
				so_r := '1';
				sready := '0';
				vcni_a <= '1';
			end if;
		end if;
		------------------------------------
		if(vcni_r = '0') then
			vcni_a <= '0';
		end if;
		if(vcmo_a = '1' and mready = '1') then
			mo_r := '0';
			vcmo <= noc_transfer_none;
		end if;
		if(vcso_a = '1' and sready = '1') then
			so_r := '0';
			vcso <= noc_transfer_none;
		end if;
		if(co_a = '1' and cready = '1') then
			co_r <= '0';
			co <= noc_transfer_none;
		end if;
		------------------------------------
		vcso_r <= so_r;
		vcmo_r <= mo_r;
	end if;
end process vni_proc;

vno_proc: process (clk, res)
variable no_r, rr, nready, eready : std_logic;
variable mcmp, iocmp, faddr, fmask : std_logic_vector(11 downto 0);
variable pagenr, maskstart, cstate : integer;
variable timer : integer;
variable slvsave : std_logic_vector(31 downto 0);
constant ntr_config : noc_transfer_reg := (len => "010", addr => "0000", flit => (x"2F002E00", others => (others => '0')));
constant ntr_remote : noc_transfer_reg := (len => "010", addr => "0000", flit => (x"4F000000", others => (others => '0')));
begin
	if(res = '0') then
		mcmp := (others => '0');
		iocmp := (others => '0');
		faddr := (others => '0');
		fmask := (others => '0');
		pagenr := 0;
		maskstart := 0;
		cstate := 0;
		rr := '0';
		no_r := '0';
		nready := '0';
		eready := '0';
		eo_r <= '0';
		eo <= noc_transfer_none;
		vcmi_a <= '0';
		vcsi_a <= '0';
		vcno_r <= '0';
		vcno <= noc_transfer_none;
		timer := 0;
		slvsave := (others => '0');
	elsif(clk'event and clk = '1') then
		if(rr = '1' and vcsi_r = '0') then
			rr := '0';
		end if;
		if(no_r = '1') then 
			---- vcno_a reset (1/2)
			nready := '1';
		end if;
		if(eo_r = '1') then
			eready := '1';
		end if;
		if(datastore(0)(23) = '1' and datastore(0)(22) = '0') then -- datastore(0)(23) load; datastore(0)(22) load complete
-- Page Table Load
			if(no_r = '0') then
				if(cstate = 0) then
					vcno <= ntr_config;
					vcno.flit(0)(23 downto 20) <= conv_std_logic_vector(cstate,4);
					vcno.flit(1) <= datastore(1);
					no_r := '1';
					cstate := 1;
				elsif(cstate = 1) then
					vcno <= ntr_config;
					vcno.flit(0)(23 downto 20) <= conv_std_logic_vector(cstate,4);
					vcno.flit(0)(7 downto 5) <= "001";
					vcno.flit(1) <= datastore(1);
					vcno.flit(1)(9 downto 0) <= conv_std_logic_vector(conv_integer(datastore(1)(9 downto 0))+4,10);
					no_r := '1';
					cstate := 2;
				elsif(cstate = 2) then
					vcno <= ntr_config;
					vcno.flit(0)(23 downto 20) <= conv_std_logic_vector(cstate,4);
					vcno.flit(0)(7 downto 5) <= "001";
					vcno.flit(1) <= datastore(1);
					vcno.flit(1)(9 downto 0) <= conv_std_logic_vector(conv_integer(datastore(1)(9 downto 0))+20,10);
					no_r := '1';
					cstate := 3;
				elsif(cstate = 3) then
					vcno <= ntr_config;
					vcno.flit(0)(23 downto 20) <= conv_std_logic_vector(cstate,4);
					vcno.flit(0)(7 downto 5) <= "001";
					vcno.flit(1) <= datastore(1);
					vcno.flit(1)(9 downto 0) <= conv_std_logic_vector(conv_integer(datastore(1)(9 downto 0))+36,10);
					no_r := '1';
					cstate := 4;
				elsif(cstate = 4) then
					vcno <= ntr_config;
					vcno.flit(0)(23 downto 20) <= conv_std_logic_vector(cstate,4);
					vcno.flit(0)(7 downto 5) <= "001";
					vcno.flit(1) <= datastore(1);
					vcno.flit(1)(9 downto 0) <= conv_std_logic_vector(conv_integer(datastore(1)(9 downto 0))+52,10);
					no_r := '1';
					cstate := 5;
				end if;
				vcno.addr <= conv_std_logic_vector(5,4);
			end if;
			-- no_r --
		elsif(datastore(0)(22 downto 21) = "11") then -- datastore(0)(21) remote config
			if(no_r = '0') then
-- Remote Config Ack
				vcno <= ntr_remote;
				vcno.flit(0)(31 downto 28) <= "0101";
				vcno.addr <= datastore(0)(19 downto 16);
				vcno.len <= "001";
				no_r := '1';
			end if;
		elsif(datastore(4)(31) = '1') then -- send remote config
-- Remote Config
			if(no_r = '0') then
				vcno <= ntr_remote;
				vcno.addr <= datastore(4)(27 downto 24);
				vcno.flit(1) <= datastore(5);
				no_r := '1';
			end if;
		elsif(vcmi_r = '1' and no_r = '0' and rr = '0') then
-- Master to Network
			rr := '1';
			vcno <= vcmi;
			no_r := '1';
			vcmi_a <= '1';
		elsif(vcsi_r = '1' and no_r = '0' and eo_r = '0') then
-- Slave to Network
			pagenr := 0;
			maskstart := 0;
			faddr := vcsi.flit(1)(31 downto 20);
			---- get compare value which page table Memory/IO ----
			fmask := conv_std_logic_vector(iomask,12);
			for I in 0 to 11 loop
				iocmp(I) := faddr(I) and fmask(I);
			end loop;
			fmask := conv_std_logic_vector(memmask,12);
			for I in 0 to 11 loop
				mcmp(I) := faddr(I) and fmask(I);
			end loop;
			---- find out value which page table Memory/IO -------------------------------------------------------------
			if(iocmp = conv_std_logic_vector(ioaddr,12)) then
				for I in 12 to 31 loop
					---- Gaisler GRIP 12bit APB Range set in ahbctrl
					if(datastore(pagebase)(I) = '1' and maskstart = 0) then
						maskstart := I;
					end if;
				end loop;
				if(maskstart = 0) then
					maskstart := 32;
				end if;
				pagenr := conv_integer(vcsi.flit(1)(maskstart-1 downto maskstart-4));
				if(datastore(pagenr+pagebase+1) /= x"ffffffff") then
					vcno <= vcsi;
					vcno.addr <= conv_std_logic_vector(3,4);
					for I in 31 downto 8 loop
						-- (page entry and not page mask) or (page mask and haddr)
						vcno.flit(1)(I) <= (datastore(pagenr+1+pagebase)(I) and datastore(pagebase)(I)) or (not datastore(pagebase)(I) and vcsi.flit(1)(I));
					end loop;
					no_r := '1';
				else
					---- error handling; page non existent
					eo.len <= "010";
					eo.flit(0) <= vcsi.flit(0);
					eo.flit(0)(31 downto 28) <= "0011";
					eo.flit(0)(1 downto 0) <= "01";
					eo.flit(1) <= x"ffffffff";
					eo_r <= '1';
				end if;
				vcsi_a <= '1';
			elsif(mcmp = conv_std_logic_vector(memaddr,12)) then
				---- not really implemented
				vcno <= vcsi;
				vcno.addr <= conv_std_logic_vector(4,4);
				no_r := '1';
				vcsi_a <= '1';
			else
				---- return error if read else dump it without notice if no ack required
				vcsi_a <= '1';
			end if;
		end if;
		---------------------------------
		if(vcno_a = '1' and nready = '1') then
			---- vcno_a reset (2/2)
			no_r := '0';
			nready := '0';
			vcno <= noc_transfer_none;
		end if;
		---------------------------------
		if(eo_a = '1' and eready = '1') then
			eo_r <= '0';
			eready := '0';
			eo <= noc_transfer_none;
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
variable loadstate : std_logic_vector(4 downto 0);
begin
	if(res = '0') then
		ahbso <= ahbs_none;
		tslv := ahbs_none;
		bstate := 0; -- no bursts
		vaddr := x"00";
		vincr := 0;
		vwrite := '0';
		datastore <= (others => (others => '0'));
		datastore(pagebase) <= x"ffffffff";
		co_a <= '0';
		loadstate := (others => '0');
	elsif(clk'event and clk = '1') then
		---- Remote Input --------------------------------------------------
		if(co_r = '1') then
			if(co.flit(0)(31 downto 28) = "0011") then
				if(co.flit(0)(23 downto 20) = "0000") then
					datastore(pagebase) <= co.flit(1);
					loadstate(0) := '1';
				elsif(co.flit(0)(23 downto 20) = "0001") then
					datastore(pagebase+1) <= co.flit(1);
					datastore(pagebase+2) <= co.flit(2);
					datastore(pagebase+3) <= co.flit(3);
					datastore(pagebase+4) <= co.flit(4);
					loadstate(1) := '1';
				elsif(co.flit(0)(23 downto 20) = "0010") then
					datastore(pagebase+5) <= co.flit(1);
					datastore(pagebase+6) <= co.flit(2);
					datastore(pagebase+7) <= co.flit(3);
					datastore(pagebase+8) <= co.flit(4);
					loadstate(2) := '1';
				elsif(co.flit(0)(23 downto 20) = "0011") then
					datastore(pagebase+9) <= co.flit(1);
					datastore(pagebase+10) <= co.flit(2);
					datastore(pagebase+11) <= co.flit(3);
					datastore(pagebase+12) <= co.flit(4);
					loadstate(3) := '1';
				elsif(co.flit(0)(23 downto 20) = "0100") then
					datastore(pagebase+13) <= co.flit(1);
					datastore(pagebase+14) <= co.flit(2);
					datastore(pagebase+15) <= co.flit(3);
					datastore(pagebase+16) <= co.flit(4);
					loadstate(4) := '1';
				end if;
			elsif(co.flit(0)(31 downto 28) = "0100") then
				datastore(1) <= co.flit(1);
				datastore(0)(23) <= '1'; -- load page table
				datastore(0)(21) <= '1'; -- remote config active
				datastore(0)(19 downto 16) <= co.addr;
			elsif(co.flit(0)(31 downto 28) = "0101") then
				datastore(4)(31) <= '0'; -- deactivate send bit
				datastore(4)(30) <= '1'; -- remote config completed
				datastore(4)(27 downto 24) <= "0000";
			end if;
			co_a <= '1';
		else
			co_a <= '0';
		end if;
		if(loadstate(0) = '1' and loadstate(1) = '1' and loadstate(2) = '1' and loadstate(3) = '1' and loadstate(4) = '1') then
			datastore(0)(22) <= '1'; -- load complete
			datastore(0)(23) <= '0'; -- deactivate load bit
			loadstate := (others => '0');
		end if;
		if(datastore(4)(31) = '1') then
			datastore(4)(30) <= '0'; -- when send bit is active, complete bit can't
		end if;
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
	acwr <= datastore(0)(0);
	
end process vcctrl_proc;

end Behavioral;
