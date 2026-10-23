# FIFO UVM Verification Report & Sign-off
> **Dự án:** 8-bit × 4 Synchronous FIFO Verification  
> **Simulator:** Verilator 5.052 with Z3 SMT Solver & GTKWave  
> **Trạng thái:** **PASSED (100% Functional & Toggle Coverage)**  
[⬅ Quay lại trang chủ README.md](README.md)
---
## 1. Kết quả Tổng kết (Executive Summary)
* **UVM Test Status:** **PASSED** (`UVM_ERROR: 0`, `UVM_FATAL: 0`).
* **Scoreboard:** Hoàn thành đối soát chính xác **87/87 giao dịch đọc** so với Golden Reference Model.
* **Functional Coverage:** **100.0% (29/29 bins)**.
* **Toggle Coverage:** **100.0% (172/172 signals toggled)**.
* **RTL Line Coverage:** **100.0%** trên module `fifo_sync.sv`.
---
## 2. Bằng chứng Mô phỏng UVM (Simulation Log)
Toàn bộ 200 giao dịch ngẫu nhiên sinh từ Z3 SAT Solver và các bài test định hướng biên đều hoàn thành không lỗi:
```text
./build/Vtb_top +UVM_TESTNAME=fifo_test +UVM_VERBOSITY=UVM_MEDIUM +verilator+coverage+file+build/coverage.dat
UVM_INFO @ 0: reporter [RNTST] Running test fifo_test...
UVM_INFO tb/fifo_uvm_pkg.sv(201) @ 2230000: uvm_test_top.env.sb [FIFO_SB] Reads checked: 87; functional coverage: 100.0%
UVM_INFO /home/john/tool/uvm/1800.2-2020.3.2/src/base/uvm_report_server.svh(1009) @ 2230000: reporter [UVM/REPORT/SERVER] 
--- UVM Report Summary ---
** Report counts by severity
UVM_INFO    :    5
UVM_WARNING :    2
UVM_ERROR   :    0
UVM_FATAL   :    0
- Simulation Report: Verilator 5.052
- Verilator: $finish at 2us; walltime 2.703 s; speed 825.052 ns/s

  

  
## 3. Báo cáo Chi tiết Độ phủ (Coverage Report)

  

Báo cáo trích xuất tự động qua công cụ verilator_coverage:


  
text
Coverage Summary:
  toggle     : 100.0% ( 172/ 172)
  covergroup : 100.0% (  29/  29)
  line       : 100.0% on RTL DUT (fifo_sync.sv)

  

  
Phân tích Covergroup: Đã kích hoạt toàn bộ 29 bins kiểm thử (Empty, 1 phần tử, 2 phần tử, 3 phần tử, Full 4 phần tử kết hợp với thao tác Đọc và Ghi).

  
Phân tích Toggle: 100% các chân tín hiệu vào/ra của FIFO đều đã lật trạng thái 0 ➔ 1 và 1 ➔ 0 đầy đủ.

  

  

  
4. Phân tích Dạng sóng Waveform (GTKWave)

  

Preview unavailable


  
Các mốc kiểm thử quan trọng trên sóng:

  

  
Giai đoạn Reset (0 - 30 ns): Tín hiệu rst_n tích cực mức thấp (0) trong 3 chu kỳ clock. Cờ empty lên 1, full về 0, bộ đếm count về 0.

  
Nạp đầy FIFO (30 - 110 ns): Ghi liên tiếp 4 dữ liệu 0x11, 0x22, 0x33, 0x44 vào 4 ô nhớ mem[0..3]. Ngay khi nạp xong từ thứ 4, cờ full lập tức nhảy lên 1.

  
Kiểm tra Corner Case (Chặn ghi khi FULL): Khi full = 1, kích hoạt wr_en = 1 với dữ liệu rác wdata = 0xEE. Quan sát sóng thấy tín hiệu nội bộ do_write = 0, ô nhớ mem[3] vẫn giữ nguyên giá trị 0x44 (ngăn chặn hỏng dữ liệu thành công).

  
Giai đoạn Đọc tuần tự (110 - 180 ns): Kích hoạt rd_en = 1, dữ liệu xuất hiện ở rdata l
ần lượt là 0x11, 0x22, 0x33, 0x44 (đúng chuẩn FIFO). Khi đọc hết, cờ empty bật lên 1.
