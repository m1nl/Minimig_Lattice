--
-- AUTHOR=EMARD
-- LICENSE=BSD
--

-- VHDL Wrapper

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity clk_minimig_vhdl is
  port
  (
    clkin   : in  std_logic;
    clk_140 : out std_logic;
    clk_112 : out std_logic;
    clk_28  : out std_logic;
    clk_7   : out std_logic;
    locked  : out std_logic
  );
end;

architecture syn of clk_minimig_vhdl is
  component clk_minimig -- verilog name and its parameters
  port
  (
    clkin:   in  std_logic;
    clk_140: out std_logic;
    clk_112: out std_logic;
    clk_28 : out std_logic;
    clk_7  : out std_logic;
    locked:  out std_logic
  );
  end component;

begin
  clk_minimig_cpu_v_inst: clk_minimig
  port map
  (
    clkin   => clkin,
    clk_140 => clk_140,
    clk_112 => clk_112,
    clk_28  => clk_28,
    clk_7   => clk_7,
    locked  => locked
  );
end syn;
