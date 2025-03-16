library ieee;
use ieee.std_logic_1164.all;

package jcapture_pkg is

	-- User constants

	constant jcapture_width : integer := 64;
	constant jcapture_triggerwidth : integer := 8;
	constant jcapture_depth : integer := 7;

	-- Internal constants

	constant jcapture_irsize : integer := 4;
	constant jcapture_drsize : integer := 32;
	constant jcapture_ir_status : std_logic_vector(jcapture_irsize-1 downto 0) := "0000";
	constant jcapture_ir_abort : std_logic_vector(jcapture_irsize-1 downto 0) := "0001";
	constant jcapture_ir_read : std_logic_vector(jcapture_irsize-1 downto 0) := "0010";
	constant jcapture_ir_write : std_logic_vector(jcapture_irsize-1 downto 0) := "0011";
	constant jcapture_ir_setleadin : std_logic_vector(jcapture_irsize-1 downto 0) := "0100";
	constant jcapture_ir_setmask : std_logic_vector(jcapture_irsize-1 downto 0) := "0101";
	constant jcapture_ir_setinvert : std_logic_vector(jcapture_irsize-1 downto 0) := "0110";
	constant jcapture_ir_setedge : std_logic_vector(jcapture_irsize-1 downto 0) := "0111";
	constant jcapture_ir_capture : std_logic_vector(jcapture_irsize-1 downto 0) := "1000";
	constant jcapture_ir_capturewidth : std_logic_vector(jcapture_irsize-1 downto 0) := "1001";
	constant jcapture_ir_capturedepth : std_logic_vector(jcapture_irsize-1 downto 0) := "1010";
	constant jcapture_ir_triggerwidth : std_logic_vector(jcapture_irsize-1 downto 0) := "1011";
	constant jcapture_ir_sample : std_logic_vector(jcapture_irsize-1 downto 0) := "1100";
	constant jcapture_ir_spare : std_logic_vector(jcapture_irsize-1 downto 0) := "1101";
	constant jcapture_ir_reset : std_logic_vector(jcapture_irsize-1 downto 0) := "1110";
	constant jcapture_ir_bypass : std_logic_vector(jcapture_irsize-1 downto 0) := "1111";
end package;

