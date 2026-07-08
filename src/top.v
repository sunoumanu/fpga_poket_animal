/*
 * Tang Nano 20K (GW2AR-LV18QN88C8/I7) wrapper for tt_um_poket_animal.
 *
 * Instantiates the Tiny Tapeout design unchanged and adapts it to the
 * board: 27 MHz crystal, the two on-board push buttons (S1 = feed,
 * S2 = pet, both active high), the six on-board LEDs (active low) as
 * status indicators, and an external common-cathode 7-segment digit on
 * header J6 for the face.
 *
 * The core runs straight from the 27 MHz crystal instead of the
 * recommended 10 MHz, so every time constant is 2.7x shorter (debounce
 * ~2.4 ms, speed 01 tick ~9.9 s). See README.md for the full table.
 *
 * Reset sources (any of):
 *   - power-on reset (~2.4 ms after configuration)
 *   - rst_btn_n header pin jumpered to GND
 *   - holding S1 and S2 together for ~1.2 s (revives a dead pet; reset
 *     is held until both buttons are released so the fresh pet does not
 *     get a spurious meal from the release edges)
 */

`default_nettype none

module top (
    input  wire       clk,        // pin 4, 27 MHz crystal
    input  wire       btn_feed,   // pin 88, S1, active high
    input  wire       btn_pet,    // pin 87, S2, active high
    input  wire       rst_btn_n,  // header J5 pin 42, pull-up; short to GND to reset
    input  wire [1:0] speed,      // header J5 pins {41,48}; default 2'b01 via pulls
    output wire [7:0] seg,        // header J6: {dp, g, f, e, d, c, b, a}, active high
    output wire [5:0] led_n,      // on-board LEDs, active low
    output wire       tick,       // header J6 pin 85, hunger-tick debug pulse
    output wire       cause       // header J5 pin 80, cause of death
);

  // Power-on reset: 65536 clocks (~2.4 ms at 27 MHz)
  reg [15:0] por_cnt = 16'd0;
  wire       por_done = &por_cnt;
  always @(posedge clk)
    if (!por_done) por_cnt <= por_cnt + 16'd1;

  // Hold S1+S2 for 2^25 clocks (~1.2 s) to revive; latch reset until
  // both buttons are back low so no feed/pet edge hits the fresh pet.
  reg [24:0] both_cnt = 25'd0;
  reg        both_rst = 1'b0;
  always @(posedge clk) begin
    if (btn_feed && btn_pet) begin
      if (&both_cnt) both_rst <= 1'b1;
      else           both_cnt <= both_cnt + 25'd1;
    end else begin
      both_cnt <= 25'd0;
      if (!btn_feed && !btn_pet) both_rst <= 1'b0;
    end
  end

  wire rst_n = por_done & rst_btn_n & ~both_rst;

  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  tt_um_poket_animal dut (
      .ui_in  ({4'b0000, speed, btn_pet, btn_feed}),
      .uo_out (uo_out),
      .uio_in (8'h00),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (1'b1),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  // External common-cathode 7-segment digit (series resistors required)
  assign seg = uo_out;

  // uio_out: 0 alive, 1 heartbeat, 2 cause, 3 sick, 5:4 hunger, 6 wiggle, 7 tick
  assign led_n = ~{uio_out[5:4],   // LED5, LED4: hunger
                   uio_out[6],     // LED3: wiggle
                   uio_out[3],     // LED2: sick
                   uio_out[1],     // LED1: heartbeat
                   uio_out[0]};    // LED0: alive
  assign tick  = uio_out[7];
  assign cause = uio_out[2];

  wire _unused = &{uio_oe, 1'b0};

endmodule
