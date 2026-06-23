import hashlib
import random
import re
import sys
from pathlib import Path

Q = 3329
R = 1 << 16
R_INV = pow(R, -1, Q)

TWIDDLE_PATTERN = re.compile(
    r"7'd(\d+)\s*:\s*val\s*=\s*\{\s*(-?)\s*16'sd(\d+)\s*,\s*(-?)\s*16'sd(\d+)\s*\}\s*;"
)


def parse_twiddles(path: Path) -> tuple:
    txt = path.read_text(errors="ignore")
    zetas = [None] * 128
    zetas_inv = [None] * 128

    for m in TWIDDLE_PATTERN.finditer(txt):
        idx = int(m.group(1))
        if idx < 128:
            fwd_val = int(m.group(3))
            if m.group(2) == "-":
                fwd_val = -fwd_val
            zetas[idx] = fwd_val % Q

            inv_val = int(m.group(5))
            if m.group(4) == "-":
                inv_val = -inv_val
            zetas_inv[idx] = inv_val % Q

    missing = [i for i, v in enumerate(zetas) if v is None]
    if missing:
        raise RuntimeError(f"Missing twiddle entries: {missing[:10]}")
    return zetas, zetas_inv


def fqmul(a: int, b: int) -> int:
    return (a * b * R_INV) % Q


def ntt_ref(a: list, zetas: list) -> list:
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


def intt_ref(a: list, zetas_inv: list) -> list:
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


def coeffs_from_seed(seed: int) -> list:
    buf = hashlib.shake_256(str(seed).encode()).digest(512)
    return [(buf[2 * i] | (buf[2 * i + 1] << 8)) % Q for i in range(256)]


def poly_to_hex(poly: list) -> str:
    return "".join(f"{poly[i] & 0xFFF:03x}" for i in range(255, -1, -1))


def make_edge_cases() -> list:
    return [
        ([0] * 256, "all-zero"),
        ([Q - 1] * 256, "all-max (Q-1)"),
        ([1] + [0] * 255, "unit-impulse"),
    ]


def main():
    vectors_dir = Path(__file__).resolve().parent

    num_random = 20
    if len(sys.argv) > 1:
        if sys.argv[1].lower() == "clear":
            for name in ["tv_all.mem", "tv_spec.txt"]:
                p = vectors_dir / name
                if p.exists():
                    p.unlink()
            print("Cleared vectors.")
            return 0
        try:
            num_random = int(sys.argv[1])
        except ValueError:
            print(f"Warning: Invalid '{sys.argv[1]}', defaulting to 20.")
            num_random = 20

    ntt_funcs_path = vectors_dir.parent / "rtl" / "utils" / "ntt_funcs.vh"
    zetas, zetas_inv = parse_twiddles(ntt_funcs_path)
    print(f"Parsed 128 twiddle pairs from {ntt_funcs_path.name}")

    cases = []

    for poly, label in make_edge_cases():
        ntt = ntt_ref(poly, zetas)
        intt = intt_ref(ntt, zetas_inv)
        assert all(0 <= c < Q for c in ntt), f"NTT out of range for '{label}'"
        assert all(0 <= c < Q for c in intt), f"INTT out of range for '{label}'"
        cases.append((poly, ntt, intt))
        print(f"  Edge case: {label}")

    for i in range(1, num_random + 1):
        random.seed(i)
        case_seed = random.randint(0, 1_000_000_000)
        poly = coeffs_from_seed(case_seed)
        ntt = ntt_ref(poly, zetas)
        intt = intt_ref(ntt, zetas_inv)
        assert all(0 <= c < Q for c in ntt), f"NTT out of range for case {i}"
        assert all(0 <= c < Q for c in intt), f"INTT out of range for case {i}"
        cases.append((poly, ntt, intt))

    total = len(cases)
    with open(vectors_dir / "tv_all.mem", "w") as f:
        for poly, ntt, intt in cases:
            f.write(f"{poly_to_hex(intt)}{poly_to_hex(ntt)}{poly_to_hex(poly)}\n")

    (vectors_dir / "tv_spec.txt").write_text(f"tv_count={total}\n")
    print(f"\nGenerated {total} vectors ({len(make_edge_cases())} edge + {num_random} random)")
    print(f"  -> {vectors_dir / 'tv_all.mem'}")
    print(f"  -> {vectors_dir / 'tv_spec.txt'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())