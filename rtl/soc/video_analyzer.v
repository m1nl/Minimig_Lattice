//
// video_analyzer.v
//
// try to derive video parameters from hs/vs/de
//

module video_analyzer (
  input wire clk,

  input wire hs,
  input wire vs,

  input wire [1:0] screen,  // standard, overscan or wide screen jailbars enabled

  output reg pal,         // pal mode detected
  output reg short_frame, // short frame has two lines less
  output reg interlace,   // interlace modes have one line less
  output reg vreset       // video reset signal
);

// generate a reset signal in the upper left corner of active video used
// to synchonize the HDMI video generation to the Amiga
reg [1:0] screenD;

reg vsD, hsD;

reg [10:0] hcnt;
reg [10:0] hcntL;

reg [ 9:0] vcnt;
reg [ 9:0] vcntL;

reg changed;

always @(posedge clk) begin
  // resync HDMI whenever screen setting changes
  screenD <= screen;
  if(screenD != screen)
    changed <= 1;

  // ---- hsync processing -----
  hsD <= hs;

  // begin of hsync, falling edge
  if(!hs && hsD) begin
    // check if line length has changed during last cycle
    hcntL <= hcnt;
    if(hcntL != hcnt)
      changed <= 1;
    hcnt <= 0;
  end else
    hcnt <= hcnt + 1;

  if(!hs && hsD) begin
    // ---- vsync processing -----
    vsD <= vs;

    // begin of vsync, falling edge
    if(!vs && vsD) begin
      // check if image height has changed during last cycle
      vcntL <= vcnt;
      if(vcntL != vcnt) begin
        if(vcnt == 523) begin
          pal <= 0; // NTSC
          short_frame <= 1;
        end
        if(vcnt == 524 || vcnt == 525) begin
          pal <= 0; // NTSC
          short_frame <= 0;
        end
        if(vcnt == 623) begin
          pal <= 1; // PAL
          short_frame <= 1;
        end
        if(vcnt == 624 || vcnt == 625) begin
          pal <= 1; // PAL
          short_frame <= 0;
        end

        interlace <= !vcnt[0];
        changed <= 1;
      end

      vcnt <= 0;
    end else
      vcnt <= vcnt + 1;
  end

  // the reset signal is sent to the HDMI generator. On reset the
  // HDMI re-adjusts its counters to the start of the visible screen
  // area
  vreset <= 0;

  // account for back porches to adjust image position within the
  // HDMI frame. Center screen according to screen type standard (0),
  // overscan (1) or wide (2)
  if( hcnt == (( screen == 2'd2) ? 88 : (screen == 2'd1 ) ? 120 : 162) && vcnt == 46 && changed) begin
    vreset <= 1;
    changed <= 0;
  end
end

endmodule
