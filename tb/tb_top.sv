module tb_top;
  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import fifo_uvm_pkg::*;

  logic clk = 1'b0;
  always #5ns clk = ~clk;

  fifo_if bus(clk);

  fifo_sync #(.DATA_W(8), .DEPTH(4)) dut (
    .clk   (clk),
    .rst_n (bus.rst_n),
    .wr_en (bus.wr_en),
    .rd_en (bus.rd_en),
    .wdata (bus.wdata),
    .rdata (bus.rdata),
    .full  (bus.full),
    .empty (bus.empty)
  );

  initial begin
    bus.wr_en = 1'b0;
    bus.rd_en = 1'b0;
    bus.wdata = '0;
    uvm_config_db #(virtual fifo_if)::set(null, "uvm_test_top*", "vif", bus);
    run_test("fifo_test");
  end
  // Tiến trình 2: Kích xung Reset chạy song song
  initial begin
    bus.rst_n = 1'b1;
    #1ns;
    bus.rst_n = 1'b0;
    repeat (3) @(negedge clk);
    bus.rst_n = 1'b1;
  end
`ifdef WAVES
  initial begin
    $dumpfile("fifo.vcd");
    $dumpvars(0, tb_top);
  end
`endif
endmodule
