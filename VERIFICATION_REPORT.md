# Báo cáo xác minh FIFO bằng UVM



Flow được chạy với **Verilator 5.052** và **Accellera UVM 2020.3.2** trên Ubuntu. Đây là kết quả của lần chạy được lưu trong `sim.log` và `coverage.log`, không đại diện cho simulator thương mại hay regression nhiều seed.

## Cách tôi tổ chức việc xác minh

Trước khi kiểm tra, tôi xác định chính sách FIFO như sau:

- Ghi và đọc xảy ra tại cạnh lên.
- Reset bất đồng bộ, active-low.
- `rdata` cập nhật khi có read được chấp nhận; các chu kỳ khác giữ giá trị cũ.
- `full` và `empty` trước cạnh lên quyết định có nhận thao tác hay không.
- Khi empty, read+write chỉ nhận write. Khi full, read+write chỉ nhận read. Khi partial, nhận cả hai.

Testbench tách stimulus và checking. Sequence sinh request một chu kỳ. Driver lái tín hiệu ở cạnh xuống. Monitor lấy request/cờ trước cạnh lên và output/cờ sau cập nhật. Scoreboard quyết định thao tác được nhận dựa trên occupancy của queue model, không dựa vào cờ DUT để tạo expected result. Với read được chấp nhận, scoreboard so sánh `rdata` với phần tử cũ nhất trong queue và cập nhật reference model.

## Các thành phần testbench

| Thành phần | Vai trò |
|---|---|
| `fifo_item` | Gói `wr_en`, `rd_en`, `wdata` cho một chu kỳ và dữ liệu monitor lấy mẫu. |
| `fifo_sequencer` | Cấp item cho driver. |
| `fifo_driver` | Lái request trên interface đồng bộ với clock. |
| `fifo_monitor` | Quan sát request, status trước cạnh và kết quả sau cạnh; phát qua analysis port. |
| `fifo_scoreboard` | Queue reference model; so sánh read data và cờ FIFO; lấy functional coverage. |
| `fifo_agent` / `fifo_env` | Kết nối sequencer, driver, monitor và scoreboard. |
| `fifo_directed_seq` | Tạo tình huống biên và simultaneous operation. |
| `fifo_random_seq` | Sinh 200 request random có ràng buộc, sau đó một item idle. |
| `fifo_test` / `tb_top` | Chạy sequence và tạo clock, reset, DUT, virtual interface. |

## Kịch bản đã chạy

Directed sequence gồm 17 request: ghi bốn giá trị `0x11`, `0x22`, `0x33`, `0x44` để lấp FIFO; thử ghi thêm khi full; read+write đồng thời lúc full; đọc FIFO theo thứ tự đến empty; thử read lúc empty; read+write lúc empty; và read+write ở partial occupancy. Tiếp theo là 200 request ngẫu nhiên và một item idle.

Trong lần chạy này, scoreboard báo đã kiểm tra **87 lượt đọc được chấp nhận**.

## Kết quả trong log

| Chỉ số | Kết quả |
|---|---:|
| Simulator | Verilator 5.052, release ngày 2026-09-05 |
| UVM | Accellera 2020.3.2 |
| Read data được scoreboard kiểm tra | 87 |
| UVM error / fatal | 0 / 0 |
| UVM runtime warning | 2 |
| Functional covergroup | 100.0% (29 / 29 bins đã định nghĩa) |
| Toggle coverage | 100.0% (172 / 172 toggle được báo cáo) |
| Line coverage tổng hợp | 26.5% (3,109 / 11,745 điểm) |
| Branch coverage tổng hợp | 12.1% (1,934 / 15,983 điểm) |
| Expression coverage tổng hợp | 16.4% (318 / 1,942 điểm) |
| FSM state / arc | 0 / 0 điểm |
| Annotation summary | 6.00% dòng có tất cả attached points được cover (1,355 / 20,410) |
| Kết thúc mô phỏng | `$finish` tại 2 us; wall time báo cáo 2.954 s |

Coverage code là số tổng hợp của các nguồn được instrument, gồm UVM, testbench và DUT. Log không đưa ra line coverage riêng cho DUT. Vì vậy, report này **không tuyên bố 100% line coverage cho RTL**. Tương tự, functional coverage 29/29 chỉ nói rằng mọi bin trong covergroup cụ thể đã được hit, không có nghĩa đã xác minh hết mọi hành vi FIFO.

### Phạm vi functional coverage

Covergroup trong `fifo_scoreboard` lấy mẫu occupancy model từ 0 đến 4, `wr_en`, `rd_en` và cross của ba coverpoint. Tổng 29 bins gồm 5 occupancy bins, 2 write bins, 2 read bins và 20 cross bins `occupancy × wr_en × rd_en`.

Covergroup này không đo trực tiếp các trường hợp reset, mẫu dữ liệu, việc `rdata` giữ nguyên, assertion coverage hay toàn bộ tình huống recovery/error.

## Phân tích warning

### Hai UVM runtime warnings

Log có 2 warning, 0 UVM error và 0 fatal:

1. **`NO_DPI_USED`** — Do build định nghĩa `UVM_NO_DPI`; UVM khuyến nghị thử chạy không có define này.
2. **`NO_VISIT_CHECK`** — Do `UVM_REGEX_NO_DPI` được định nghĩa, UVM không kiểm tra các ràng buộc tên component.

Đây là giới hạn do cấu hình UVM không dùng DPI. Vì vậy các kiểm tra tên component cần DPI không được thực hiện trong lần chạy này.

Verilator compile

Build hoàn tất với `-Wall -Wno-fatal`, nhưng log ghi 311 compile warnings:

| Nhóm | Số lượng |
|---|---:|
| `WIDTHTRUNC` | 147 |
| `WIDTHEXPAND` | 144 |
| `UNUSEDSIGNAL` | 13 |
| `TIMESCALEMOD` | 3 |
| `DECLFILENAME` | 1 |
| `PROCASSINIT` | 1 |
| `SYNCASYNCNET` | 1 |
| `UNDRIVEN` | 1 |

Hai warning width trong RTL liên quan các localparam `LAST_PTR` và `DEPTH_COUNT`. Phần lớn warning width khác xuất hiện trong expansion của macro field-automation UVM. Mô phỏng hoàn tất, nhưng build chưa sạch warning.

8. Giới hạn

- Coverage code là kết quả tổng hợp, không tách riêng DUT.
- Covergroup không đo trực tiếp reset, mẫu dữ liệu, `rdata` hold hay assertion coverage.
- Build có 311 compile warnings; simulation có hai UVM warning liên quan DPI.
- Kết quả chỉ đại diện cho Verilator 5.052 và UVM 2020.3.2; chưa có kết quả từ Questa, VCS hoặc Xcelium.

## 9. Tóm tắt dự án

Testbench SystemVerilog/UVM cho FIFO đồng bộ 8-bit × 4 với directed và constrained-random stimulus, queue-based reference scoreboard, assertion và functional coverage. Trong lần chạy được ghi lại, scoreboard kiểm tra 87 lượt đọc, UVM report không có error/fatal và covergroup đạt 29/29 bins. Build vẫn có compile warnings, simulation có hai UVM warning và log chưa lưu seed.




