library ieee;
use ieee.std_logic_1164.all;

entity cdc_pulse is
port (
	clk_d : in std_logic;
	d : in std_logic;
	clk_q : in std_logic;
	q : out std_logic
);
end entity;

architecture rtl of cdc_pulse is
	signal d_d : std_logic:='0';
	signal d_edge : std_logic:='0';
	signal d_q,d_q2,d_q3 : std_logic;

begin

	-- Invert d_edge every time we see a rising edge on d.
	process(clk_d) begin
		if rising_edge(clk_d) then
			d_d<=d;
			if d='1' and d_d='0' then
				d_edge<=not d_edge;
			end if;
		end if;
	end process;

	-- Sync d_edge to clk_q, and emit a pulse any time it changes.
	process(clk_q) begin
		if rising_edge(clk_q) then
			d_q<=d_edge;
			d_q2<=d_q;
			d_q3<=d_q2;
			q <= d_q3 xor d_q2;
		end if;
	end process;
end;

