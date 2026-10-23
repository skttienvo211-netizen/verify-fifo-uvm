8-bit × 4 Synchronous FIFO — UVM Verification

## Project overview

A FIFO (First-In, First-Out) stores data in arrival order. A synchronous FIFO is commonly used to buffer bursts and separate data flow between blocks that share a clock, such as datapath stages or a producer and consumer with different short-term processing rates.



**Tools:** Ubuntu, Verilator 5.052, Accellera UVM 2020.3.2.

## Design behavior

- Reads and writes are sampled on the rising clock edge.
- Reset is asynchronous and active-low.
- `rdata` updates only when a read is accepted; otherwise it holds its value.
- Operations use `full` and `empty` before the rising edge.
- At empty, simultaneous read/write accepts only the write.
- At full, simultaneous read/write accepts only the read.
- At intermediate occupancy, both operations are accepted.

The RTL has `DATA_W` and `DEPTH` parameters. The verification setup tests 8-bit data and depth 4.

## Verification environment

```text
fifo_test → sequence → sequencer → driver → interface → DUT
                                      DUT → interface → monitor → scoreboard
```

The UVM testbench includes directed and constrained-random sequences, an active agent, a monitor, a queue-based reference scoreboard, an assertion, and functional coverage. The directed sequence checks full/empty boundaries, FIFO ordering, and simultaneous operations. The random sequence generates 200 requests.



## Simulation results

Results from the supplied Verilator 5.052 / UVM 2020.3.2 logs:

| Metric | Result |
|---|---:|
| Scoreboard reads checked | 87 |
| UVM errors / fatals | 0 / 0 |
| Functional covergroup | 29 / 29 defined bins |
| Toggle coverage | 172 / 172 reported toggles |
| Aggregate line / branch / expression coverage | 26.5% / 12.1% / 16.4% |
| UVM runtime warnings | 2 |
| Verilator compile warnings | 311 (`-Wno-fatal`) |

Aggregate code coverage includes the instrumented UVM library, testbench, and DUT; it is not DUT-only coverage. The functional coverage result applies only to the defined covergroup. The simulation log does not record an explicit seed. See [the verification report](VERIFICATION_REPORT_EN.md) for details.

## Repository contents

- `rtl/fifo_sync.sv`: FIFO RTL design.
- `tb/fifo_if.sv`: interface between DUT and testbench.
- `tb/fifo_uvm_pkg.sv`: UVM components, sequences, and scoreboard.
- `tb/tb_top.sv`: simulation top.
- `Makefile`: build, simulation, coverage, and waveform targets.
