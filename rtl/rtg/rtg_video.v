
module rtg_video (
	input         clk_114,
	input         clk_28,
	input         clk_vid,
	input         reset_n,
	input         rtg_ena,       // RTG on/off
	input         rtg_linecompare,

    input  [10:0] reg_addr,
	input         reg_wr,        // Write strobe
	input  [15:0] reg_d,

	output [25:0] fetch_addr,
	output        fetch_req,
	output        fetch_pri,
	input  [15:0] fetch_d,
	input         fetch_ack,
	input         fetch_fill,
	
	input   [7:0] amiga_r,
	input   [7:0] amiga_g,
	input   [7:0] amiga_b,
	input         amiga_vb, /* Used for RTG framing */
	input         amiga_hb, /* Used for RTG framing */
	input         amiga_hs, /* Used for RTG framing and line compare */
	input         amiga_blank,

	output reg [7:0] red,
	output reg [7:0] green,
	output reg [7:0] blue,
	output wire      pixel,
	output reg       de
);

reg [25:4] rtg_base;
reg [25:4] rtg_base2;
reg  [6:0] rtg_vbend;
reg        rtg_ext;
reg        rtg_clut;
reg        rtg_16bit;
wire [7:0] rtg_clut_idx;
wire [7:0] rtg_clut_r;
wire [7:0] rtg_clut_g;
wire [7:0] rtg_clut_b;
reg [5:0] rtg_pixelwidth; // Number of clocks per fetch - 1 in indexed mode

reg [31:0] clut[0:255];
reg [31:0] clut_rgb;
reg [15:0] clut_high; // CLUT entries are written in two consecutive words

assign rtg_clut_r = clut_rgb[23:16];
assign rtg_clut_g = clut_rgb[15:8];
assign rtg_clut_b = clut_rgb[7:0];


// Decode input address and data
always @(posedge clk_114) begin

	clut_rgb<=clut[rtg_clut_idx];

	if(reg_wr) begin
		if(reg_addr[10]) begin
			if(reg_addr[1])
				clut[reg_addr[9:2]]={clut_high,reg_d};
			else
				clut_high<=reg_d;
		end else begin
			case (reg_addr[4:1])
				4'h0: rtg_base[25:16] <= reg_d[9:0]; // High word of framebuffer address
				4'h1: rtg_base[15:4]<=reg_d[15:4];   // Low word of framebuffer address
				4'h2: begin // CLUT (15) : Extend (14) : VBEnd(n downto 6) : PixelClock (5 downto 0)
						rtg_pixelwidth<=reg_d[5:0];
						rtg_vbend<=reg_d[12:6];
						rtg_clut<=reg_d[15];
						rtg_ext<=reg_d[14];
					end
				4'h3: rtg_16bit<=reg_d[0]; // PixelFormat - 16bit (0) 
				4'h4: rtg_base2[25:16] <= reg_d[9:0]; // High word of second framebuffer address (for screendragging)
				4'h5: rtg_base2[15:4]<=reg_d[15:4];   // Low word of second framebuffer address
				default: ;
			endcase
		end
	end

end


reg [5:0] rtg_pixelctr;	// Counter, compared against rtg_pixelwidth
wire rtg_pixel;	// Strobe the next pixel from the FIFO

reg rtg_vblank;
wire rtg_blank;
reg rtg_blank_d;
reg rtg_blank_d2;
reg [6:0] rtg_vbcounter;	// Vvbco counter


wire [7:0] rtg_r;	// 16-bit mode RGB data
wire [7:0] rtg_g;
wire [7:0] rtg_b;
reg rtg_clut_in_sel;	// Select first or second byte of 16-bit word as CLUT index
reg rtg_clut_in_sel_d;


