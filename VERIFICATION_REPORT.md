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

Đây là warning do cấu hình UVM, không phải báo lỗi dữ liệu FIFO. Tuy nhiên, lần chạy này không xác minh các kiểm tra tên component dựa trên DPI của UVM. Log cũng có thông tin `UVM/COMP/NAMECHECK` cho biết cơ chế kiểm tra tên component cần DPI.

### Cảnh báo lúc compile từ Verilator

Build đã hoàn tất với `-Wall -Wno-fatal`, nghĩa là warning không dừng build. Đếm các dòng `%Warning-...` trong `sim.log` có **311 cảnh báo compile**:

| Nhóm | Số lượng | Ví dụ trong log |
|---|---:|---|
| `WIDTHTRUNC` | 147 | 2 cảnh báo ở localparam DUT (`LAST_PTR`, `DEPTH_COUNT`); phần lớn còn lại ở phần mở rộng macro field-automation của UVM. |
| `WIDTHEXPAND` | 144 | Chủ yếu ở phần mở rộng macro field-automation của UVM. |
| `UNUSEDSIGNAL` | 13 | Có tín hiệu interface/testbench và tín hiệu coverage được sinh. |
| `TIMESCALEMOD` | 3 | RTL/package thiếu time scale trong khi `tb_top` khai báo time scale. |
| `DECLFILENAME` | 1 | File package chứa class có tên khác file. |
| `PROCASSINIT` | 1 | `clk` vừa khởi tạo tại khai báo vừa được gán trong tiến trình clock. |
| `SYNCASYNCNET` | 1 | Reset dùng trong reset bất đồng bộ của DUT và kiểm tra đồng bộ. |
| `UNDRIVEN` | 1 | Tín hiệu coverage nội bộ được sinh. |

Do đó, kết quả là **mô phỏng hoàn tất nhưng còn warning**, không phải build sạch warning. Nên xử lý trước hai width warning ở localparam DUT và sự không thống nhất time scale; sau đó đánh giá riêng warning từ macro UVM và warning của RTL/testbench. Không nên tắt cả nhóm warning rộng khi chưa hiểu nguyên nhân.




