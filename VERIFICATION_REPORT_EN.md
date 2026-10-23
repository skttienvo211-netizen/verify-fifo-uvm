# FIFO UVM Verification Report

## Project

I verified an 8-bit, 4-entry synchronous FIFO using SystemVerilog, UVM 2020.3.2, and Verilator 5.052. The testbench has directed and random sequences, a queue-based scoreboard, assertions, and functional coverage.

## Test and results

The directed sequence has 17 request items. It fills and drains the FIFO, checks blocked operations at full/empty, and tests simultaneous read/write. The random sequence generates 200 requests and then an idle item.

| Check | Result in the supplied logs |
|---|---:|
| Accepted reads checked by scoreboard | 87 |
| UVM errors / fatals | 0 / 0 |
| Functional covergroup | 29 / 29 bins |
| Toggle coverage | 172 / 172 reported toggles |
| Aggregate line / branch / expression coverage | 26.5% / 12.1% / 16.4% |
| Verilator compile warnings | 311 |

Coverage figures are limited to the instrumented sources and defined covergroup. They are not DUT-only line coverage or proof of complete verification.

## Warnings and limits

The two UVM warnings are `NO_DPI_USED` and `NO_VISIT_CHECK`. They result from the `UVM_NO_DPI` configuration; component-name checks that need DPI are not performed.

The build used `-Wno-fatal`, so compile warnings did not stop it. The run completed with 0 UVM errors and 0 fatals, but it was not warning-clean. The simulation log contains no explicit random seed.

## CV summary

> Built and ran a SystemVerilog/UVM testbench for an 8-bit × 4 synchronous FIFO. Checked 87 accepted reads with a queue-based scoreboard and hit all 29 bins in the configured occupancy/read/write covergroup using Verilator 5.052 and UVM 2020.3.2.

The reported run had two UVM configuration warnings and 311 compile warnings; do not describe it as warning-free or claim 100% DUT line coverage.
