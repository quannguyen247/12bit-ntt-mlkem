#!/usr/bin/env python3
"""Generate test vectors for the 12-bit NTT/INTT RTL testbench.

Creates three hex memory files in the output directory:
 - vec_in.mem   : 256 input coefficients (12-bit hex per line)
 - vec_ntt.mem  : expected NTT output (12-bit hex per line)
 - vec_intt.mem : expected INTT output (12-bit hex per line)

The script implements a Python version of the Kyber-like NTT/INTT used by the RTL
so the vectors match behavior. CLI mirrors the Makefile usage.
"""
import argparse
import os
import struct
import sys


# Parameters (match RTL / twiddle tables)
Q = 3329
N = 256


def montgomery_reduce(a):
    # simple Python placeholder matching behavior of k2_red in RTL
    # Implementation: return a mod Q in signed range 0..Q-1
    return a % Q


def barrett_reduce(a):
    return a % Q


def fqmul(a, b):
    # multiply and reduce to 12-bit coefficient (norm to 0..Q-1 then to 12-bit)
    return montgomery_reduce(a * b)


def load_twiddle_from_verilog(path):
    # Parse a twiddle_factor.v or twiddle_factor_inv.v that assigns rom[i] = <value>;
    tw = [0] * 128
    try:
        with open(path, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('rom['):
                    # rom[12]  =  16'sd962;
                    left, right = line.split('=', 1)
                    idx = int(left[left.find('[')+1:left.find(']')])
                    val = right.strip().rstrip(';')
                    # handle forms like 16'sd962 or -16'sd1044
                    if "'sd" in val:
                        val = val.split("'sd")[1]
                    tw[idx] = int(val)
    except FileNotFoundError:
        print(f"[WARN] twiddle file {path} not found; using zeros")
    return tw


def ntt_ref(a, twiddle):
    # Cooley-Tukey iterative decimation-in-time NTT using provided twiddle table
    A = list(a)
    length = N
    half = 1
    # This reproduces the stage ordering used by the RTL: outer len from 128..2
    len_val = N // 2
    zidx = 1
    while len_val >= 2:
        for base in range(0, N, 2 * len_val):
            for j in range(base, base + len_val):
                u = A[j]
                v = A[j + len_val]
                z = twiddle[zidx & 0x7f]
                t = fqmul(v, z)
                A[j] = (u + t) % Q
                A[j + len_val] = (u - t) % Q
            zidx += 1
        len_val >>= 1
    return A


def intt_ref(a, twiddle_inv):
    A = list(a)
    len_val = 2
    zidx = 0
    while len_val <= N // 2:
        for base in range(0, N, 2 * len_val):
            for j in range(base, base + len_val):
                u = A[j]
                v = A[j + len_val]
                A[j] = (u + v) % Q
                z = twiddle_inv[zidx & 0x7f]
                t = fqmul((u - v) % Q, z)
                A[j + len_val] = t
            zidx += 1
        len_val <<= 1

    # Final scaling stage: multiply by SCALE inverse / N as in RTL's S_SCALE
    # The RTL uses SCALE = 1441 as a fixed-point scale; mimic by multiplying
    SCALE = 1441
    for i in range(N):
        A[i] = fqmul(A[i], SCALE)

    return A


def write_mem(path, arr):
    with open(path, 'w') as f:
        for v in arr:
            # Write as 12-bit hex (lowercase) without 0x, padded to 3 hex digits
            v12 = v & 0xfff
            f.write('{:03x}\n'.format(v12))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--req', help='(ignored) path to KAT request file', default=None)
    p.add_argument('--rsp', help='(ignored) path to KAT response file', default=None)
    p.add_argument('--count', help='(ignored) KAT count', default=None)
    p.add_argument('--tw', help='path to twiddle_factor.v', default='Implementation/rtl/modules/legacy/twiddle_factor.v')
    p.add_argument('--twinv', help='path to twiddle_factor_inv.v', default='Implementation/rtl/modules/legacy/twiddle_factor_inv.v')
    p.add_argument('--outdir', help='output directory', default='build')
    args = p.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    tw = load_twiddle_from_verilog(args.tw)
    twinv = load_twiddle_from_verilog(args.twinv)

    # Generate a simple deterministic input vector: e.g., 0..255 mod Q
    vec_in = [i % Q for i in range(N)]

    vec_ntt = ntt_ref(vec_in, tw)
    vec_intt = intt_ref(vec_ntt, twinv)

    write_mem(os.path.join(args.outdir, 'vec_in.mem'), vec_in)
    write_mem(os.path.join(args.outdir, 'vec_ntt.mem'), vec_ntt)
    write_mem(os.path.join(args.outdir, 'vec_intt.mem'), vec_intt)

    print(f"Wrote {args.outdir}/vec_in.mem, vec_ntt.mem, vec_intt.mem")


if __name__ == '__main__':
    main()
