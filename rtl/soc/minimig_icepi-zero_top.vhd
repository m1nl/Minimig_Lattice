library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.minimig_virtual_pkg.all;

entity minimig_icepizero_top is
port(
	clk : in std_logic; -- 25MHz

	usb_tx : out std_logic;
	usb_rx : in std_logic;

	button : in std_logic_vector(1 downto 0);
	led : out std_logic_vector(4 downto 0);

	sdram_clk  : out std_logic;
	sdram_csn  : out std_logic;
	sdram_a    : out std_logic_vector(12 downto 0);
	sdram_dq   : inout std_logic_vector(15 downto 0);
	sdram_wen  : out std_logic;
	sdram_rasn : out std_logic;
	sdram_casn : out std_logic;
	sdram_cke  : out std_logic;
	sdram_ba   : out std_logic_vector(1 downto 0);
	sdram_dqm  : out std_logic_vector(1 downto 0);

	sd_clk : out std_logic;
	sd_mosi : out std_logic;
	sd_csn : out std_logic;
	sd_miso : in std_logic;

	usb_dp : inout std_logic_vector(1 downto 0);
	usb_dn : inout std_logic_vector(1 downto 0);

	gpio : inout std_logic_vector(27 downto 0);

	gpdi_dp : out std_logic_vector(3 downto 0)	-- Quasi-differential output for digital video.
	-- gpdi_dn : out std_logic_vector(3 downto 0)  -- Don't declare the _n pins - the _p pins are declared as
	                                               -- LVCMOS33D so their conjugate pairs will be used automatically.
);
end entity;

architecture rtl of minimig_icepizero_top is
	-- Internal signals

	signal ps2k_dat_in : std_logic;
	signal ps2k_dat_out : std_logic;
	signal ps2k_clk_in : std_logic;
	signal ps2k_clk_out : std_logic;
	signal ps2m_dat_in : std_logic;
	signal ps2m_dat_out : std_logic;
	signal ps2m_clk_in : std_logic;
	signal ps2m_clk_out : std_logic;

	signal audio_l : std_logic_vector(23 downto 0);
	signal audio_r : std_logic_vector(23 downto 0);

	signal clk_sys : std_logic;
	signal dvi_red : std_logic_vector(7 downto 0);
	signal dvi_green : std_logic_vector(7 downto 0);
	signal dvi_blue : std_logic_vector(7 downto 0);
	signal dvi_hsync : std_logic := '0';
	signal dvi_vsync : std_logic := '0';
	signal dvi_window : std_logic;
	signal dvi_pixel : std_logic;

	signal reset_n : std_logic;

	signal amiga_txd : std_logic;
	signal amiga_rxd : std_logic;

	signal joya : std_logic_vector(6 downto 0);
	signal joyb : std_logic_vector(6 downto 0);
	signal joyc : std_logic_vector(6 downto 0);
	signal joyd : std_logic_vector(6 downto 0);

	component ODDRX1F
	port (
		D0 : in std_logic;
		D1 : in std_logic;
		Q : out std_logic;
		SCLK : in std_logic;
		RST : in std_logic
	); end component;
