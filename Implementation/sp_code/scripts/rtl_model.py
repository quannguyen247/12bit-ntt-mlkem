#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
from dataclasses import dataclass

Q = 3329
N = 256


def _to_s16(v: int) -> int:
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


def parse_twiddle_table(ntt_funcs_path: Path) -> dict[int, tuple[int, int]]:
    text = ntt_funcs_path.read_text(encoding="utf-8")
    # Example line:
    # 7'd0: val = { -16'sd1044, 16'sd1701 };
    pat = re.compile(
        r"7'd(\d+)\s*:\s*val\s*=\s*\{\s*([+-]?)16'sd(\d+)\s*,\s*([+-]?)16'sd(\d+)\s*\}\s*;"
    )

    table: dict[int, tuple[int, int]] = {}
    for m in pat.finditer(text):
        idx = int(m.group(1))
        fwd = int(m.group(3)) * (-1 if m.group(2) == "-" else 1)
        inv = int(m.group(5)) * (-1 if m.group(4) == "-" else 1)
        table[idx] = (_to_s16(fwd), _to_s16(inv))

    if len(table) != 128:
        raise RuntimeError(f"Expected 128 twiddle entries, found {len(table)}")

    return table


def twiddle_u(table: dict[int, tuple[int, int]], addr: int, is_inv: bool) -> int:
    fwd, inv = table[addr & 0x7F]
    tw = inv if is_inv else fwd
    if tw < 0:
        tw += Q
    return tw & 0xFFF


def mod_add(a: int, b: int) -> int:
    s = a + b
    if s >= Q:
        s -= Q
    return s


def mod_sub(a: int, b: int) -> int:
    if a >= b:
        return a - b
    return a + Q - b


def montgomery_reduce_12b(t: int) -> int:
    # Match rtl/modules/ntt_mod_mul_12b.v
    t16 = t & 0xFFFF
    m = (t16 * 3327) & 0xFFFF
    t_plus = t + m * Q
    u = (t_plus >> 16) & 0x1FFF
    if u >= Q:
        u -= Q
    return u & 0xFFF


def mul_mod(a: int, b: int) -> int:
    t = (a & 0xFFF) * (b & 0xFFF)
    return montgomery_reduce_12b(t)


def butterfly(a: int, b: int, zeta: int) -> tuple[int, int]:
    mb = mul_mod(b, zeta)
    return mod_add(a, mb), mod_sub(a, mb)


@dataclass
class Ctrl:
    state: int = 0  # 0=IDLE, 1=RUN, 2=SCALE
    busy: int = 0
    done: int = 0
    mode: int = 0
    length: int = 0
    pos: int = 0
    zidx: int = 0
    cnt: int = 0

    def start(self, mode: int) -> None:
        self.mode = mode & 1
        self.state = 1
        self.busy = 1
        self.done = 0
        self.length = 2 if self.mode else 128
        self.zidx = 0 if self.mode else 1
        self.pos = 0
        self.cnt = 0

    def advance(self) -> None:
        self.done = 0
        if self.state == 1:
            if self.pos == (self.length - 1):
                self.pos = 0
                self.zidx = (self.zidx + 1) & 0xFF
            else:
                self.pos = (self.pos + 1) & 0xFF

            if self.cnt == 127:
                self.cnt = 0
                self.pos = 0
                if self.mode == 0:
                    if self.length == 2:
                        self.done = 1
                        self.busy = 0
                        self.state = 0
                    else:
                        self.length = (self.length >> 1) & 0xFF
                else:
                    if self.length == 128:
                        self.state = 2
                    else:
                        self.length = (self.length << 1) & 0xFF
            else:
                self.cnt = (self.cnt + 1) & 0xFF

        elif self.state == 2:
            if self.cnt == 255:
                self.done = 1
                self.busy = 0
                self.state = 0
            else:
                self.cnt = (self.cnt + 1) & 0xFF


def simulate_ntt_core(mem_in: list[int], mode: int, tw_table: dict[int, tuple[int, int]]) -> list[int]:
    if len(mem_in) != N:
        raise ValueError(f"Expected {N} input coefficients")

    mem = [x & 0xFFF for x in mem_in]
    c = Ctrl()
    c.start(mode)

    max_steps = 5000
    steps = 0

    while c.busy:
        if c.state in (1, 2):
            len2 = (c.length << 1) & 0xFF
            base = (c.zidx * len2) & 0xFF
            addr_a = (base + c.pos) & 0xFF
            addr_b = (base + c.pos + c.length) & 0xFF

            zeta = twiddle_u(tw_table, c.zidx & 0x7F, is_inv=bool(c.mode))
            out0, out1 = butterfly(mem[addr_a], mem[addr_b], zeta)
            mem[addr_a] = out0
            mem[addr_b] = out1

            c.advance()
        else:
            break

        steps += 1
        if steps > max_steps:
            raise RuntimeError("Simulation did not complete (step overflow)")

    return mem


def write_mem(path: Path, data: list[int]) -> None:
    lines = [f"{x & 0xFFF:03x}" for x in data]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
