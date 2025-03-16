library ieee;
use ieee.std_logic_1164.all;

entity vjtag_reg is
generic (
	bits : integer := 32
);
port (
	-- JTAG clock domain
	tck : in std_logic;
	tdo : out std_logic;
	tdi : in std_logic;
	ce : in std_logic;
	cap : in std_logic;
	upd : in std_logic;
	shift : in std_logic;
	frd : out std_logic;
	d : in std_logic_vector(bits-1 downto 0);
	-- System clock domain
	clk_sys : in std_logic;
	q : out std_logic_vector(bits-1 downto 0);
	rd : out std_logic;
	wr : out std_logic
);
end entity;

architecture rtl of vjtag_reg is
	signal shift_next : std_logic_vector(bits-1 downto 0);
	signal shiftreg : std_logic_vector(bits-1 downto 0);
	signal tck_inv : std_logic;
begin
	tdo <= shiftreg(0);

	shift_next <= tdi & shiftreg(bits-1 downto 1);

	process(tck) begin
		if falling_edge(tck) then
			frd<='0';
			if cap='1' then
				shiftreg<=d;
				frd <= '1';
			end if;

			if shift='1' and ce='1' then
				shiftreg<=shift_next;
			end if;
		end if;
	end process;

	process(tck) begin
		if falling_edge(tck) then
			if upd='1' then
				q<=shift_next;
			end if;
		end if;
	end	process;

	-- Synchronise the update and capture signals to clk
	-- (on the falling edge of jtck)
	tck_inv <= not tck;
	cdc_udr : entity work.cdc_pulse port map ( clk_d => tck_inv, d=>upd, clk_q => clk_sys, q=>wr);
	cdc_cdr : entity work.cdc_pulse port map ( clk_d => tck_inv, d=>cap, clk_q => clk_sys, q=>rd);

end architecture;

-- Virtual JTAG wrapper for ECP5 JTAGG primitive.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ecp5u;
use ecp5u.components.all;

entity vjtag_ecp5 is
generic (
	irwidth : integer := 3;
	drwidth : integer := 32;
	depth : integer := 7
);
port (
	clk : in std_logic;
	reset_n : in std_logic;
	-- FIFO signals
	fifo_in : in std_logic_vector(drwidth-1 downto 0);
	fifo_wr : in std_logic;
	fifo_empty : out std_logic; -- Caution - not synced to clk
	fifo_full : out std_logic;
	leadin : in std_logic_vector(1 downto 0);
	
	-- Physical JTAG signals
	sys_tck : in std_logic;
	sys_tdo : out std_logic;
	sys_tdi : in std_logic;
	sys_tms : in std_logic;

	-- Virtual JTAG signals
	vir_in : in std_logic_vector(irwidth-1 downto 0);
	vir_capture : out std_logic;
	vir_out : out std_logic_vector(irwidth-1 downto 0);
	vir_update : out std_logic;
	vdr_out : out std_logic_vector(drwidth-1 downto 0);
	vdr_capture : out std_logic;
	vdr_update : out std_logic
);
end entity;

architecture rtl of vjtag_ecp5 is
	-- JTAG signals
	signal jtck,jtdi,jshift,jupdate,jrstn,jce1,jce2,jrti1,jrti2,jtdo1,jtdo2 : std_logic;
	signal jtdi_mux : std_logic;
	signal jtck_inv : std_logic;
	signal capture : std_logic_vector(1 downto 0);
	signal update : std_logic_vector(1 downto 0);
	-- FIFO signals
	signal frd_en,fempty,ffull : std_logic;
	signal fwr : std_logic_vector(drwidth-1 downto 0);
	signal frd : std_logic_vector(drwidth-1 downto 0);

begin

	fifo_empty <= fempty;
	fifo_full <= ffull;

	fifo : entity work.vjtag_fifo
	generic map (
		width => drwidth,
		depth => depth
	)
	port map(
		reset_n => reset_n,
		rd_clk => jtck,
		rd_en => frd_en,
		dout => frd,
		empty => fempty,
		
		wr_clk => clk,
		wr_en => fifo_wr,
		din => fifo_in,
		full => ffull,
		lead => leadin
	);

	jtg : component JTAGG
	port map(
		TCK => sys_tck,
		TDO => sys_tdo,
		TDI => sys_tdi,
		TMS => sys_tms,
		JTCK => jtck,
		JTDI => jtdi,
		JSHIFT => jshift,
		JUPDATE => jupdate,
		JRSTN => jrstn,
		JCE1 => jce1,
		JCE2 => jce2,
		JRTI1 => jrti1,
		JRTI2 => jrti2,
		JTDO1 => jtdo1,
		JTDO2 => jtdo2
	);

	jtck_inv<=not jtck;

	-- separate the Create capture and update signals for the two channels

	jtagctrl : block
		signal jtdi_latched : std_logic;
		signal jshift_d : std_logic;
		signal selectedreg : std_logic;
	begin
		jtdi_mux <= jtdi when jshift_d='1' else jtdi_latched;

		process(jtck) begin
			if rising_edge(jtck) then
				jshift_d <= jshift;
				if jshift_d='1' then
					jtdi_latched <= jtdi;
				end if;
			end if;
		end process;

		capture(0) <= jce1 and not jshift;
		capture(1) <= jce2 and not jshift;

		-- Record which register is being accessed, and filter jupdate accordingly.
		process(jtck) begin
			if rising_edge(jtck) then
				if (jce1 and jshift) = '1' then
					selectedreg<='0';
				end if;
				if (jce2 and jshift) = '1' then
					selectedreg<='1';
				end if;
			end if;
		end process;
		update(0) <= jupdate and not selectedreg;
		update(1) <= jupdate and selectedreg;

	end block;

		-- Create a pair of registers to be accessed over the JTAG chain

	virtual_ir : entity work.vjtag_reg
	generic map (
		bits => irwidth
	)
	port map (
		tck => jtck,
		tdo => jtdo1,
		tdi => jtdi_mux,
		ce => jce1,
		cap => capture(0),
		upd => update(0),
		shift => jshift,
		frd => open,

		clk_sys => clk,
		d => vir_in,
		q => vir_out,
		rd => vir_capture,
		wr => vir_update
	);

	virtual_dr : entity work.vjtag_reg
	generic map (
		bits => drwidth
	)
	port map (
		tck => jtck,
		tdo => jtdo2,
		tdi => jtdi_mux,
		ce => jce2,
		cap => capture(1),
		upd => update(1),
		shift => jshift,
		frd => frd_en,
		d => frd,

		clk_sys => clk,
		q => vdr_out,
		rd => vdr_capture,
		wr => vdr_update
	);

end architecture;


