// Simple interface shared by the DUT, UVM driver, and UVM monitor.
// The monitor/driver use explicit clock edges rather than clocking blocks.
interface fifo_if(input logic clk);
  logic rst_n;
  logic wr_en;
  logic rd_en;
  logic [7:0] wdata;
  logic [7:0] rdata;
  logic full;
  logic empty;
endinterface
