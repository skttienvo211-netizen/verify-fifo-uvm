# Xác minh FIFO đồng bộ 8-bit × 4 bằng UVM

Dự án này xác minh một FIFO đồng bộ có độ rộng dữ liệu 8 bit và sức chứa 4 phần tử. Repository gồm RTL DUT và testbench SystemVerilog/UVM với test định hướng, dữ liệu ngẫu nhiên có ràng buộc, scoreboard dùng reference model độc lập, assertion và coverage.

> **Công cụ:** Verilator 5.052, Accellera UVM 2020.3.2, Ubuntu. Đây là flow học tập với simulator mã nguồn mở. Verilator có các giới hạn UVM đã biết; không ghi đây là kết quả từ Questa/VCS/Xcelium nếu chưa chạy trên simulator đó. Xem [report xác minh](VERIFICATION_REPORT.md) để biết chi tiết log và giới hạn.

## Kết quả từ log hiện có

| Chỉ số | Kết quả |
|---|---:|
| Giao dịch định hướng | 17 |
| Giao dịch ngẫu nhiên có ràng buộc | 200 |
| Lượt đọc được scoreboard kiểm tra | 87 / 87 |
| UVM error / fatal | 0 / 0 |
| UVM runtime warning | 2 (`NO_DPI_USED`, `NO_VISIT_CHECK`) |
| Functional covergroup | 29 / 29 bins đã định nghĩa |
| Toggle coverage | 172 / 172 toggle được báo cáo |
| Line coverage tổng hợp | 26.5% (3,109 / 11,745 điểm instrumented; không riêng DUT) |
| Verilator compile warnings | 311; build dùng `-Wno-fatal` |

Các phần trăm coverage chỉ áp dụng cho covergroup và các điểm được instrument trong lần chạy này. Log không ghi seed tường minh. Đây không phải tuyên bố đã xác minh đầy đủ mọi hành vi FIFO hay đạt 100% line coverage riêng cho RTL. Xem [VERIFICATION_REPORT.md](VERIFICATION_REPORT.md).

## Đặc tả DUT

- Ghi và đọc được lấy mẫu ở cạnh lên của `clk`.
- Reset bất đồng bộ, tích cực mức thấp (`rst_n`).
- `rdata` là output đã đăng ký: chỉ cập nhật khi đọc được chấp nhận, ngoài ra giữ giá trị cũ.
- Việc chấp nhận thao tác dựa trên `full`/`empty` trước cạnh lên.
- Khi empty và cùng bật đọc/ghi: chỉ ghi được nhận. Khi full và cùng bật đọc/ghi: chỉ đọc được nhận. Ở occupancy giữa 0 và 4: nhận cả đọc lẫn ghi.

## Cấu trúc project

```text
.
├── rtl/
│   └── fifo_sync.sv
├── tb/
│   ├── fifo_if.sv
│   ├── fifo_uvm_pkg.sv
│   └── tb_top.sv
├── Makefile
├── README.md
├── README_EN.md
├── VERIFICATION_REPORT.md
└── VERIFICATION_REPORT_EN.md
```

## Cài đặt và chạy trên Ubuntu

Cần Verilator 5.052, UVM 2020.3.2 và GCC/G++ 10 trở lên để hỗ trợ chế độ timing của flow này. Cài các gói build:

```bash
sudo apt update
sudo apt install -y git autoconf help2man perl python3 make g++ flex bison libfl-dev zlib1g-dev gtkwave
```

Build UVM từ source Verilator tag `v5.052` nếu cần theo hướng dẫn chính thức của Verilator. Tải UVM 2020.3.2 từ [Accellera](https://www.accellera.org/downloads/standards/uvm), giải nén, rồi đặt `UVM_HOME` vào thư mục chứa `uvm_pkg.sv` và `uvm_macros.svh`:

```bash
export UVM_HOME="$HOME/tools/uvm-2020.3.2/src"
test -f "$UVM_HOME/uvm_pkg.sv" && test -f "$UVM_HOME/uvm_macros.svh" && echo "UVM_HOME OK"
```

Tại thư mục gốc repository:

```bash
make clean
make build
make sim
make coverage
```

`make sim` phụ thuộc vào `build`, nên tự build lại trước khi chạy. Kết quả coverage được ghi vào `build/coverage.dat`; `make coverage` in summary và annotate source vào `build/coverage_annotated/`.

Để chạy binary với seed và coverage file riêng:

```bash
seed=12345
./build/Vtb_top +UVM_TESTNAME=fifo_test +UVM_VERBOSITY=UVM_MEDIUM \
  +verilator+seed+$seed +verilator+coverage+file+build/coverage_${seed}.dat
verilator_coverage --report summary build/coverage_${seed}.dat
```

Log `sim.log` không có seed được truyền vào, vì vậy seed của kết quả hiện tại chưa được ghi nhận. Ở lần chạy tiếp theo, lưu seed và log cùng nhau để có thể tái hiện kết quả. Verilator ghi rõ tùy chọn seed runtime là `+verilator+seed+<value>` trong [tài liệu chính thức](https://verilator.org/guide/latest/exe_sim.html).

## Cách testbench hoạt động

```text
fifo_test → sequence → sequencer → driver → interface → DUT
                                      DUT → interface → monitor → scoreboard
```

- Directed sequence lấp FIFO, thử ghi lúc full, rút dữ liệu, thử đọc lúc empty và thử đọc/ghi đồng thời ở full, empty và partial.
- Random sequence sinh 200 request có ràng buộc rồi thêm một chu kỳ idle.
- Driver đổi input ở cạnh xuống để ổn định trước cạnh lấy mẫu của DUT.
- Monitor ghi request/status trước cạnh lên và output/status sau cạnh lên.
- Scoreboard dùng queue độc lập để dự đoán thao tác được nhận, so sánh dữ liệu đọc và cờ `full`/`empty`.
- Assertion trong DUT kiểm tra occupancy không vượt sức chứa.

## Các điểm còn cần hoàn thiện

- Hai UVM runtime warnings do cấu hình `UVM_NO_DPI` cần được giữ rõ trong báo cáo; chúng làm mất một số kiểm tra tên component của UVM.
- Build hiện có 311 cảnh báo Verilator và dùng `-Wno-fatal`; cần xem xét warning trong RTL/testbench và phân biệt với warning từ macro UVM.
- Coverage line/branch/expression trong `coverage.log` là tổng hợp trên các nguồn đã instrument, bao gồm UVM/testbench và DUT; chưa có báo cáo line coverage riêng cho DUT.
- Covergroup hiện đo occupancy, `wr_en`, `rd_en` và cross của chúng; chưa đo trực tiếp reset, mẫu dữ liệu, `rdata` giữ giá trị, hoặc assertion coverage.
- Nên lưu seed và log đầy đủ cho mỗi lần chạy, đồng thời thêm kiểm tra tự động để regression thất bại nếu có UVM error/fatal hoặc assertion failure.

## Tài liệu tham khảo

- [Hướng dẫn cài Verilator](https://verilator.org/guide/latest/install.html)
- [Runtime arguments của Verilator](https://verilator.org/guide/latest/exe_sim.html)
- [Trạng thái và giới hạn hỗ trợ UVM của Verilator](https://github.com/verilator/verilator/issues/1538)
- [Tải Accellera UVM](https://www.accellera.org/downloads/standards/uvm)
- [Phân tích coverage của Verilator](https://verilator.org/guide/latest/simulating.html#coverage-analysis)


