# FIFO 8-bit × 4 UVM verification project

> **Mục tiêu:** một project nhỏ nhưng có đủ các thành phần cơ bản của block-level Design Verification: RTL DUT, SystemVerilog interface, UVM sequence item/sequencer/driver/monitor/agent/environment/scoreboard/test, directed và constrained-random stimulus, assertion, functional coverage, waveform và hướng dẫn chạy trên Ubuntu.

> **Simulator của hướng dẫn:** Verilator **5.052** với UVM **2020.3.2**. Verilator 5.052 công bố hỗ trợ UVM 2020.3.2; đây là lựa chọn miễn phí để luyện tập. Nó vẫn có một số giới hạn so với simulator thương mại. Testbench này tránh clocking block của virtual interface và không dựa vào giá trị X/Z. Nếu trường có Questa/VCS/Xcelium, hãy chạy cùng project trên simulator đó nữa và ghi đúng công cụ đã dùng trong CV.

## 1. Đặc tả FIFO trước khi viết code

FIFO là synchronous FIFO (cả ghi và đọc theo cạnh lên của `clk`), dữ liệu rộng 8 bit, chứa tối đa 4 từ. Reset bất đồng bộ, active-low (`rst_n=0`). `rdata` là ngõ ra đã đăng ký: nó cập nhật ở cạnh lên khi một thao tác đọc được chấp nhận và giữ giá trị cũ ở các chu kỳ khác.

| Trạng thái trước cạnh lên | `wr_en` | `rd_en` | Kết quả |
|---|---:|---:|---|
| Empty | 0 | 1 | Bỏ qua đọc; vẫn empty |
| Empty | 1 | 1 | Chỉ ghi; dữ liệu mới nằm trong FIFO |
| Partial | 1 | 1 | Đọc từ cũ ở đầu FIFO và ghi từ mới; occupancy giữ nguyên |
| Full | 1 | 0 | Bỏ qua ghi; vẫn full |
| Full | 1 | 1 | Chỉ đọc; ghi bị từ chối theo chính sách đã chọn |

Quy tắc chấp nhận được xác định theo `full/empty` **trước** cạnh lên. Đây là điểm quan trọng: một FIFO khác có thể cho phép ghi đồng thời khi full nếu có đọc trong cùng chu kỳ; nếu đổi chính sách, phải đổi cả DUT và reference model/scoreboard.

## 2. Cấu trúc project

```text
fifo_uvm_lab/
├── rtl/
│   └── fifo_sync.sv       # DUT: bộ nhớ, read/write pointer, occupancy
├── tb/
│   ├── fifo_if.sv         # Interface nối DUT với testbench
│   ├── fifo_uvm_pkg.sv    # Các class UVM và reference model
│   └── tb_top.sv          # Clock, reset, DUT, cấu hình virtual interface
├── Makefile               # Lệnh build, chạy mô phỏng, báo cáo coverage
└── .gitignore
```

## 3. Cài bộ công cụ trên Ubuntu

Nên dùng Ubuntu 22.04/24.04 hoặc môi trường Ubuntu có GCC/G++ 10 trở lên, vì chế độ timing của Verilator cần compiler hỗ trợ C++20 coroutine.

### 3.1 Cài các gói build

```bash
sudo apt update
sudo apt install -y git autoconf help2man perl python3 make g++ flex bison libfl-dev zlib1g-dev
g++ --version
```

### 3.2 Build Verilator 5.052

Gói `verilator` trong kho Ubuntu có thể cũ hơn phiên bản cần cho flow UVM này. Build bản release 5.052 từ source:

```bash
mkdir -p "$HOME/tools"
cd "$HOME/tools"
git clone --depth 1 --branch v5.052 https://github.com/verilator/verilator.git
cd verilator
autoconf
./configure
make -j"$(nproc)"
sudo make install
verilator --version
```

Kiểm tra output có `Verilator 5.052`.

### 3.3 Tải UVM 2020.3.2

