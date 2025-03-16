// dpram_inf_be_1024x16.v
// 2015, rok.krajnc@gmail.com
// inferrable two-port memory with byte-enables

module dpram_be_1024x32 (
  input  wire           clock,
  input  wire           wren_a,
  input  wire           reset,
  input  wire [  4-1:0] byteena_a,
  input  wire [ 10-1:0] address_a,
  input  wire [ 32-1:0] data_a,
  output wire [ 32-1:0] q_a,
  input  wire           wren_b,
  input  wire [  4-1:0] byteena_b,
  input  wire [ 10-1:0] address_b,
  input  wire [ 32-1:0] data_b,
  output wire [ 32-1:0] q_b
);

dp_1024x32 ram(
	.DataInA(data_a),
	.DataInB(data_b),
    .ByteEnA(byteena_a),
    .ByteEnB(byteena_b),
	.AddressA(address_a),
	.AddressB(address_b),
	.ClockA(clock),
	.ClockB(clock), 
    .ClockEnA(1'b1),
	.ClockEnB(1'b1),
	.WrA(wren_a),
	.WrB(wren_b),
	.ResetA(reset),
	.ResetB(reset),
	.QA(q_a),
	.QB(q_b)
);

endmodule

