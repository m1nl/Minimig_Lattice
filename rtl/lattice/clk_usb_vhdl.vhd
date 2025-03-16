--
-- AUTHOR=EMARD
-- LICENSE=BSD
--

-- VHDL Wrapper

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity clk_usb_vhdl is
  port
  (
    clkin          : in  std_logic;
    clk_240        : out std_logic;
    clk_48         : out std_logic;
    clk_6          : out std_logic;
    locked         : out std_logic
  );
end;

architecture syn of clk_usb_vhdl is
  component clk_usb -- verilog name and its parameters
  port
  (
    clkin          : in  std_logic;
    clk_240        : out std_logic;
    clk_48         : out std_logic;
    clk_6          : out std_logic;
    locked         : out std_logic
  );
  end component;

begin
  clk_usb_v_inst: clk_usb
  port map
  (
    clkin          => clkin,
    clk_240        => clk_240,
    clk_48         => clk_48,
    clk_6          => clk_6,
    locked         => locked
  );
end syn;