begin

	ddr_sdramclk: ODDRX1F port map (D0=>'0', D1=>'1', Q=>sdram_clk, SCLK=>clk_sys, RST=>'0');

	reset_n <= button(0);

	ps2k_clk_in <= '1';
	ps2k_dat_in <= '1';
	ps2m_clk_in <= '1';
	ps2m_dat_in <= '1';

	joya<=(others=>'1');
	joyb<=(others=>'1');
	joyc<=(others=>'1');
	joyd<=(others=>'1');

	amiga_rxd <= '1';

	virtual_top : COMPONENT minimig_virtual_top
	generic map
		(
			hostonly => 0,
			debug => 0,
			spimux => 0,
			haveiec => 0,
			havereconfig => 0,
			havertg => 0,
			haveaudio => 0,
			havec2p => 0,
			havespirtc => 0,
			ram_64meg => 0,
			vga_width => 4,
			havecart => 0,
			haveaga => 0
		)
	PORT map
		(
			CLK_IN => clk,
			CLK_114 => clk_sys,
			RESET_N => reset_n,
			LED_POWER => led(4),
			LED_DISK => led(3),
			LED_USB => led(2 downto 1),
			MENU_BUTTON => button(1),
			CTRL_TX => usb_tx,
			CTRL_RX => usb_rx,
			AMIGA_TX => amiga_txd,
			AMIGA_RX => amiga_rxd,

			DVI_HS => dvi_hsync,
			DVI_VS => dvi_vsync,
			DVI_R => dvi_red,
			DVI_G => dvi_green,
			DVI_B => dvi_blue,
			DVI_STROBE => dvi_pixel,
			DVI_DE => dvi_window,

			SDRAM_DQ => sdram_dq,
			SDRAM_A => sdram_a,
			SDRAM_DQML => sdram_dqm(0),
			SDRAM_DQMH => sdram_dqm(1),
			SDRAM_nWE => sdram_wen,
			SDRAM_nCAS => sdram_casn,
			SDRAM_nRAS => sdram_rasn,
			SDRAM_nCS => sdram_csn,
			SDRAM_BA => sdram_ba,
--			SDRAM_CLK => sdram_clk,
			SDRAM_CKE => sdram_cke,

			AUDIO_L => audio_l,
			AUDIO_R => audio_r,

			PS2_DAT_I => ps2k_dat_in,
			PS2_CLK_I => ps2k_clk_in,
			PS2_MDAT_I => ps2m_dat_in,
			PS2_MCLK_I => ps2m_clk_in,

			PS2_DAT_O => ps2k_dat_out,
			PS2_CLK_O => ps2k_clk_out,
			PS2_MDAT_O => ps2m_dat_out,
			PS2_MCLK_O => ps2m_clk_out,

			AMIGA_RESET_N => '1',
			AMIGA_KEY => (others=>'-'),
			AMIGA_KEY_STB => '0',
			c64_keys => (others => '1'),
			JOYA => joya,
			JOYB => joyb,
			JOYC => joyc,
			JOYD => joyd,

			SD_MISO => sd_miso,
			SD_MOSI => sd_mosi,
			SD_CLK => sd_clk,
			SD_CS => sd_csn,
			SD_ACK => '1',

			usb_dp => usb_dp,
			usb_dn => usb_dn
		);

	-- Instantiate HDMI out:
	genvideo: block
		component hdmi
		generic (
			IT_CONTENT : std_logic := '1';
			DVI_OUTPUT : std_logic := '0';
			VIDEO_RATE : integer := 28571400;
			AUDIO_RATE : integer := 48000;
			AUDIO_BIT_WIDTH : integer := 24;
			VENDOR_NAME : std_logic_vector(8*8-1 downto 0) := x"556E6B6E6F776E00";  -- "Unknown" + zero padding
			PRODUCT_DESCRIPTION : std_logic_vector(8*16-1 downto 0) := x"46504741000000000000000000000000"; -- "FPGA" + padding
			SOURCE_DEVICE_INFORMATION : std_logic_vector(7 downto 0) := x"09"
		);
		port (
			clk_pixel_x5 : in  std_logic;
			clk_pixel    : in  std_logic;
			reset        : in  std_logic;

			pal_mode    : in  std_logic;
			screen      : in  std_logic_vector(1 downto 0);
			short_frame : in  std_logic;
			interlace   : in  std_logic;

			rgb : in  std_logic_vector(23 downto 0);

			audio_sample_word_0 : in  std_logic_vector(AUDIO_BIT_WIDTH-1 downto 0);
			audio_sample_word_1 : in  std_logic_vector(AUDIO_BIT_WIDTH-1 downto 0);
			audio_sample_en     : out std_logic;

			tmds       : out std_logic_vector(2 downto 0);
			tmds_clock : out std_logic
		); end component;

		component video_analyzer
		port (
			clk         : in  std_logic;
			hs          : in  std_logic;
			vs          : in  std_logic;
			screen      : in  std_logic_vector(1 downto 0);
			pal         : out std_logic;
			short_frame : out std_logic;
			interlace   : out std_logic;
			vreset      : out std_logic
		); end component;

		signal pcnt : unsigned(3 downto 0);
		signal clksel : std_logic_vector(1 downto 0);
		signal vidclks : std_logic_vector(3 downto 0);
		signal clk_video : std_logic;
		signal clk_tmds : std_logic;

		signal heartbeat_ctr : unsigned(27 downto 0);

		signal vreset : std_logic;
		signal vpal : std_logic;
		signal interlace : std_logic;
		signal short_frame : std_logic;
		signal screen : std_logic_vector(1 downto 0);
		signal tmds_clock : std_logic;
		signal tmds : std_logic_vector(2 downto 0);
		signal rgb : std_logic_vector(23 downto 0);

	begin

		--process(clk_tmds) begin
			--if rising_edge(clk_tmds) then
				--heartbeat_ctr <= heartbeat_ctr+1;
			--end if;
			--led_blue <= heartbeat_ctr(heartbeat_ctr'high);
		--end process;

		process(clk_sys) begin

			-- Clock multiplexing:  Video timings are derived from the 114Hz clock.
			-- dvi_pixel is high for one cycle at the start of each pixel, so by counting
			-- the number of clocks between each pulse we can determine the pixel clock and
			-- thus the appropriate TMDS clock to use.
			-- We will see a pcnt value of 1 for 56MHz modes and 3 for 28MHz modes
			-- Since we don't seem to be able to cascade DCSCs, we're stuck with just two
			-- TDMS clocks, which will be 5*28MHz and 5*56Mhz.
			if rising_edge(clk_sys) then
				if dvi_pixel='1' then
					pcnt <=(others => '0');
					clksel(0)<='0';
					case pcnt is
						when X"1" => -- 56MHz pixel clock in RTG mode
							clksel(0) <= '0';
						when others => -- 28MHz pixel clock otherwise
							clksel(0) <= '1';
							null;
					end case;
				else
					pcnt<=pcnt+1;
				end if;
			end if;
			clksel(1) <= not clksel(0);
		end process;

		vidpll : entity work.ecp5pll
		generic map(
			in_hz => natural(114.2857e6),
			out0_hz => natural(142.857125e6),
			out1_hz => natural(285.71425e6),
			out2_hz => natural(28.571425e6)
		)
		port map (
			clk_i => clk_sys,
			clk_o => vidclks
		);

		--clkmux1 : component DCSC
		--port map (
		--	CLK0 => vidclks(0),
		--	CLK1 => vidclks(1),
		--	SEL1 => clksel(1),
		--	SEL0 => clksel(0),
		--	MODESEL => '1',
		--	DCSOUT => clk_tmds
		--);

		clk_tmds <= vidclks(0);
		clk_video <= vidclks(2);

		video_analyzer_inst : component video_analyzer
		port map (
			clk => clk_video,
			hs => dvi_hsync,
			vs => dvi_vsync,
			pal => vpal,
			short_frame => short_frame,
			screen => screen,
			interlace => interlace,
			vreset => vreset
		);
		screen <= (others => '0');

		hdmi_inst : component hdmi
		generic map (
			AUDIO_RATE => 48000,
			AUDIO_BIT_WIDTH => 24
		)
		port map (
			clk_pixel_x5 => clk_tmds,
			clk_pixel => clk_video,
			reset => vreset,

			pal_mode => vpal,
			short_frame => short_frame,
			screen => screen,
			interlace => interlace,

			rgb => rgb,

			audio_sample_word_0 => audio_l,
			audio_sample_word_1 => audio_r,
			audio_sample_en => open,

			tmds => tmds,
			tmds_clock => tmds_clock
		);

		rgb <= dvi_red & dvi_green & dvi_blue;
		gpdi_dp <= tmds_clock & tmds;
	end block;
end architecture;

