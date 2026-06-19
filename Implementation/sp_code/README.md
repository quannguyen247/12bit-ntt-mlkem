# sp_code

Bộ script verify độc lập cho `rtl/modules/ntt_core_top.v` (không sửa RTL gốc).

## Thành phần
- `scripts/rtl_model.py`: software model bám theo hành vi hiện tại của RTL (`ntt_controller + ntt_agu + ntt_butterfly`).
- `scripts/gen_vectors.py`: sinh input vector + expected memory (`.mem`).
- `scripts/gen_tb_ntt_core_top.py`: sinh testbench Verilog tự động.
- `scripts/run_verify.py`: chạy full flow generate + compile + simulate.

## Cách chạy
Từ thư mục `Implementation`:

```bash
python3 sp_code/scripts/run_verify.py --mode 0 --seed 1
python3 sp_code/scripts/run_verify.py --mode 1 --seed 1
```

`mode=0` là NTT, `mode=1` là INTT (theo hành vi RTL hiện tại).

## File sinh ra
- `sp_code/generated_tb/tb_ntt_core_top_auto.v`
- `sp_code/build/*_in.mem`
- `sp_code/build/*_exp.mem`
- `sp_code/build/sim_mode*_seed*.out`
