#!/usr/bin/env python3
import argparse
import hashlib
import re
from pathlib import Path

Q = 3329
R = 1 << 16
RINV = pow(R, -1, Q)

def parse_seed(path, count):
    cur = None
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if line.startswith("count"):
                cur = int(line.split("=")[1].strip())
            elif line.startswith("seed") and cur == count:
                return bytes.fromhex(line.split("=")[1].strip())
    raise RuntimeError(f"cannot find count={count} seed in {path}")

def parse_rom(path):
    txt = Path(path).read_text(errors="ignore")
    rom = [None] * 128

    pat = re.compile(r"rom\[(\d+)\]\s*=\s*(-?)\s*\d+'s?d\s*(\d+)")
    for m in pat.finditer(txt):
        idx = int(m.group(1))
        if idx < 128:
            val = int(m.group(3))
            if m.group(2) == "-":
                val = -val
            rom[idx] = val % Q

    bad = [i for i, v in enumerate(rom) if v is None]
    if bad:
        raise RuntimeError(f"missing rom entries in {path}: {bad[:10]}")

    return rom

def fqmul(a, b):
    return (a * b * RINV) % Q

def ntt_ref(a, zetas):
    r = a[:]
    k = 1
    length = 128

    while length >= 2:
        start = 0
        while start < 256:
            zeta = zetas[k]
            k += 1
            for j in range(start, start + length):
                t = fqmul(zeta, r[j + length])
                r[j + length] = (r[j] - t) % Q
                r[j] = (r[j] + t) % Q
            start += 2 * length
        length >>= 1

    return r

def intt_ref(a, zetas_inv):
    r = a[:]
    k = 0
    length = 2

    while length <= 128:
        start = 0
        while start < 256:
            zeta = zetas_inv[k]
            k += 1
            for j in range(start, start + length):
                t = r[j]
                r[j] = (t + r[j + length]) % Q
                r[j + length] = fqmul(zeta, (t - r[j + length]) % Q)
            start += 2 * length
        length <<= 1

    f = zetas_inv[127]
    for j in range(256):
        r[j] = fqmul(r[j], f)

    return r

def coeffs_from_seed(seed):
    buf = hashlib.shake_256(seed).digest(512)
    out = []
    for i in range(256):
        x = buf[2 * i] | (buf[2 * i + 1] << 8)
        out.append(x % Q)
    return out

def write_mem(path, vec):
    with open(path, "w") as f:
        for x in vec:
            f.write(f"{x & 0xfff:03x}\n")

def main():
    ap = argparse.ArgumentParser()

    ap.add_argument("--req", default="../Kyber-Round3-KAT/KAT/kyber512/PQCkemKAT_1632.req")
    ap.add_argument("--rsp", default="../Kyber-Round3-KAT/KAT/kyber512/PQCkemKAT_1632.rsp")
    ap.add_argument("--count", type=int, default=0)
    ap.add_argument("--tw", default="../src/twiddle_factor.v")
    ap.add_argument("--twinv", default="../src/twiddle_factor_inv.v")
    ap.add_argument("--outdir", default="../build")

    args = ap.parse_args()

    seed_req = parse_seed(args.req, args.count)

    if args.rsp and Path(args.rsp).exists():
        seed_rsp = parse_seed(args.rsp, args.count)
        if seed_req != seed_rsp:
            raise RuntimeError("seed mismatch between req and rsp")

    zetas = parse_rom(args.tw)
    zetas_inv = parse_rom(args.twinv)

    poly = coeffs_from_seed(seed_req)
    ntt = ntt_ref(poly, zetas)
    intt = intt_ref(ntt, zetas_inv)

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    write_mem(outdir / "vec_in.mem", poly)
    write_mem(outdir / "vec_ntt.mem", ntt)
    write_mem(outdir / "vec_intt.mem", intt)

    print(f"[OK] generated vectors from count={args.count}")
    print(f"[OK] seed={seed_req.hex().upper()}")
    print(f"[OK] wrote {outdir}/vec_in.mem")
    print(f"[OK] wrote {outdir}/vec_ntt.mem")
    print(f"[OK] wrote {outdir}/vec_intt.mem")

if __name__ == "__main__":
    main()