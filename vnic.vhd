----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:26:53 12/27/2015 
-- Design Name: 
-- Module Name:    vnic - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vnic is
	 generic (nic_hindex : integer := 0);
    port ( res : in  STD_LOGIC;
           clk : in  STD_LOGIC;
			  nic_irq : in std_logic;
			  nico : in ahb_slv_out_type;
			  nici : out ahb_slv_in_type;
			  --msti : in  ahb_mst_in_type;
			  --msto : out ahb_mst_out_type;
			  slvi : in ahb_slv_in_type;
			  slvo : out ahb_slv_out_type);
end vnic;

architecture Behavioral of vnic is

-- typedefs
type flits is array (0 to 4) of std_logic_vector(31 downto 0);
type noc_transfer_reg is record
	state : std_logic_vector(31 downto 0);
	flit :  flits;
end record;

-- constants
constant flit_none : flits := ((others => '0'), (others => '0'), (others => '0'), (others => '0'), (others => '0'));
constant noc_transfer_none : noc_transfer_reg := ((others => '0'), flit_none);

-- signals
signal noc_rx, noc_tx : noc_transfer_reg; -- data handover register from NI-AHB-Interface to processing
signal noc_rx_ready, noc_rx_ack, noc_tx_ready, noc_tx_ack, nic_start : std_logic; -- handshake signals for data handover
signal cstate : std_logic_vector(1 downto 0);
signal cstart : std_logic;

begin

