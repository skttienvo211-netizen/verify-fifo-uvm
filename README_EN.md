# 8-bit × 4 FIFO UVM Verification

This project verifies a synchronous FIFO with 8-bit data and 4 entries. It uses SystemVerilog, UVM 2020.3.2, and Verilator 5.052.

## What I built

- A FIFO RTL design and UVM testbench.
- Directed tests for full, empty, simultaneous read/write, and FIFO ordering.
- 200 constrained-random requests.
- An independent queue-based scoreboard to check read data and `full`/`empty` flags.
- Assertions and functional coverage.

## Results from the supplied logs

| Metric | Result |
|---|---:|
| Scoreboard reads checked | 87 |
| UVM errors / fatals | 0 / 0 |
| UVM warnings | 2 (DPI-related) |
| Functional covergroup | 29 / 29 bins |
| Toggle coverage | 172 / 172 reported toggles |
| Aggregate line coverage | 26.5%; includes UVM/testbench and DUT |
| Verilator compile warnings | 311; build used `-Wno-fatal` |

The logs do not include an explicit random seed. See [the short report](VERIFICATION_REPORT_EN.md) for warning details and coverage limits.

## Run

Set `UVM_HOME` to the UVM `src` folder, then run from the project root:

```bash
make clean
make build
make sim
make coverage
```

`make sim` builds the project before running it. `make coverage` reports the collected data.

## FIFO policy

Operations are accepted using `full` and `empty` before the rising clock edge. At empty, simultaneous read/write accepts only the write. At full, it accepts only the read. At intermediate occupancy, both are accepted.

See [Verilator UVM status](https://github.com/verilator/verilator/issues/1538) for known limitations of this open-source simulator flow.
