/*
my_hdmi_device 

Copyright (C) 2021  Hirosh Dabui <hirosh@dabui.de>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/
/*
 * tmds_encode implementation (c) 2020 Hirosh Dabui <hirosh@dabui.de>
 * based on Digital Visual Interface Revision 1.0, Page 29
 */
 
/* Pipelined by Alastair M. Robinson, May 2023. */
 
module tmds_encoder(
           input clk,
           input pixel_stb,
           input window,
           input [7:0]D,
           input C1,
           input C0,
           output reg[9:0] q_out = 0
       );
parameter LEGACY_DVI_CONTROL_LUT = 1;

function [3:0] N0;
    input [7:0] d;
    integer i;
    begin
        N0 = 0;
        for (i = 0; i < 8; i = i +1)
            N0 = N0 + !d[i];
    end
endfunction

function [3:0] N1;
    input [7:0] d;
    integer i;
    begin
        N1 = 0;
        for (i = 0; i < 8; i = i +1)
            N1 = N1 + d[i];
    end
endfunction




// First pipeline stage

reg [7:0] D_p1;
reg C0_p1;
reg C1_p1;
reg pixel_stb_p1;
reg window_p1;

always @(posedge clk) begin
	D_p1<=D;
	C0_p1<=C0;
	C1_p1<=C1;
	pixel_stb_p1<=pixel_stb;
	window_p1<=window;
end

reg [7:0] q_m_a_t;
reg [7:0] q_m_a_p1;

always @(posedge clk) begin
	q_m_a_t[0] =           D[0];
	q_m_a_t[1] = q_m_a_t[0] ~^ D[1];
	q_m_a_t[2] = q_m_a_t[1] ~^ D[2];
	q_m_a_t[3] = q_m_a_t[2] ~^ D[3];
	q_m_a_t[4] = q_m_a_t[3] ~^ D[4];
	q_m_a_p1 <= q_m_a_t;
end

reg [7:0] q_m_b_t;
reg [7:0] q_m_b_p1;

always @(posedge clk) begin
	q_m_b_t[0] =           D[0];
	q_m_b_t[1] = q_m_b_t[0] ^ D[1];
	q_m_b_t[2] = q_m_b_t[1] ^ D[2];
	q_m_b_t[3] = q_m_b_t[2] ^ D[3];
	q_m_b_t[4] = q_m_b_t[3] ^ D[4];
	q_m_b_p1 <= q_m_b_t;
end




// Second pipeline stage

reg [0:0] D0_p2;
reg C0_p2;
reg C1_p2;
reg pixel_stb_p2;
reg window_p2;

always @(posedge clk) begin
	D0_p2<=D_p1[0];
	C0_p2<=C0_p1;
	C1_p2<=C1_p1;
	pixel_stb_p2<=pixel_stb_p1;
	window_p2<=window_p1;
end


reg [7:0] q_m_a_t2;
reg [7:0] q_m_a_p2;

always @(posedge clk) begin
	q_m_a_t2[4:0] = q_m_a_p1[4:0];
	q_m_a_t2[5] = q_m_a_t2[4] ~^ D_p1[5];
	q_m_a_t2[6] = q_m_a_t2[5] ~^ D_p1[6];
	q_m_a_t2[7] = q_m_a_t2[6] ~^ D_p1[7];
	q_m_a_p2 <= q_m_a_t2;
end

reg [7:0] q_m_b_t2;
reg [7:0] q_m_b_p2;

always @(posedge clk) begin
	q_m_b_t2[4:0] = q_m_b_p1[4:0];
	q_m_b_t2[5] = q_m_b_t2[4] ^ D_p1[5];
	q_m_b_t2[6] = q_m_b_t2[5] ^ D_p1[6];
	q_m_b_t2[7] = q_m_b_t2[6] ^ D_p1[7];
	q_m_b_p2 <= q_m_b_t2;
end

reg [2:0] n1_p2;
always @(posedge clk) n1_p2 <= N1(D_p1);




// Third pipeline stage

reg C0_p3;
reg C1_p3;
reg pixel_stb_p3;
reg window_p3;

always @(posedge clk) begin
	C0_p3<=C0_p2;
	C1_p3<=C1_p2;
	pixel_stb_p3<=pixel_stb_p2;
	window_p3<=window_p2;
end


reg [8:0] q_m_p3;
reg msb_p3;

always @(posedge clk) begin

	if(n1_p2 > 4 | (n1_p2 == 4) & D0_p2[0] == 0) begin
		q_m_p3 <= q_m_a_p2; 
		msb_p3 <= 1'b0;
	end else begin
		q_m_p3 <= q_m_b_p2;
		msb_p3 <= 1'b1;
	end
end




// Fourth pipeline stage

reg C0_p4;
reg C1_p4;
reg pixel_stb_p4;
reg window_p4;
reg msb_p4;

always @(posedge clk) begin
	C0_p4<=C0_p3;
	C1_p4<=C1_p3;
	pixel_stb_p4<=pixel_stb_p3;
	window_p4<=window_p3;
	msb_p4<=msb_p3;
end