nic_inf: process(clk, res)
variable rxstate : integer range 0 to 7;
variable txstate : integer range 0 to 8;
variable tnic : ahb_slv_in_type;
variable rnic : ahb_slv_out_type;
variable noc_rx_reg, noc_tx_reg : noc_transfer_reg;
variable state : std_logic_vector(1 downto 0);
variable rbase : std_logic_vector(31 downto 0);
constant tbase : std_logic_vector(31 downto 0) := x"60000010";
variable rw, start : std_logic;
variable flit_index : integer range 0 to 4;
begin
	if(res = '0') then
		noc_rx <= noc_transfer_none;
		noc_rx_ready <= '0';
		noc_tx_ack <= '0';
		noc_rx_reg := noc_transfer_none;
		
		nic_start <= '0';
		tnic := ahbs_in_none;
		rnic := ahbs_none;
		
		rbase := x"60000070"; -- will be set to x"60000030" immediately
		rxstate := 0;
		txstate := 0;
		state := "00";
		flit_index := 0;
	elsif(clk'event and clk = '1') then
		if(cstart = '1') then
			state := cstate;
			nic_start <= '1';
		end if;
		if(noc_tx_ready = '1') then
			noc_tx_reg := noc_tx;
			noc_tx_ack <= '1';
		else
			noc_tx_ack <= '0';
		end if;
		rnic := nico;
		if(state = "01") then
			txstate := 0;
			if(rnic.hresp = "00" and rnic.hready = '1') then -- Slave OKAY Response
				tnic.hsel(nic_hindex) := '1';
				tnic.htrans := "10";
				tnic.hsize := "010";
				if(rxstate = 0) then
					-- set next RX Buffer
					if(rbase = x"60000030") then rbase := x"60000050";
					elsif(rbase = x"60000050") then rbase := x"60000070";
					elsif(rbase = x"60000070") then rbase := x"60000030"; -- first case after reset
					end if;
					tnic.hwrite := '0';
					tnic.haddr := rbase; -- start address for new rx buffer sequence
					tnic.hwdata(31 downto 0) := x"00000000"; -- reset rx buffer from previous sequence if there was one			
					rxstate := 1;
					flit_index := 0;
				elsif(rxstate = 1) then
					tnic.hwrite := '0';
					tnic.haddr := rbase + x"00000004"; -- Request 1st Flit
					rxstate := 2;
				elsif(rxstate = 2) then
					tnic.hwrite := '0';
					tnic.haddr := rbase + x"00000008"; -- Request 2nd Flit
					noc_rx_reg.state := rnic.hrdata(31 downto 0); -- Receive NoC RX State; Determine Flit amount!
					rxstate := 3;
				elsif(rxstate = 3) then
					tnic.hwrite := '0';
					tnic.haddr := rbase + x"0000000c"; -- Request 3rd Flit
					noc_rx_reg.flit(flit_index) := rnic.hrdata(31 downto 0); -- Receive 1st Flit
					flit_index := flit_index + 1;
					rxstate := 4;
				elsif(rxstate = 4) then
					tnic.hwrite := '0';
					tnic.haddr := rbase + x"00000010"; -- Request 4th Flit
					noc_rx_reg.flit(flit_index) := rnic.hrdata(31 downto 0); -- Receive 2nd Flit
					flit_index := flit_index + 1;
					rxstate := 5;
				elsif(rxstate = 5) then
					tnic.hwrite := '0';
					tnic.haddr := rbase + x"00000014"; -- Request 5th Flit
					noc_rx_reg.flit(flit_index) := rnic.hrdata(31 downto 0);	-- Receive 3rd Flit
					flit_index := flit_index + 1;
					rxstate := 6; -- start in next Buffer
				elsif(rxstate = 6) then
					tnic.hwrite := '1';
					tnic.haddr := rbase; -- Select NoC RX State Register to Set Acknowledge
					noc_rx_reg.flit(flit_index) := rnic.hrdata(31 downto 0); -- Receive 4th Flit
					flit_index := flit_index + 1;
					rxstate := 7; -- start in next Buffer
				elsif(rxstate = 7) then
					tnic.hsel(nic_hindex) := '0';
					tnic.haddr := x"00000000";
					noc_rx_reg.flit(flit_index) := rnic.hrdata(31 downto 0); -- Receive 5th flit
					noc_rx <= noc_rx_reg;
					noc_rx_ready <= '1';
					nic_start <= '0';
					state := "00";
				end if;
			elsif(rnic.hresp = "01") then
			end if;
		--------------------------------------------------------------------------
		elsif(state = "10") then
			rxstate := 0;
			if(rnic.hresp = "00" and rnic.hready = '1') then -- Slave OKAY Response
				tnic.hsel(nic_hindex) := '1';
				tnic.htrans := "10";
				tnic.hsize := "010";
				if(txstate = 0) then
					tnic.hwrite := '0';
					tnic.haddr := tbase; -- start address for new tx buffer sequence
					tnic.hwdata(31 downto 0) := x"00000000"; -- reset tx buffer from previous sequence if there was one			
					txstate := 1;
					flit_index := 0;
				elsif(txstate = 1) then
					tnic.htrans := "00";
					tnic.haddr := x"00000000";
					txstate := 2;
				elsif(txstate = 2) then
					if(rnic.hrdata(7) = '1') then 
						nic_start <= '0';
						state := "00";
					else
						tnic.hwrite := '1';
						tnic.haddr := tbase + x"00000004"; -- Select 1st Flit
						txstate := 3;
					end if;
				elsif(txstate = 3) then
					tnic.hwrite := '1';
					tnic.haddr := tbase + x"00000008"; -- Select 2nd Flit
					tnic.hwdata(31 downto 0):= noc_tx_reg.flit(flit_index); -- Write 1st Flit
					flit_index := flit_index + 1;
					txstate := 4;
				elsif(txstate = 4) then
					tnic.hwrite := '1';
					tnic.haddr := tbase + x"0000000c"; -- Select 3nd Flit
					tnic.hwdata(31 downto 0):= noc_tx_reg.flit(flit_index); -- Write 2nd Flit
					flit_index := flit_index + 1;
					txstate := 5;
				elsif(txstate = 5) then
					tnic.hwrite := '1';
					tnic.haddr := tbase + x"00000010"; -- Select 4th Flit
					tnic.hwdata(31 downto 0):= noc_tx_reg.flit(flit_index); -- Write 3rd Flit
					flit_index := flit_index + 1;
					txstate := 6; -- start in next Buffer
				elsif(txstate = 6) then
					tnic.hwrite := '1';
					tnic.haddr := tbase + x"00000014"; -- Select 5th Flit
					tnic.hwdata(31 downto 0):= noc_tx_reg.flit(flit_index); -- Write 4th Flit
					flit_index := flit_index + 1;
					txstate := 7; -- start in next Buffer
				elsif(txstate = 7) then
					tnic.hwrite := '1';
					tnic.haddr := tbase; -- Select TX state register	
					tnic.hwdata(31 downto 0):= noc_tx_reg.flit(flit_index); -- Write 5th Flit
					flit_index := flit_index + 1;
					txstate := 8;
				elsif(txstate = 8) then
					tnic.hsel(nic_hindex) := '0';
					tnic.hwdata(18 downto 16) := noc_tx_reg.state(18 downto 16);
					tnic.hwdata(6) := '1';
					nic_start <= '0';
					state := "00";
				end if;
			elsif(rnic.hresp = "01") then
				-- go back 2 states and retry
			end if;
		else
			tnic := ahbs_in_none;
			txstate := 0;
			rxstate := 0;
		end if;
		if(noc_rx_ack = '1') then noc_rx_ready <= '0';
		end if;
	nici <= tnic;
	end if;	
end process nic_inf;

vnic_control: process(clk, res)
variable rr : integer range 0 to 1;
variable start : std_logic;
begin
	if(res = '0') then
		rr := 0;
		start := '0';
		cstart <= '0';
		cstate <= "00";
	elsif(clk'event and clk = '1') then
		if(nic_start = '1') then
			start := '0';
		end if;
		if(rr = 1) then
			if(nic_start = '0' and start = '0') then
				if(nic_irq = '1') then
					cstate <= "01";
					start := '1';
				else
					cstate <= "00";
				end if;
			end if;
			rr := 0;
		else
			if(nic_start = '0' and start = '0') then
				if(noc_tx_ready = '1') then
					cstate <= "10";
					start := '1';
				else
					cstate <= "00";
				end if;
			end if;
			rr := 1;
		end if;
		cstart <= start;
	end if;
end process vnic_control;

packetizer: process(clk, res)
begin
	if(res = '0') then 
		noc_tx_ready <= '0';
		noc_rx_ack <= '0';
	elsif(clk'event and clk = '1') then
		if(noc_rx_ready = '1') then 
			noc_tx <= noc_rx;
			noc_rx_ack <= '1';
			noc_tx_ready <= '1';
		else
			noc_rx_ack <= '0';
		end if;
		if(noc_tx_ack = '1') then noc_tx_ready <= '0';
		end if;
	end if;
end process packetizer;

end Behavioral;

