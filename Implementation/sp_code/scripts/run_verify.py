#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


RTL_FILES = [
    "rtl/modules/ntt_core_top.v",
    "rtl/modules/ntt_controller.v",
    "rtl/modules/ntt_agu.v",
    "rtl/modules/poly_ram_dual.v",
    "rtl/modules/ntt_twiddle_rom.v",
    "rtl/modules/ntt_butterfly.v",
    "rtl/modules/ntt_mod_mul_12b.v",
    "rtl/modules/ntt_mod_addsub_12b.v",
]


def run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    p = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)
    if p.stdout:
        print(p.stdout, end="")
    if p.stderr:
        print(p.stderr, end="", file=sys.stderr)
    return p


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate vectors/TB then verify ntt_core_top by simulation")
    ap.add_argument("--mode", type=int, choices=[0, 1], required=True, help="0=NTT, 1=INTT")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--prefix", type=str, default="case")
    args = ap.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    sp_root = repo_root / "sp_code"
    build_dir = sp_root / "build"
    build_dir.mkdir(parents=True, exist_ok=True)

    tb_path = sp_root / "generated_tb" / "tb_ntt_core_top_auto.v"

    p = run(
        [sys.executable, str(sp_root / "scripts" / "gen_tb_ntt_core_top.py"), "--out", str(tb_path)],
        cwd=repo_root,
    )
    if p.returncode != 0:
        return p.returncode

    p = run(
        [
            sys.executable,
            str(sp_root / "scripts" / "gen_vectors.py"),
            "--mode",
            str(args.mode),
            "--seed",
            str(args.seed),
            "--out-dir",
            str(build_dir),
            "--prefix",
            args.prefix,
            "--root",
            str(repo_root),
        ],
        cwd=repo_root,
    )
    if p.returncode != 0:
        return p.returncode

    in_mem = build_dir / f"{args.prefix}_mode{args.mode}_seed{args.seed}_in.mem"
    exp_mem = build_dir / f"{args.prefix}_mode{args.mode}_seed{args.seed}_exp.mem"
    sim_out = build_dir / f"sim_mode{args.mode}_seed{args.seed}.out"

    iverilog_cmd = [
        "iverilog",
        "-g2012",
        "-DSYNTHESIS",
        "-I",
        "rtl/utils",
        "-o",
        str(sim_out),
        str(tb_path),
        *RTL_FILES,
    ]
    p = run(iverilog_cmd, cwd=repo_root)
    if p.returncode != 0:
        return p.returncode

    vvp_cmd = [
        "vvp",
        str(sim_out),
        f"+MODE={args.mode}",
        f"+IN_MEM={in_mem}",
        f"+EXP_MEM={exp_mem}",
    ]
    p = run(vvp_cmd, cwd=repo_root)
    if p.returncode != 0:
        return p.returncode

    if "[PASS]" not in p.stdout:
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
