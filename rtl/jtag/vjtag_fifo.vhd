library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- FIFO queue for debug channel.
-- Asynchronous, fall-through semantics.

-- Also has a "lead in" mode, activated by setting "lead" to "01", "10" or "11".
-- While "lead in" mode is active, the FIFO will be continuously filled, and the
-- read pointer will be forced to track the write pointer with an offset of
-- 1/4 the FIFO depth, for "01", 1/2 for "10" and 3/4 for "11".


ENTITY vjtag_fifo IS
	generic (
		width : integer :=256;
		depth : integer :=6
	);
	PORT (
		reset_n : in std_logic := '1';
		-- Read-side signals
		rd_clk : IN STD_LOGIC;
		rd_en : IN STD_LOGIC;
		dout : OUT STD_LOGIC_VECTOR(width-1 DOWNTO 0);
		empty : OUT STD_LOGIC;
		-- Write-side signals
		wr_clk : IN STD_LOGIC;
		wr_en : IN STD_LOGIC;
		din : IN STD_LOGIC_VECTOR(width-1 DOWNTO 0);
		full : OUT STD_LOGIC;
		-- If this is non-zero, Lock the read pointer a fixed amount behind the write pointer,
		-- disabling full and empty logic (for capturing lead-ins).  "01" -> 1/4, "10" -> 1/2, "11" -> 3/4.
		lead : in std_logic_vector(1 downto 0) := "00"
	);
END entity;

architecture rtl of vjtag_fifo is

