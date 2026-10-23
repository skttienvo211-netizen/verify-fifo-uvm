VERILATOR ?= verilator
UVM_HOME ?=
BUILD_DIR ?= build

SV_SOURCES = rtl/fifo_sync.sv \
             tb/fifo_if.sv \
             $(UVM_HOME)/uvm_pkg.sv \
             tb/fifo_uvm_pkg.sv \
             tb/tb_top.sv

VERILATOR_FLAGS = --binary --timing --assert --coverage -Wall -Wno-fatal \
                  -j $$(nproc) --top-module tb_top --Mdir $(BUILD_DIR) \
                  +incdir+$(UVM_HOME) +define+UVM_NO_DPI

.PHONY: check-uvm build sim coverage clean waves

check-uvm:
	@test -n "$(UVM_HOME)" || (echo "Set UVM_HOME to the UVM 2020.3.2 src directory"; exit 1)
	@test -f "$(UVM_HOME)/uvm_pkg.sv" || (echo "Cannot find $(UVM_HOME)/uvm_pkg.sv"; exit 1)

build: check-uvm
	$(VERILATOR) $(VERILATOR_FLAGS) $(SV_SOURCES)

sim: build
	./$(BUILD_DIR)/Vtb_top +UVM_TESTNAME=fifo_test +UVM_VERBOSITY=UVM_MEDIUM +verilator+coverage+file+$(BUILD_DIR)/coverage.dat

coverage:
	verilator_coverage --report summary $(BUILD_DIR)/coverage.dat
	verilator_coverage --annotate $(BUILD_DIR)/coverage_annotated $(BUILD_DIR)/coverage.dat

waves: check-uvm
	$(VERILATOR) $(VERILATOR_FLAGS) --trace +define+WAVES $(SV_SOURCES)
	./$(BUILD_DIR)/Vtb_top +UVM_TESTNAME=fifo_test +UVM_VERBOSITY=UVM_MEDIUM

clean:
	rm -rf $(BUILD_DIR) fifo.vcd