// RTG data fetch strobe
assign rtg_pixel=(!rtg_blank || (!rtg_blank_d && rtg_ext)) && rtg_pixelctr==(rtg_ena ? rtg_pixelwidth : 5'd3) ? 1'b1 : 1'b0;

wire rtg_clut_pixel;
assign rtg_clut_pixel = rtg_clut_in_sel & !rtg_clut_in_sel_d; // Detect rising edge;
reg rtg_pixel_d;

// Export a VGA pixel strobe for the dither module.

assign pixel=rtg_ena ? (rtg_pixel_d | (rtg_clut_pixel & rtg_clut)) : 1'b0;

always @(posedge clk_114) begin
	rtg_pixel_d<=rtg_pixel;

	// Delayed copies of signals
	rtg_blank_d<=rtg_blank;
	rtg_blank_d2<=rtg_blank_d;
	rtg_clut_in_sel_d<=rtg_clut_in_sel;

	// Alternate colour index at twice the fetch clock.
	if(rtg_pixelctr=={1'b0,rtg_pixelwidth[5:1]})
		rtg_clut_in_sel<=1'b1;
	
	// Increment the fetch clock, reset during blank.
	if(rtg_blank || rtg_pixel) begin
		rtg_pixelctr<=6'b0;
		rtg_clut_in_sel<=1'b0;
	end else begin
		rtg_pixelctr<=rtg_pixelctr+1'd1;
	end
end

reg linecompare_d;
wire linecompare_trigger = rtg_linecompare & !linecompare_d;
reg [3:0] linecompare_fillmask_ctr;
wire linecompare_fillmask=|linecompare_fillmask_ctr;

reg hs_reg;

always @(posedge clk_28)
begin
	// Handle vblank manually, since the OS makes it awkward to use the chipset for this.
	hs_reg    <= amiga_hs;
	linecompare_d<=rtg_linecompare;

	// When we change the RTG address we must ensure any existing transaction has finished
	if(|linecompare_fillmask_ctr)
		linecompare_fillmask_ctr=linecompare_fillmask_ctr-1'd1;
	if(linecompare_trigger)
		linecompare_fillmask_ctr=4'hf;

	if(amiga_vb) begin
		rtg_vblank<=1'b1;
		rtg_vbcounter<=5'b0;
	end else if(rtg_vbcounter==rtg_vbend) begin
		rtg_vblank<=1'b0;
	end else if(amiga_hs & !hs_reg) begin
		rtg_vbcounter<=rtg_vbcounter+1'd1;
	end
end

assign rtg_blank = rtg_vblank | amiga_hb;

assign rtg_clut_idx = rtg_clut_in_sel_d ? rtg_dat[7:0] : rtg_dat[15:8];
assign rtg_r=rtg_16bit ? {rtg_dat[15:11],rtg_dat[15:13]} : {rtg_dat[14:10],rtg_dat[14:12]};
assign rtg_g=rtg_16bit ? {rtg_dat[10:5],rtg_dat[10:9]} : {rtg_dat[9:5],rtg_dat[9:7]};
assign rtg_b={rtg_dat[4:0],rtg_dat[4:2]};

wire [15:0] rtg_dat;

reg [7:0] rtg_reset;

always @(posedge clk_28) begin
	rtg_reset <= {1'b1,rtg_reset[7:1]};
	if(!rtg_ena || amiga_vb || linecompare_fillmask)
		rtg_reset <= 8'h00;
end


wire [25:0] fetch_addr_raw;

VideoStream #(.fifodepth(9),.burstdepth(3),.signalwidth(16)) myvs
(
	.clk(clk_114),
	.reset_n(rtg_reset[0]),
	.enable(rtg_ena),
	.baseaddr({rtg_linecompare ? rtg_base2[25:4] : rtg_base[25:4],4'b0}),
	// SDRAM interface
	.a(fetch_addr_raw),
	.req(fetch_req),
	.ack(fetch_ack),
	.pri(fetch_pri),
	.d(fetch_d),
	.fill(fetch_fill),
	// Display interface
	.rdreq(rtg_ena & rtg_pixel & !rtg_linecompare), // Allow one blank line for fetch to get ahead of display
	.q(rtg_dat)
);

// Replicate the CPU's address mangling.
assign fetch_addr[25:24]=fetch_addr_raw[25:24];
assign fetch_addr[23]=fetch_addr_raw[23]^(fetch_addr_raw[22]|fetch_addr_raw[21]);
assign fetch_addr[22:0]=fetch_addr_raw[22:0];


// Select between RTG hi-colour, RTG CLUT and native video
always @ (posedge clk_vid) begin
  red   <= #1 rtg_ena && !rtg_blank_d2 ? rtg_clut ? rtg_clut_r : rtg_r : amiga_r;
  green <= #1 rtg_ena && !rtg_blank_d2 ? rtg_clut ? rtg_clut_g : rtg_g : amiga_g;
  blue  <= #1 rtg_ena && !rtg_blank_d2 ? rtg_clut ? rtg_clut_b : rtg_b : amiga_b;
  de <= rtg_ena ? ~rtg_blank_d2 : ~amiga_blank;
end

endmodule
