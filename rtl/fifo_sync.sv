// Synchronous FIFO with asynchronous, active-low reset.
// Policy: accept writes only when !full and reads only when !empty,
// using the status values present before the active clock edge.
module fifo_sync #(
  parameter int DATA_W = 8,
  parameter int DEPTH  = 4
) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              wr_en,
  input  logic              rd_en,
  input  logic [DATA_W-1:0] wdata,
  output logic [DATA_W-1:0] rdata,
  output logic              full,
  output logic              empty
);

  localparam int PTR_W   = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam int COUNT_W = $clog2(DEPTH + 1);
  localparam logic [PTR_W-1:0] LAST_PTR = DEPTH - 1;
  localparam logic [COUNT_W-1:0] DEPTH_COUNT = DEPTH;

  logic [DATA_W-1:0] mem [0:DEPTH-1];
  logic [PTR_W-1:0] wr_ptr;
  logic [PTR_W-1:0] rd_ptr;
  logic [COUNT_W-1:0] count;
  logic do_write;
  logic do_read;

  assign empty = (count == '0);
  assign full  = (count == DEPTH_COUNT);

  // These decisions use the current (pre-edge) full/empty flags.
  assign do_write = wr_en && !full;
  assign do_read  = rd_en && !empty;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count  <= '0;
      rdata  <= '0;
    end else begin
      if (do_write) begin
        mem[wr_ptr] <= wdata;
        if (wr_ptr == LAST_PTR)
          wr_ptr <= '0;
        else
          wr_ptr <= wr_ptr + 1'b1;
      end

      if (do_read) begin
        rdata <= mem[rd_ptr];
        if (rd_ptr == LAST_PTR)
          rd_ptr <= '0;
        else
          rd_ptr <= rd_ptr + 1'b1;
      end

      // At full, simultaneous read/write performs only the read.
      // At empty, simultaneous read/write performs only the write.
      case ({do_write, do_read})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end

`ifndef SYNTHESIS
  always_ff @(posedge clk) begin
    if (rst_n) begin
      assert (count <= DEPTH_COUNT)
        else $error("FIFO occupancy exceeded DEPTH");
    end
  end
`endif

endmodule