function togray(d : unsigned) return unsigned is begin
	return d xor ('0'&d(d'high downto 1));
end function;

subtype element_t is std_logic_vector(width-1 downto 0);
type storage_t is array ((2**depth)-1 downto 0) of element_t;
signal storage : storage_t;

signal inptr_gray : unsigned(depth-1 downto 0) := (others=>'0');
signal outptr_gray : unsigned(depth-1 downto 0) := (others => '0');
signal outptr_prev_gray : unsigned(depth-1 downto 0) := to_unsigned((2**(depth-1)),depth); -- Set MSB only

-- Leadin signals - enable, value and level-matching req/ack signals to coordinate the two sides.
signal leadin : std_logic;
signal leadptr : unsigned(depth-1 downto 0) := (others => '0');
signal lead_wr : std_logic :='0';
signal lead_rd : std_logic :='0';

begin

-- Read side logic

readlogic : block is

signal inptr_gray_sync : unsigned(depth-1 downto 0);
signal inptr_gray_sync2 : unsigned(depth-1 downto 0);
signal outptr : unsigned(depth-1 downto 0) := (others=>'0');
signal outptr_prev : unsigned(depth-1 downto 0);
signal outptr_next : unsigned(depth-1 downto 0);
signal empty_c : std_logic;
signal rd_trigger : std_logic;
signal reset_rd : std_logic_vector(1 downto 0);
signal leadin_sync : std_logic;
signal leadin_sync2 : std_logic;
signal leadin_d : std_logic;
signal lead_wr_sync : std_logic := '0';
signal lead_wr_sync2 : std_logic := '0';
signal lead_wr_upd : std_logic := '0';
signal lead_rd_d : std_logic;
begin

	process(rd_clk) begin
		if rising_edge(rd_clk) then
			reset_rd <= reset_rd(0) & reset_n;
			inptr_gray_sync2<=inptr_gray;
			inptr_gray_sync<=inptr_gray_sync2;			
			leadin_sync2 <= leadin;
			leadin_sync <= leadin_sync2;
			leadin_d <= leadin_sync;
			lead_wr_sync2 <= lead_wr;
			lead_wr_sync <= lead_wr_sync2;
			lead_wr_upd <= lead_wr_sync;
		end if;
	end process;

	rd_trigger <= '1' when rd_en='1' and empty_c='0' else '0';

	empty_c <= '1' when lead_rd /= lead_wr_sync or inptr_gray_sync = outptr_gray else'0';
	empty <= empty_c or leadin_sync;	-- Make sure the FIFO's considered empty while a lead-in is in progress...

	outptr_next<=leadptr+1 when lead_rd /= lead_wr_sync else outptr+1;
	outptr_prev<=leadptr-1 when lead_rd /= lead_wr_sync else outptr-1; -- Gray counter updated on lead_wr_upd

	process(rd_clk,reset_rd(1)) begin
		if reset_rd(1)='0' then
			outptr<=(others=>'0');
			outptr_gray<=(others=>'0');
			outptr_prev_gray<=to_unsigned((2**(depth-1)),depth); -- Set MSB only
			lead_rd<='0';
		elsif rising_edge(rd_clk) then
			dout <= storage(to_integer(outptr_gray));
			lead_rd<=lead_rd_d;
			if rd_trigger='1' or lead_rd /= lead_wr_upd then
				outptr<=outptr_next;
				outptr_gray <= togray(outptr_next);
				outptr_prev_gray<=togray(outptr_prev);
				lead_rd_d <= lead_wr_sync;	-- Acknowledge that the leadin ptr has been adopted.
			end if;
		end if;
	end process;

end block;


-- Write side logic;

writelogic : block is

signal outptr_prev_gray_sync : unsigned(depth-1 downto 1);
signal outptr_prev_gray_sync2 : unsigned(depth-1 downto 1);
signal inptr : unsigned(depth-1 downto 0) := (others=>'0');
signal inptr_next : unsigned(depth-1 downto 0);
signal reset_wr : std_logic_vector(1 downto 0);
signal leadptr_msbs : unsigned(1 downto 0);
signal leadptr_gray : unsigned(depth-1 downto 0);
signal fullptr : unsigned(depth-1 downto 1);
signal leadprev : std_logic;
signal lead_rd_sync : std_logic := '0';
signal lead_rd_sync2 : std_logic := '0';
begin

	leadin <= '0' when lead="00" else '1';
	fullptr <= outptr_prev_gray_sync when leadprev='0' and lead_rd_sync = lead_wr else leadptr_gray(depth-1 downto 1);
	
	process(wr_clk) begin
		if rising_edge(wr_clk) then
			reset_wr <= reset_wr(0) & reset_n;
			outptr_prev_gray_sync2<=outptr_prev_gray(outptr_prev_gray'high downto 1); -- Ignore the lowest bit to provide some headroom.
			outptr_prev_gray_sync<=outptr_prev_gray_sync2;
			lead_rd_sync2 <= lead_rd;
			lead_rd_sync <= lead_rd_sync2;
		end if;
	end process;

	-- We consider the FIFO full when outptr_prev_gray == inptr_gray, so the write pointer is about to
	-- catch up with the read pointer (ignoring the LSB to give a little extra headroom, so the FIFO can accept one further
	-- entry in the cycle during which full goes high).
	full <= '1' when leadin='1' or inptr_gray(inptr_gray'high downto 1) = fullptr else '0';

	inptr_next<=inptr+1;
	leadptr_msbs<=inptr(depth-1 downto depth-2) + unsigned(lead);

	process(wr_clk,reset_wr(1)) begin
		if reset_wr(1)='0' then
			inptr<=(others=>'0');
			inptr_gray<=(others=>'0');
			lead_wr<='0';
		elsif rising_edge(wr_clk) then
			if wr_en='1' or leadin='1' then
				storage(to_integer(inptr_gray))<=din;
				inptr<=inptr_next;
				inptr_gray <= togray(inptr_next);
			end if;
			if leadin='1' then
				leadptr<=leadptr_msbs & inptr(depth-3 downto 0); -- Passed to the read-side logic when leadin ends
				leadptr_gray <= togray(leadptr-1); -- Used as a temporary fullptr while the read-side logic catches up.
			end if;
			leadprev <= leadin;	
			if leadprev='1' and leadin='0' then
				-- Let the read side logic know we're recording...
				lead_wr <= not lead_rd_sync;
			end if;
		end if;
	end process;

end block;

end architecture;

