-- A minimalist FIFO-based video buffer
--
-- Copyright 2020 by Alastair M. Robinson
--
-- 512 words of 16 bit each to fill one M9K
-- On vblank, reset inpointer and start filling.
-- Thereafter, compare inptr with outptr and fill any time they differ.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity VideoStream is
generic
(
	fifodepth : integer := 9; -- 512 entries deep by default
	burstdepth : integer := 3; -- Eight word bursts
	signalwidth : integer := 16 -- Sixteen bits wide
);
port
(
	clk : in std_logic;
	reset_n : in std_logic;
	enable : in std_logic;
	-- RAM interface
	baseaddr : in std_logic_vector(25 downto 0);
	a : out std_logic_vector(25 downto 0);
	req : out std_logic;
	ack : in std_logic;
	pri : out std_logic;
	d : in std_logic_vector(signalwidth-1 downto 0);
	fill : in std_logic;
	-- Display interface
	rdreq : in std_logic;
	q : out std_logic_vector(signalwidth-1 downto 0)
);
end entity;

architecture rtl of VideoStream is

type samplebuffer is array(0 to 2**fifodepth-1) of std_logic_vector(signalwidth-1 downto 0);
signal buf : samplebuffer;
attribute syn_ramstyle : string;
attribute syn_ramstyle of buf : signal is "block_ram";
signal inptr : unsigned(fifodepth-1 downto 0);
signal outptr : unsigned(fifodepth-1 downto 0);
signal watermark : unsigned(fifodepth-1 downto 0);
signal fetch_address : unsigned(25 downto 0);
signal nearfull : std_logic;
signal hungry : std_logic;
begin

-- Accounting
process(clk) begin
	if rising_edge(clk) then

		if fill='1' and rdreq='0' then
			watermark <= watermark + 1;
		end if;
		
		if fill='0' and rdreq='1' then
			watermark <= watermark - 1;
		end if;
		
		if reset_n='0' then
			watermark <= (others => '0');
		end if;

	end if;
end process;

nearfull <= '1' when watermark(watermark'high downto (burstdepth+2)) = to_unsigned(2**(fifodepth-(burstdepth+2))-1,fifodepth-(burstdepth+2)) else '0';

hungry <= not watermark(fifodepth-1);


-- Fill from RAM

process(clk)
begin
	if rising_edge(clk) then

		if fill='1' then
			buf(to_integer(inptr))<=d;
			inptr<=inptr+1;
		end if;

		if ack='1' then	-- Advance the fetch address when the controller acknowledges the request
			fetch_address<=fetch_address + ((signalwidth/8) * 2**burstdepth);
		end if;

		if reset_n='0' then
			fetch_address <= unsigned(baseaddr);
			inptr <= (others => '0');
		end if;
	end if;
end process;

a<=std_logic_vector(fetch_address);

process(clk)
begin
	if rising_edge(clk) then
		req<=reset_n and enable and not nearfull;
		pri<=hungry and enable;
	end if;
end process;

-- Output to video

process(clk)
begin
	if rising_edge(clk) then
		if rdreq='1' then
			outptr<=outptr+1;
		end if;

		if reset_n='0' then
			outptr<=(others => '0');
		end if;

		q<=buf(to_integer(outptr));
	end if;
end process;


end architecture;

