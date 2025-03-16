--
-- AUTHOR=EMARD
-- LICENSE=BSD
--

-- VHDL Wrapper

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity clk_ramusb_vhdl is
  port
  (
    clkin          : in  std_logic;
    clk_112        : out std_logic;
    clk_112_120deg : out std_logic;
    clk_6          : out std_logic;
    locked         : out std_logic
  );
end;

architecture syn of clk_ramusb_vhdl is
  component clk_ramusb -- verilog name and its parameters
  port
  (
    clkin          : in  std_logic;
    clk_112        : out std_logic;
    clk_112_120deg : out std_logic;
    clk_6          : out std_logic;
    locked         : out std_logic
  );
  end component;

begin
  clk_ramusb_v_inst: clk_ramusb
  port map
  (
    clkin          => clkin,
    clk_112        => clk_112,
    clk_112_120deg => clk_112_120deg,
    clk_6          => clk_6,
    locked         => locked
  );
end syn;
