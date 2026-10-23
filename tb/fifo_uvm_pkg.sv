package fifo_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  localparam int FIFO_DEPTH = 4;

  // One sequence item represents one cycle of requested FIFO activity.
  // The monitor also uses this type to publish sampled bus activity.
  class fifo_item extends uvm_sequence_item;
    rand bit       wr_en;
    rand bit       rd_en;
    rand bit [7:0] wdata;

    bit       rst_n;
    bit       full_pre;
    bit       empty_pre;
    bit       full_post;
    bit       empty_post;
    bit [7:0] rdata_post;

    constraint c_control_mix {
      wr_en dist {0 := 1, 1 := 1};
      rd_en dist {0 := 1, 1 := 1};
    }

    `uvm_object_utils_begin(fifo_item)
      `uvm_field_int(wr_en,      UVM_DEFAULT)
      `uvm_field_int(rd_en,      UVM_DEFAULT)
      `uvm_field_int(wdata,      UVM_DEFAULT)
      `uvm_field_int(rst_n,      UVM_DEFAULT)
      `uvm_field_int(full_pre,   UVM_DEFAULT)
      `uvm_field_int(empty_pre,  UVM_DEFAULT)
      `uvm_field_int(full_post,  UVM_DEFAULT)
      `uvm_field_int(empty_post, UVM_DEFAULT)
      `uvm_field_int(rdata_post, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "fifo_item");
      super.new(name);
    endfunction
  endclass

  class fifo_sequencer extends uvm_sequencer #(fifo_item);
    `uvm_component_utils(fifo_sequencer)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  // Pulls transactions from the sequencer and drives them on falling edges.
  class fifo_driver extends uvm_driver #(fifo_item);
    `uvm_component_utils(fifo_driver)
    virtual fifo_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db #(virtual fifo_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "fifo_driver did not receive virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_item req;
      vif.wr_en = 1'b0;
      vif.rd_en = 1'b0;
      vif.wdata = '0;
      forever begin
        seq_item_port.get_next_item(req);
        @(negedge vif.clk);
        vif.wr_en = req.wr_en;
        vif.rd_en = req.rd_en;
        vif.wdata = req.wdata;
        @(posedge vif.clk);
        seq_item_port.item_done();
      end
    endtask
  endclass

  // Samples request/status just before a rising edge, then samples registered
  // outputs at the following falling edge (after the DUT's nonblocking updates).
  class fifo_monitor extends uvm_monitor;
    `uvm_component_utils(fifo_monitor)
    virtual fifo_if vif;
    uvm_analysis_port #(fifo_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db #(virtual fifo_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "fifo_monitor did not receive virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_item tr;
      forever begin
        @(posedge vif.clk);
        tr = fifo_item::type_id::create("tr");
        tr.rst_n     = vif.rst_n;
        tr.wr_en     = vif.wr_en;
        tr.rd_en     = vif.rd_en;
        tr.wdata     = vif.wdata;
        tr.full_pre  = vif.full;
        tr.empty_pre = vif.empty;
        @(negedge vif.clk);
        tr.full_post  = vif.full;
        tr.empty_post = vif.empty;
        tr.rdata_post = vif.rdata;
        ap.write(tr);
      end
    endtask
  endclass

  // The reference model is a SystemVerilog queue. It predicts accepted
  // operations from its own occupancy, then compares DUT flags and read data.
  class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)
    uvm_analysis_imp #(fifo_item, fifo_scoreboard) analysis_export;
    bit [7:0] expected_q[$];
    int unsigned occ_sample;
    bit wr_sample;
    bit rd_sample;
    int unsigned reads_checked;

    covergroup fifo_cg;
      cp_occupancy: coverpoint occ_sample {
        bins empty = {0};
        bins one   = {1};
        bins two   = {2};
        bins three = {3};
        bins full  = {4};
      }
      cp_write: coverpoint wr_sample;
      cp_read:  coverpoint rd_sample;
      occupancy_and_ops: cross cp_occupancy, cp_write, cp_read;
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      analysis_export = new("analysis_export", this);
      fifo_cg = new();
      reads_checked = 0;
    endfunction

    function void write(fifo_item tr);
      bit model_full;
      bit model_empty;
      bit accept_write;
      bit accept_read;
      bit [7:0] expected_data;

      if (!tr.rst_n) begin
        expected_q.delete();
        if ((tr.empty_post !== 1'b1) || (tr.full_post !== 1'b0))
          `uvm_error("FIFO_RESET", "DUT flags are not empty=1/full=0 during reset")
        return;
      end

      model_empty = (expected_q.size() == 0);
      model_full  = (expected_q.size() == FIFO_DEPTH);

      if (tr.empty_pre !== model_empty)
        `uvm_error("FIFO_EMPTY", $sformatf("pre-edge empty mismatch: DUT=%0b model=%0b occupancy=%0d", tr.empty_pre, model_empty, expected_q.size()))
      if (tr.full_pre !== model_full)
        `uvm_error("FIFO_FULL", $sformatf("pre-edge full mismatch: DUT=%0b model=%0b occupancy=%0d", tr.full_pre, model_full, expected_q.size()))

      occ_sample = expected_q.size();
      wr_sample = tr.wr_en;
      rd_sample = tr.rd_en;
      fifo_cg.sample();

      // Acceptance is deliberately derived from expected state, not from DUT flags.
      accept_read  = tr.rd_en && !model_empty;
      accept_write = tr.wr_en && !model_full;

      if (accept_read) begin
        expected_data = expected_q[0];
        if (tr.rdata_post !== expected_data)
          `uvm_error("FIFO_DATA", $sformatf("read mismatch: expected=0x%02h DUT=0x%02h", expected_data, tr.rdata_post))
        expected_q.pop_front();
        reads_checked++;
      end

      if (accept_write)
        expected_q.push_back(tr.wdata);

      if (tr.empty_post !== (expected_q.size() == 0))
        `uvm_error("FIFO_EMPTY", $sformatf("post-edge empty mismatch: DUT=%0b model occupancy=%0d", tr.empty_post, expected_q.size()))
      if (tr.full_post !== (expected_q.size() == FIFO_DEPTH))
        `uvm_error("FIFO_FULL", $sformatf("post-edge full mismatch: DUT=%0b model occupancy=%0d", tr.full_post, expected_q.size()))
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("FIFO_SB", $sformatf("Reads checked: %0d; functional coverage: %0.1f%%", reads_checked, fifo_cg.get_inst_coverage()), UVM_LOW)
    endfunction
  endclass

  class fifo_agent extends uvm_agent;
    `uvm_component_utils(fifo_agent)
    fifo_sequencer seqr;
    fifo_driver    drv;
    fifo_monitor   mon;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      is_active = UVM_ACTIVE;
      seqr = fifo_sequencer::type_id::create("seqr", this);
      drv  = fifo_driver::type_id::create("drv", this);
      mon  = fifo_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
  endclass

  class fifo_env extends uvm_env;
    `uvm_component_utils(fifo_env)
    fifo_agent      agent;
    fifo_scoreboard sb;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = fifo_agent::type_id::create("agent", this);
      sb    = fifo_scoreboard::type_id::create("sb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.mon.ap.connect(sb.analysis_export);
    endfunction
  endclass

  // Directed tests cover boundaries and simultaneous read/write policy.
  class fifo_directed_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_directed_seq)
    function new(string name = "fifo_directed_seq");
      super.new(name);
    endfunction

    task send(bit wr, bit rd, bit [7:0] data);
      fifo_item req = fifo_item::type_id::create("req");
      start_item(req);
      req.wr_en = wr;
      req.rd_en = rd;
      req.wdata = data;
      finish_item(req);
    endtask

    task body();
      // Fill all four locations, then attempt a blocked write at full.
      send(1, 0, 8'h11);
      send(1, 0, 8'h22);
      send(1, 0, 8'h33);
      send(1, 0, 8'h44);
      send(1, 0, 8'hEE);

      // At full, simultaneous request accepts read only; write is rejected.
      send(1, 1, 8'h55);
      send(0, 1, 8'h00);
      send(0, 1, 8'h00);
      send(0, 1, 8'h00);
      send(0, 1, 8'h00);
      send(0, 1, 8'h00); // Read while empty is ignored.

      // At empty, simultaneous request accepts write only; then read it back.
      send(1, 1, 8'hA5);
      send(0, 1, 8'h00);

      // With one item present, simultaneous read/write accepts both.
      send(1, 0, 8'h3C);
      send(1, 1, 8'hC3);
      send(0, 1, 8'h00);
      send(0, 0, 8'h00); // Leave the interface idle after the directed test.
    endtask
  endclass

  class fifo_random_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_random_seq)
    function new(string name = "fifo_random_seq");
      super.new(name);
    endfunction

    task body();
      fifo_item req;
      repeat (200) begin
        req = fifo_item::type_id::create("req");
        start_item(req);
        if (!req.randomize())
          `uvm_fatal("RANDFAIL", "Could not randomize FIFO sequence item")
        finish_item(req);
      end
      // An explicit idle item prevents the last random request being repeated.
      req = fifo_item::type_id::create("idle_req");
      start_item(req);
      req.wr_en = 1'b0;
      req.rd_en = 1'b0;
      req.wdata = '0;
      finish_item(req);
    endtask
  endclass

  class fifo_test extends uvm_test;
    `uvm_component_utils(fifo_test)
    fifo_env env;
    virtual fifo_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db #(virtual fifo_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "fifo_test did not receive virtual interface")
      env = fifo_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      fifo_directed_seq directed;
      fifo_random_seq random_seq;
      phase.raise_objection(this, "FIFO verification in progress");
      
      wait (vif.rst_n === 1'b0);
      wait (vif.rst_n === 1'b1);
      @(posedge vif.clk);
      directed = fifo_directed_seq::type_id::create("directed");
      directed.start(env.agent.seqr);
      random_seq = fifo_random_seq::type_id::create("random_seq");
      random_seq.start(env.agent.seqr);
      // Let the monitor publish the final sampled cycle before ending the test.
      @(posedge vif.clk);
      @(negedge vif.clk);
      phase.drop_objection(this, "FIFO sequences completed");
    endtask
  endclass

endpackage