Tải **UVM 2020-3.2 Reference Implementation** từ [trang tải UVM chính thức của Accellera](https://www.accellera.org/downloads/standards/uvm), giải nén vào một thư mục riêng, ví dụ `$HOME/tools/uvm-2020.3.2/`.

Tìm file package:

```bash
find "$HOME/tools/uvm-2020.3.2" -name uvm_pkg.sv -print
```

Đặt `UVM_HOME` bằng thư mục `src` chứa `uvm_pkg.sv` và `uvm_macros.svh`. Ví dụ:

```bash
export UVM_HOME="$HOME/tools/uvm-2020.3.2/src"
test -f "$UVM_HOME/uvm_pkg.sv" && echo "UVM_HOME OK"
```

Nếu file tìm thấy ở đường dẫn khác, hãy sửa giá trị `UVM_HOME` cho đúng. Không cần chép source UVM vào repository project.

## 4. Hiểu RTL DUT: `rtl/fifo_sync.sv`

- `mem[0:DEPTH-1]` lưu bốn từ 8-bit.
- `wr_ptr` trỏ tới vị trí ghi tiếp theo; `rd_ptr` trỏ tới từ cũ nhất.
- `count` lưu số phần tử hiện có. `empty = (count == 0)` và `full = (count == 4)`.
- `do_write = wr_en && !full`; `do_read = rd_en && !empty`. Chúng hiện thực chính sách đã ghi trong đặc tả.
- Khi ghi/đọc ở phần tử cuối, pointer quay về 0. Cách này vẫn đúng nếu sau này thử depth không phải lũy thừa của 2.
- `case ({do_write, do_read})` tăng count khi chỉ ghi, giảm count khi chỉ đọc và giữ nguyên count khi cả hai cùng được chấp nhận hoặc cả hai đều không được chấp nhận.
- `rdata` chỉ thay đổi khi `do_read=1`; vì là register, monitor lấy giá trị sau cạnh lên để so với từ đầu queue.
- Assertion kiểm tra occupancy không vượt quá depth. `--assert` bật kiểm tra đó khi chạy Verilator.

## 5. Hiểu UVM testbench

### Transaction và stimulus

`fifo_item` là transaction một chu kỳ, gồm `wr_en`, `rd_en`, `wdata`. Các trường `*_pre` và `*_post` là dữ liệu monitor ghi nhận để scoreboard dùng. Constraint tạo ngẫu nhiên hai enable; dữ liệu ghi là giá trị 8-bit ngẫu nhiên.

`fifo_directed_seq` chủ động tạo các tình huống biên: đổ đầy FIFO, ghi khi full, đọc và ghi cùng lúc khi full, đọc đến empty, đọc khi empty, cùng lúc đọc/ghi ở empty và ở partial. `fifo_random_seq` tiếp tục 200 transaction ngẫu nhiên rồi gửi một transaction idle để không lặp lại yêu cầu cuối.

### Driver, monitor, scoreboard

`fifo_driver` lấy item qua `seq_item_port`, lái input ở cạnh xuống và hoàn tất item sau cạnh lên kế tiếp. Như vậy input ổn định trước khi DUT lấy mẫu ở cạnh lên.

`fifo_monitor` đọc input và `full/empty` trước cạnh lên; nó đợi cạnh xuống tiếp theo để lấy `rdata` và status sau cập nhật nonblocking của DUT, rồi phát transaction qua `uvm_analysis_port`.

`fifo_scoreboard` giữ một queue độc lập làm reference model. Nó tự tính nhận/từ chối giao dịch từ occupancy dự đoán, không lấy cờ DUT làm đáp án. Với mỗi cycle, nó so sánh cờ trước cạnh, dữ liệu đọc (nếu read được chấp nhận), rồi so sánh cờ sau cạnh. Nó cũng thu functional coverage theo occupancy, write/read enable và cross của chúng.

### Agent, environment, test và top

`fifo_agent` gắn sequencer, driver và monitor thành một active agent. `fifo_env` nối analysis port của monitor tới scoreboard. `fifo_test` chạy directed sequence trước, random sequence sau và giữ objection cho tới khi monitor kịp phát transaction cuối. `tb_top` tạo clock/reset, instantiate DUT/interface, đưa virtual interface vào `uvm_config_db` rồi gọi `run_test`.

Luồng dữ liệu:

```text
fifo_test → sequence → sequencer → driver → interface → DUT
                                      interface → monitor → analysis port → scoreboard
```

## 6. Build và chạy

Từ thư mục gốc của project:

```bash
export UVM_HOME="$HOME/tools/uvm-2020.3.2/src"
make build
make sim
```

`make build` gọi Verilator với `--timing` cho clock/delay, `--assert` cho assertion, `--coverage` cho code và functional coverage, `+define+UVM_NO_DPI` cho flow Verilator, rồi tạo `build/Vtb_top`.

`make sim` chạy test `fifo_test`, hiển thị log UVM mức `UVM_MEDIUM` và ghi coverage vào `build/coverage.dat`. Kết quả tốt là simulation kết thúc bình thường, không có `UVM_ERROR`/assertion failure, và scoreboard báo số lần đọc đã kiểm tra cùng phần trăm functional coverage. Coverage có thể chưa đạt 100%; hãy xem bin nào chưa hit và bổ sung stimulus thay vì chỉ kéo dài random.

Đọc báo cáo coverage sau khi mô phỏng:

```bash
make coverage
```

Lệnh này in summary và tạo source đã annotate trong `build/coverage_annotated/`.

Đổi seed để tạo thêm một lần chạy ngẫu nhiên:

```bash
./build/Vtb_top +UVM_TESTNAME=fifo_test +ntb_random_seed=12345 \
  +UVM_VERBOSITY=UVM_MEDIUM +verilator+coverage+file+build/seed_12345.dat
verilator_coverage --report summary build/seed_12345.dat
```

### Xem waveform (tùy chọn)

Cài GTKWave, build với trace và mở VCD:

```bash
sudo apt install -y gtkwave
make waves
gtkwave fifo.vcd
```

Trong waveform, quan sát `wr_en`, `rd_en`, `wdata`, `rdata`, `full`, `empty`; kiểm tra pointer/count bên trong DUT nếu bật hiển thị internal signals.

## 7. Checklist kết quả cần tự kiểm tra

- Reset đưa FIFO về `empty=1`, `full=0`.
- Bốn lần ghi làm `full` lên 1; lần ghi thứ năm không làm đổi dữ liệu FIFO.
- Read khi full + write cùng lúc chỉ pop từ cũ nhất.
- Đọc theo đúng thứ tự FIFO: `11`, `22`, `33`, `44` ở đoạn directed đầu.
- Read khi empty bị bỏ qua; `empty` vẫn bằng 1.
- Read + write ở empty chỉ ghi; read + write ở partial vừa trả từ cũ vừa giữ từ mới trong FIFO.
- `rdata` chỉ được kiểm tra khi scoreboard xác định read đã được chấp nhận.
- Không có `UVM_ERROR`, assertion failure; coverage report cho thấy các occupancy states và các case directed đã được hit.

Nếu có mismatch, bắt đầu từ cycle đầu tiên có `UVM_ERROR`: so sánh `full_pre/empty_pre`, `wr_en/rd_en`, occupancy model, `rdata_post`, rồi waveform. Đừng sửa scoreboard để “khớp” DUT; xác nhận đặc tả trước và sửa RTL hoặc reference model đúng theo đặc tả.

## 8. Đưa project lên GitHub và ghi vào CV

Trước khi đưa vào CV, hãy tự chạy các bước trên Ubuntu, sửa mọi warning/lỗi, lưu seed, coverage report và một ảnh waveform có chú thích. README GitHub nên ghi rõ simulator/version, seed, số giao dịch, số read được scoreboard kiểm tra, coverage đạt được và các limitation còn lại. Không ghi “100% coverage” nếu report không chứng minh điều đó.

Ví dụ bullet CV (điền bằng số liệu bạn thực sự thu được):

> **FIFO UVM Verification (SystemVerilog, UVM 2020.3.2, Verilator 5.052)** — Built a reusable UVM agent and reference-model scoreboard for an 8-bit × 4 synchronous FIFO; verified reset, empty/full blocking, pointer wraparound, simultaneous read/write policies, and randomized traffic; collected functional coverage and debugged failures with VCD/GTKWave.

Khi đã truy cập được simulator công nghiệp ở trường, chạy lại cùng môi trường bằng Questa/VCS/Xcelium và ghi simulator thực sự dùng. Đó là phần giúp dự án gần flow DV ở công ty hơn.

## Tài liệu chính thức

- [Verilator 5.052 installation guide](https://verilator.org/guide/latest/install.html)
- [Verilator UVM support status and remaining limitations](https://github.com/verilator/verilator/issues/1538)
- [Accellera UVM download page](https://www.accellera.org/downloads/standards/uvm)
- [Verilator coverage guide](https://verilator.org/guide/latest/simulating.html#coverage-analysis)
