#!/usr/bin/env python3
from __future__ import annotations

import argparse
import random
from pathlib import Path

from rtl_model import N, Q, parse_twiddle_table, simulate_ntt_core, write_mem


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate input/expected mem files for ntt_core_top")
    ap.add_argument("--mode", type=int, choices=[0, 1], required=True, help="0=NTT, 1=INTT")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--prefix", type=str, default="case")
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2], help="Repo root")
    args = ap.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)

    tw_path = args.root / "rtl" / "utils" / "ntt_funcs.vh"
    tw_table = parse_twiddle_table(tw_path)

    rng = random.Random(args.seed)
    vec_in = [rng.randrange(Q) for _ in range(N)]
    vec_exp = simulate_ntt_core(vec_in, args.mode, tw_table)

    in_mem = args.out_dir / f"{args.prefix}_mode{args.mode}_seed{args.seed}_in.mem"
    exp_mem = args.out_dir / f"{args.prefix}_mode{args.mode}_seed{args.seed}_exp.mem"

    write_mem(in_mem, vec_in)
    write_mem(exp_mem, vec_exp)

    print(f"IN_MEM={in_mem}")
    print(f"EXP_MEM={exp_mem}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
