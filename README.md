# Xác minh FIFO đồng bộ 8-bit × 4 bằng UVM
Tác giả : Võ Minh Tiến 
## Tổng quan dự án

FIFO (First-In, First-Out) là bộ đệm phần cứng lưu dữ liệu theo thứ tự đến trước, đọc ra trước. FIFO đồng bộ thường được dùng để đệm dữ liệu dạng burst và tách nhịp truyền giữa các khối cùng miền clock, chẳng hạn giữa hai stage của datapath hoặc giữa producer và consumer có tốc độ xử lý tức thời khác nhau.

Dự án này xác minh một FIFO đồng bộ có độ rộng dữ liệu 8 bit và sức chứa 4 phần tử. Repository gồm RTL DUT và testbench SystemVerilog/UVM với test định hướng, dữ liệu ngẫu nhiên có ràng buộc, scoreboard dùng reference model độc lập, assertion và coverage.

> **Công cụ:** Verilator 5.052, Accellera UVM 2020.3.2, Ubuntu.
> ## Đặc tả hoạt động của FIFO

- Đọc và ghi được lấy mẫu tại cạnh lên của `clk`.
- Reset bất đồng bộ, active-low (`rst_n`).
- `rdata` là output đã đăng ký: cập nhật khi read được chấp nhận, ngoài ra giữ giá trị cũ.
- `full` và `empty` trước cạnh lên quyết định request có được nhận hay không.
- Khi empty và cùng bật đọc/ghi: chỉ write được nhận.
- Khi full và cùng bật đọc/ghi: chỉ read được nhận.
- Ở occupancy trung gian: read và write cùng được nhận.

RTL có các tham số `DATA_W` và `DEPTH`; verification configuration của project kiểm tra cấu hình 8 bit × 4 phần tử.




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

Build Verilator từ source Verilator tag `v5.052` nếu cần theo hướng dẫn chính thức của Verilator. Tải UVM 2020.3.2 từ [Accellera](https://www.accellera.org/downloads/standards/uvm), giải nén, rồi đặt `UVM_HOME` vào thư mục chứa `uvm_pkg.sv` và `uvm_macros.svh`:

```bash
export UVM_HOME="$HOME/tools/uvm-2020.3.2/src"
test -f "$UVM_HOME/uvm_pkg.sv" && test -f "$UVM_HOME/uvm_macros.svh" && echo "UVM_HOME OK"
```

Tại thư mục gốc dự án:

```bash
make clean
make build
make sim
make coverage
```




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



## Giới hạn của phiên bản hiện tại

- Chưa có seed tường minh trong log.
- Chưa có line/branch/expression coverage được tách riêng cho RTL DUT.
- Covergroup chưa đo trực tiếp reset scenarios, mẫu dữ liệu, `rdata` hold hoặc assertion coverage.
- Build còn compile warnings; UVM runtime cũng có hai cảnh báo do cấu hình không dùng DPI.
- Các kết quả hiện có thuộc Verilator 5.052 và UVM 2020.3.2.
  
## Xem [report xác minh](VERIFICATION_REPORT.md) để biết chi tiết log và giới hạn.
## Tài liệu tham khảo

- [Hướng dẫn cài Verilator](https://verilator.org/guide/latest/install.html)
- [Runtime arguments của Verilator](https://verilator.org/guide/latest/exe_sim.html)
- [Trạng thái và giới hạn hỗ trợ UVM của Verilator](https://github.com/verilator/verilator/issues/1538)
- [Tải Accellera UVM](https://www.accellera.org/downloads/standards/uvm)
- [Phân tích coverage của Verilator](https://verilator.org/guide/latest/simulating.html#coverage-analysis)


