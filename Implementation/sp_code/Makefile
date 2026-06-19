PYTHON ?= python3
RUNNER := scripts/run_verify.py

SEED ?= 1
START ?= 1
COUNT ?= 5

.PHONY: help verify mode0 mode1 both regress clean

help:
	@echo "Targets:"
	@echo "  make mode0 SEED=1          - Verify mode 0 (NTT)"
	@echo "  make mode1 SEED=1          - Verify mode 1 (INTT)"
	@echo "  make both SEED=1           - Verify both modes with one seed"
	@echo "  make regress START=1 COUNT=5 - Run multi-seed regression for both modes"
	@echo "  make clean                 - Remove generated files"

verify:
	$(PYTHON) $(RUNNER) --mode $(MODE) --seed $(SEED)

mode0:
	$(PYTHON) $(RUNNER) --mode 0 --seed $(SEED)

mode1:
	$(PYTHON) $(RUNNER) --mode 1 --seed $(SEED)

both:
	$(PYTHON) $(RUNNER) --mode 0 --seed $(SEED)
	$(PYTHON) $(RUNNER) --mode 1 --seed $(SEED)

regress:
	@i=$(START); \
	end=$$(( $(START) + $(COUNT) - 1 )); \
	while [ $$i -le $$end ]; do \
		echo "[REGRESS] seed=$$i mode=0"; \
		$(PYTHON) $(RUNNER) --mode 0 --seed $$i || exit $$?; \
		echo "[REGRESS] seed=$$i mode=1"; \
		$(PYTHON) $(RUNNER) --mode 1 --seed $$i || exit $$?; \
		i=$$((i+1)); \
	done

clean:
	rm -f build/*.mem build/*.out generated_tb/*.v
