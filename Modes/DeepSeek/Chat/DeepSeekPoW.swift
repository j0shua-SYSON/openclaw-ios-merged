import Foundation

/// DeepSeek's proof-of-work, `DeepSeekHashV1`.
///
/// It is the SHA3-256 construction (rate 136, pad `0x06 … 0x80`, output = first
/// 32 bytes of the state as little-endian lane words) **but the Keccak-f[1600]
/// permutation omits round 0** — it applies only rounds 1…23. This is genuinely
/// non-standard; standard SHA3-256 does not match. The C reference of this exact
/// code was validated against DeepSeek's four published test vectors.
///
/// A challenge gives you `salt`, `expire_at`, `difficulty`, and a 32-byte
/// `challenge` target. The answer is the first nonce in `[0, difficulty)` whose
/// `DeepSeekHashV1("<salt>_<expire_at>_<nonce>")` equals the target digest.
enum DeepSeekPoW {

    // Keccak round constants (rounds 1…23 are used; index 0 is present but skipped).
    private static let rc: [UInt64] = [
        0x1, 0x8082, 0x800000000000808A, 0x8000000080008000, 0x808B, 0x80000001,
        0x8000000080008081, 0x8000000000008009, 0x8A, 0x88, 0x80008009, 0x8000000A,
        0x8000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
        0x8000000000008002, 0x8000000000000080, 0x800A, 0x800000008000000A,
        0x8000000080008081, 0x8000000000008080, 0x80000001, 0x8000000080008008,
    ]
    // Rotation offsets rot[x][y].
    private static let rot: [[Int]] = [
        [0, 36, 3, 41, 18], [1, 44, 10, 45, 2], [62, 6, 43, 15, 61],
        [28, 55, 25, 21, 56], [27, 20, 39, 8, 14],
    ]

    @inline(__always) private static func rotl(_ x: UInt64, _ n: Int) -> UInt64 {
        let s = n % 64
        if s == 0 { return x }
        return (x << UInt64(s)) | (x >> UInt64(64 - s))
    }

    @inline(__always) private static func idx(_ x: Int, _ y: Int) -> Int { x + 5 * y }

    /// Keccak-f[1600] applying only rounds 1…23 (round 0 skipped) — the DeepSeek variant.
    private static func keccak23(_ st: inout [UInt64]) {
        var c = [UInt64](repeating: 0, count: 5)
        var d = [UInt64](repeating: 0, count: 5)
        var b = [UInt64](repeating: 0, count: 25)
        for r in 1..<24 {
            for x in 0..<5 { c[x] = st[idx(x, 0)] ^ st[idx(x, 1)] ^ st[idx(x, 2)] ^ st[idx(x, 3)] ^ st[idx(x, 4)] }
            for x in 0..<5 { d[x] = c[(x + 4) % 5] ^ rotl(c[(x + 1) % 5], 1) }
            for x in 0..<5 { for y in 0..<5 { st[idx(x, y)] ^= d[x] } }
            for x in 0..<5 { for y in 0..<5 { b[idx(y, (2 * x + 3 * y) % 5)] = rotl(st[idx(x, y)], rot[x][y]) } }
            for x in 0..<5 { for y in 0..<5 { st[idx(x, y)] = b[idx(x, y)] ^ (~b[idx((x + 1) % 5, y)] & b[idx((x + 2) % 5, y)]) } }
            st[idx(0, 0)] ^= rc[r]
        }
    }

    /// `DeepSeekHashV1(data)` → 32-byte digest.
    static func hash(_ data: [UInt8]) -> [UInt8] {
        let rate = 136
        var st = [UInt64](repeating: 0, count: 25)

        func absorbBlock(_ block: [UInt8], _ base: Int) {
            for i in 0..<(rate / 8) {
                var w: UInt64 = 0
                for byte in 0..<8 { w |= UInt64(block[base + i * 8 + byte]) << UInt64(8 * byte) }
                st[i] ^= w
            }
            keccak23(&st)
        }

        var off = 0
        while data.count - off >= rate {
            absorbBlock(Array(data[off..<off + rate]), 0)
            off += rate
        }
        // final padded block
        var last = [UInt8](repeating: 0, count: rate)
        let rem = data.count - off
        for i in 0..<rem { last[i] = data[off + i] }
        last[rem] ^= 0x06
        last[rate - 1] ^= 0x80
        absorbBlock(last, 0)

        var out = [UInt8](repeating: 0, count: 32)
        for i in 0..<4 {
            let w = st[i]
            for byte in 0..<8 { out[i * 8 + byte] = UInt8((w >> UInt64(8 * byte)) & 0xFF) }
        }
        return out
    }

    /// Solve: return the first nonce in `[0, difficulty)` whose
    /// `hash("<salt>_<expireAt>_<nonce>")` equals `challengeHex` (64 hex chars),
    /// or `nil` if none (expired/invalid). Runs on a background queue by callers.
    static func solve(salt: String, expireAt: String, challengeHex: String, difficulty: Int) -> Int? {
        guard let target = hexToBytes(challengeHex), target.count == 32 else { return nil }
        let prefix = Array("\(salt)_\(expireAt)_".utf8)
        var buf = prefix
        var n = 0
        while n < difficulty {
            buf.replaceSubrange(prefix.count..<buf.count, with: Array(String(n).utf8))
            if hash(buf) == target { return n }
            n += 1
        }
        return nil
    }

    private static func hexToBytes(_ hex: String) -> [UInt8]? {
        let chars = Array(hex)
        guard chars.count % 2 == 0 else { return nil }
        var out = [UInt8](); out.reserveCapacity(chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let hi = chars[i].hexDigitValue, let lo = chars[i + 1].hexDigitValue else { return nil }
            out.append(UInt8(hi << 4 | lo)); i += 2
        }
        return out
    }

    /// Verifies the implementation against the empty-string test vector. A failure
    /// means the port is broken — callers surface an error instead of spinning
    /// through `difficulty` iterations that can never match.
    static func selfCheck() -> Bool {
        let digest = hash([])
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return hex == "e594808bc5b7151ac160c6d39a02e0a8e261ed588578403099e3561dc40c26b3"
    }
}