reg [7:0] q_m_p4;
reg [2:0] n0_q_m_p4;
reg [2:0] n1_q_m_p4;

always @(posedge clk) begin
	q_m_p4<=q_m_p3;
	n0_q_m_p4 <= N0(q_m_p3);
	n1_q_m_p4 <= N1(q_m_p3);
end




// Fifth pipeline stage

reg C0_p5;
reg C1_p5;
reg pixel_stb_p5;
reg window_p5;
reg msb_p5;

always @(posedge clk) begin
	C0_p5<=C0_p4;
	C1_p5<=C1_p4;
	pixel_stb_p5<=pixel_stb_p4;
	window_p5<=window_p4;
	msb_p5<=msb_p4;
end


reg [7:0] q_m_p5;
reg [2:0] n0_q_m_p5;
reg [2:0] n1_q_m_p5;
reg signed [5:0] n1minusn0_q_m_p5;
reg signed [7:0] cntinc_a_p5;
reg signed [7:0] cntinc_b_p5;
reg difzero_p5;

always @(posedge clk) begin
	q_m_p5 <= q_m_p4;
	n0_q_m_p5 <= n0_q_m_p4;
	n1_q_m_p5 <= n1_q_m_p4;

	difzero_p5 <= ~((|n0_q_m_p4) | (|n1_q_m_p4));
	
	n1minusn0_q_m_p5 <= n1_q_m_p4-n0_q_m_p4;
	cntinc_a_p5 <= 2*msb_p4 + n0_q_m_p4 - n1_q_m_p4;
	cntinc_b_p5 <= -({~msb_p4, 1'b0} + n1_q_m_p4 - n0_q_m_p4);
end


reg [9:0] q_sync_p5;
always @(posedge clk) begin
	case ({C1_p4, C0_p4})
	`ifdef LEGACY_DVI_CONTROL_LUT
        /* dvi control data lut */
        2'b00: q_sync_p5 <= 10'b00101_01011;
        2'b01: q_sync_p5 <= 10'b11010_10100;
        2'b10: q_sync_p5 <= 10'b00101_01010;
        2'b11: q_sync_p5 <= 10'b11010_10101;
	`else
        /* hdmi control data period */
        2'b00: q_sync_p5 <= 10'b1101010100;
        2'b01: q_sync_p5 <= 10'b0010101011;
        2'b10: q_sync_p5 <= 10'b0101010100;
        2'b11: q_sync_p5 <= 10'b1010101011;
	`endif
    endcase
end


reg [9:0] q_out_a_p5;
reg [9:0] q_out_b_p5;
reg [9:0] q_out_c_p5;

always @(posedge clk) begin
    q_out_a_p5[9]   <= ~msb_p4;
    q_out_a_p5[8]   <=  msb_p4;
    q_out_a_p5[7:0] <= msb_p4 ? q_m_p4[7:0] : ~q_m_p4[7:0];
    
	q_out_b_p5[9] <= 1;
	q_out_b_p5[8] <= msb_p4;
	q_out_b_p5[7:0] <= ~q_m_p4;

	q_out_c_p5[9] <= 0;
	q_out_c_p5[8] <= msb_p4;
	q_out_c_p5[7:0] <= q_m_p4;
end




// Sixth pipeline stage

reg [9:0] q_out_p6;

reg signed [7:0] cnt = 0;
reg signed [7:0] cntinc_p6;


always @(posedge clk) begin

	if (pixel_stb_p4)
		cnt <= cnt + cntinc_p6;

	if (pixel_stb_p5) begin
		if (window_p5) begin

		    if (difzero_p5 || (cnt == 0)) begin

		        q_out_p6 <= q_out_a_p5;

		        if (msb_p5 == 0) begin
		            cntinc_p6 <= -n1minusn0_q_m_p5; // + (N0(q_m[7:0]) - N1(q_m[7:0]));
		        end else begin
		            cntinc_p6 <= n1minusn0_q_m_p5; // (N1(q_m[7:0]) - N0(q_m[7:0]));
		        end /*q_m[8] == 0*/

		    end else begin

		        if ( (cnt > 0 && (n1minusn0_q_m_p5 > 0)) | // N1(q_m[7:0]) > N0(q_m[7:0]))) |
		                (cnt < 0 && (n1minusn0_q_m_p5 <0)) ) begin // N0(q_m[7:0]) > N1(q_m[7:0]))) ) begin
					q_out_p6 <= q_out_b_p5;
		            cntinc_p6 <= cntinc_a_p5; // 2*msb_p4 - n1minusn0_q_m_p4; // + (N0(q_m[7:0]) - N1(q_m[7:0]));
		        end else begin
		        	q_out_p6 <= q_out_c_p5;
		            cntinc_p6 <= cntinc_b_p5; // - {~msb_p4, 1'b0} + n1minusn0_q_m_p4; // (N1(q_m[7:0]) - N0(q_m[7:0]));
		        end

		    end

		end else begin
		    cntinc_p6 <= 0;
			q_out_p6 <= q_sync_p5;

		end

	end

end



// Final stage

always @(posedge clk)
	q_out <= q_out_p6;

endmodule

