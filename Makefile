# ============================================================
# Makefile for 12bit Kyber NTT/INTT RTL simulation
# Tool: Icarus Verilog
# ============================================================

IVERILOG ?= iverilog
VVP      ?= vvp
PYTHON   ?= python3

SRC_DIR  := src
TB_DIR   := testbench
BUILD    := build

TOP_TB   := tb_unified_ntt_intt
SIMV     := $(BUILD)/simv

REQ      := Kyber-Round3-KAT/KAT/kyber512/PQCkemKAT_1632.req
RSP      := Kyber-Round3-KAT/KAT/kyber512/PQCkemKAT_1632.rsp
COUNT    ?= 0

VEC_IN   := $(BUILD)/vec_in.mem
VEC_NTT  := $(BUILD)/vec_ntt.mem
VEC_INTT := $(BUILD)/vec_intt.mem

RTL := \
	$(SRC_DIR)/k2_red.v \
	$(SRC_DIR)/mul_Q.v	\
	$(SRC_DIR)/mul_V.v  \
	$(SRC_DIR)/kyber_mul16_lut.v \
	$(SRC_DIR)/barret_reduce.v \
	$(SRC_DIR)/kyber_addq12.v \
	$(SRC_DIR)/kyber_subq12.v \
	$(SRC_DIR)/kyber_norm12.v \
	$(SRC_DIR)/twiddle_factor.v \
	$(SRC_DIR)/twiddle_factor_inv.v \
	$(SRC_DIR)/unified_ntt_intt.v

TB := $(TB_DIR)/tb_unified_ntt_intt.v

.PHONY: all vec sim run test clean wave check files

all: test

$(BUILD):
	mkdir -p $(BUILD)

# Generate NTT/INTT reference vectors
vec: $(BUILD)
	$(PYTHON) scripts/gen_ntt_vec.py \
		--req $(REQ) \
		--rsp $(RSP) \
		--count $(COUNT) \
		--tw $(SRC_DIR)/twiddle_factor.v \
		--twinv $(SRC_DIR)/twiddle_factor_inv.v \
		--outdir $(BUILD)

# Compile RTL + testbench
sim: vec
	$(IVERILOG) -g2012 -Wall \
		-I$(SRC_DIR) \
		-s $(TOP_TB) \
		-o $(SIMV) \
		$(TB) $(RTL)

# Run simulation
run: sim
	$(VVP) $(SIMV) \
		+IN_MEM=$(VEC_IN) \
		+NTT_MEM=$(VEC_NTT) \
		+INTT_MEM=$(VEC_INTT)

test: run

# Show project files used by simulation
files:
	@echo "RTL files:"
	@printf "  %s\n" $(RTL)
	@echo "TB:"
	@echo "  $(TB)"
	@echo "Vectors:"
	@echo "  $(VEC_IN)"
	@echo "  $(VEC_NTT)"
	@echo "  $(VEC_INTT)"

# Basic check
check:
	@command -v $(IVERILOG) >/dev/null || { echo "Missing iverilog"; exit 1; }
	@command -v $(VVP) >/dev/null || { echo "Missing vvp"; exit 1; }
	@test -f $(TB) || { echo "Missing $(TB)"; exit 1; }
	@test -f scripts/gen_ntt_vec.py || { echo "Missing scripts/gen_ntt_vec.py"; exit 1; }
	@echo "[OK] environment looks good"

clean:
	rm -rf $(BUILD)/simv $(BUILD)/*.vcd