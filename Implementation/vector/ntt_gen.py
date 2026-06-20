import hashlib
import re
import sys
from pathlib import Path

Q = 3329
R = 1 << 16
RINV = pow(R, -1, Q)

def parse_twiddles(path):
    txt = Path(path).read_text(errors="ignore")
    zetas = [None] * 128
    zetas_inv = [None] * 128

    pat = re.compile(r"7'd(\d+)\s*:\s*val\s*=\s*\{\s*(-?)\s*16'sd(\d+)\s*,\s*(-?)\s*16'sd(\d+)\s*\}\s*;")
    for m in pat.finditer(txt):
        idx = int(m.group(1))
        if idx < 128:
            fwd_val = int(m.group(3))
            if m.group(2) == "-": fwd_val = -fwd_val
            zetas[idx] = fwd_val % Q

            inv_val = int(m.group(5))
            if m.group(4) == "-": inv_val = -inv_val
            zetas_inv[idx] = inv_val % Q

    bad = [i for i, v in enumerate(zetas) if v is None]
    if bad:
        raise RuntimeError(f"missing twiddle entries: {bad[:10]}")
    return zetas, zetas_inv

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
    buf = hashlib.shake_256(str(seed).encode()).digest(512)
    return [(buf[2 * i] | (buf[2 * i + 1] << 8)) % Q for i in range(256)]

def main():
    import random
    vectors_dir = Path(__file__).resolve().parent
    
    num_cases = 20
    if len(sys.argv) > 1:
        if sys.argv[1].lower() == "clear":
            for name in ["tv_all.mem", "tv_spec.txt"]:
                p = vectors_dir / name
                if p.exists(): p.unlink()
            print("Cleared vectors.")
            return 0
        try:
            num_cases = int(sys.argv[1])
        except ValueError:
            print(f"Warning: Invalid number of cases '{sys.argv[1]}'. Defaulting to 20.")
            num_cases = 20

    ntt_funcs_path = vectors_dir.parent / "rtl" / "utils" / "ntt_funcs.vh"
    zetas, zetas_inv = parse_twiddles(ntt_funcs_path)

    cases = []
    for i in range(1, num_cases + 1):
        random.seed(i)
        case_seed = random.randint(0, 1000000000)
        poly = coeffs_from_seed(case_seed)
        ntt = ntt_ref(poly, zetas)
        intt = intt_ref(ntt, zetas_inv)
        cases.append((poly, ntt, intt))

    with open(vectors_dir / "tv_all.mem", "w") as f:
        for poly, ntt, intt in cases:
            poly_hex = "".join(f"{poly[i] & 0xfff:03x}" for i in range(255, -1, -1))
            ntt_hex = "".join(f"{ntt[i] & 0xfff:03x}" for i in range(255, -1, -1))
            intt_hex = "".join(f"{intt[i] & 0xfff:03x}" for i in range(255, -1, -1))
            f.write(f"{intt_hex}{ntt_hex}{poly_hex}\n")

    (vectors_dir / "tv_spec.txt").write_text(f"tv_count={num_cases}\n")
    print(f"Generated {num_cases} vectors in {vectors_dir}")
    return 0

if __name__ == "__main__":
    sys.exit(main())