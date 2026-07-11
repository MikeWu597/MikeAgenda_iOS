import Foundation
import CommonCrypto

enum PortCryptoError: LocalizedError {
    case rsaEncryptFailed, rsaDecryptFailed, aesEncryptFailed, aesDecryptFailed, keyGenerationFailed, invalidKey
    var errorDescription: String? {
        switch self {
        case .rsaEncryptFailed: return "RSA加密失败"
        case .rsaDecryptFailed: return "RSA解密失败"
        case .aesEncryptFailed: return "AES加密失败"
        case .aesDecryptFailed: return "AES解密失败"
        case .keyGenerationFailed: return "密钥生成失败"
        case .invalidKey: return "密钥无效"
        }
    }
}

/// Minimal BigInt for RSA-512: 64 bytes, big-endian, value semantics
private struct BigU512 {
    private var d: Data // exactly 64 bytes

    init(_ data: Data) {
        var v = data
        while v.count > 1 && v.first == 0 { v.removeFirst() }
        while v.count < 64 { v.insert(0, at: 0) }
        d = Data(v.suffix(64))
    }
    init(_ value: Int) { self.init(Data([UInt8(value)])) }

    var data: Data { d }
    var isZero: Bool { d.allSatisfy { $0 == 0 } }

    // (self * other) % mod
    static func mulMod(_ a: BigU512, _ b: BigU512, _ mod: BigU512) -> BigU512 {
        // Compute full 1024-bit product via 8-word schoolbook
        var p = [UInt64](repeating: 0, count: 16)
        let aw = a.wordsLE, bw = b.wordsLE
        for i in 0..<8 {
            var carry: UInt64 = 0
            for j in 0..<8 {
                let (hi, lo) = aw[j].multipliedFullWidth(by: bw[i])
                var sum = p[i+j] &+ lo
                var overflow: UInt64 = sum < p[i+j] ? 1 : 0
                sum = sum &+ carry; if sum < carry { overflow &+= 1 }
                p[i+j] = sum; carry = hi &+ overflow
            }
            var k = i + 8
            while carry != 0 && k < 16 {
                let (v, ov) = p[k].addingReportingOverflow(carry)
                p[k] = v; carry = ov ? 1 : 0; k += 1
            }
        }
        // Long division (1024-bit / 512-bit)
        let mw = mod.words
        var r = [UInt64](repeating: 0, count: 8)
        for bitPos in 0..<1024 {
            // r <<= 1
            var carry: UInt64 = 0
            for i in (0..<8).reversed() {
                let nc = r[i] >> 63
                r[i] = (r[i] << 1) | carry
                carry = nc
            }
            // OR in next product bit
            let wi = 15 - (bitPos / 64), bi = 63 - (bitPos % 64)
            if wi >= 0, ((p[wi] >> bi) & 1) != 0 { r[7] |= 1 }
            // Subtract mod if r >= mod
            if carry != 0 || cmpGE(r, mw) {
                var borrow: UInt64 = 0
                for i in (0..<8).reversed() {
                    let (v, ov1) = r[i].subtractingReportingOverflow(mw[i])
                    let (v2, ov2) = v.subtractingReportingOverflow(borrow)
                    r[i] = v2; borrow = (ov1 ? 1 : 0) + (ov2 ? 1 : 0)
                }
            }
        }
        return BigU512(fromWords: r)
    }

    // self % mod
    static func %(lhs: BigU512, rhs: BigU512) -> BigU512 {
        let aw = lhs.words, mw = rhs.words
        var r = [UInt64](repeating: 0, count: 8)
        for bitPos in 0..<512 {
            // r <<= 1
            var carry: UInt64 = 0
            for i in (0..<8).reversed() {
                let nc = r[i] >> 63
                r[i] = (r[i] << 1) | carry
                carry = nc
            }
            let wi = bitPos / 64, bi = 63 - (bitPos % 64)
            if ((aw[wi] >> bi) & 1) != 0 { r[7] |= 1 }
            if carry != 0 || cmpGE(r, mw) {
                var borrow: UInt64 = 0
                for i in (0..<8).reversed() {
                    let (v, ov1) = r[i].subtractingReportingOverflow(mw[i])
                    let (v2, ov2) = v.subtractingReportingOverflow(borrow)
                    r[i] = v2; borrow = (ov1 ? 1 : 0) + (ov2 ? 1 : 0)
                }
            }
        }
        return BigU512(fromWords: r)
    }

    func modPow(_ exp: BigU512, _ mod: BigU512) -> BigU512 {
        var base = self % mod
        var result = BigU512(1)
        var e = exp.words
        
        for _ in 0..<512 {
            if (e[7] & 1) != 0 { result = BigU512.mulMod(result, base, mod) }
            base = BigU512.mulMod(base, base, mod)
            // e >>= 1
            var carry: UInt64 = 0
            for i in 0..<8 {
                let nc = (e[i] & 1) << 63
                e[i] = (e[i] >> 1) | carry
                carry = nc
            }
        }
        return result
    }

    // MARK: - Internal

    private var words: [UInt64] { Self.dataToWords(d) }

    private var wordsLE: [UInt64] {
        var w = words; w.reverse(); return w
    }

    init(fromWords w: [UInt64]) {
        var bytes = Data(capacity: 64)
        for v in w { var x = v; for _ in 0..<8 { bytes.append(UInt8((x >> 56) & 0xFF)); x <<= 8 } }
        d = bytes
    }

    private static func dataToWords(_ data: Data) -> [UInt64] {
        var r = [UInt64](repeating: 0, count: 8)
        for i in 0..<8 { r[i] = data.subdata(in: i*8..<(i+1)*8).reduce(0) { $0<<8 | UInt64($1) } }
        return r
    }

    private static func cmpGE(_ a: [UInt64], _ b: [UInt64]) -> Bool {
        for i in 0..<8 { if a[i] > b[i] { return true }; if a[i] < b[i] { return false } }
        return true
    }
}

// MARK: - PortCrypto

final class PortCrypto {
    private let serverPubDER = Data(base64Encoded: "MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAK5yfMEMCBDVsLL9j63VJ3tCqi8pUAyW+eDXuU4xbBe+78IbVmblZ3KBgGDcTjqnM2desI5ZitpLa2/jFXn5Mf0CAwEAAQ==")!
    private let clientPrivDER = Data(base64Encoded: "MIIBVQIBADANBgkqhkiG9w0BAQEFAASCAT8wggE7AgEAAkEA7yLWhkYx6y/iQrgAj8cQVYIm9hKmdXlRZE8q1uP35rlVujnWM9bO3AIlDbEKzbmCnAJ68sr3Oj2zD3SAvN8SewIDAQABAkEAx3RhRaFqpWVM7KUYItO/9fIWmQu5NyY3EtlNO+rsq8ywrvSttVY2er3tBDoTVtAeOTkJWBwKoNi3u8FHFiOmoQIhAP1TWNTb2q5cd7wFK8itFuSei2A+WaUdvDNl8SaaMIyTAiEA8akkQTSZGBxO9hXChxI9wI5e74m3AVREwzi73dVWe3kCIB3EbnrMvtygRv2UCfoRxM/mhXAww23wmY3cm8KyeaP7AiEAhKZ5tikvGCMB3ObY3tfOedIsnoQTpnEhRZ/wz7X5QNECIBBc4WS/hqncMeNEC2v2vtYJAPX2UzLwV16o4GqJjgzF")!

    private var _clientN: BigU512?, _clientD: BigU512?

    func generateAESKey() -> Data {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<32).map{_ in chars.randomElement()!}).data(using:.utf8)!
    }

    func decryptAESKeyWithClientPrivateKey(_ b64: String) throws -> Data {
        let (n, d) = try clientKey()
        guard let c = Data(base64Encoded: b64) else { throw PortCryptoError.invalidKey }

        let m = BigU512(c).modPow(d, n)
        var plain = m.data
        guard plain.count >= 2, plain[0] == 0, plain[1] == 2 else { throw PortCryptoError.rsaDecryptFailed }
        if let s = plain.dropFirst(2).firstIndex(of: 0) { plain = Data(plain.suffix(from: s+1)) }
        guard let b = String(data: plain, encoding: .utf8), let k = Data(base64Encoded: b) else { throw PortCryptoError.rsaDecryptFailed }
        return k
    }

    private func clientKey() throws -> (BigU512, BigU512) {
        if let n = _clientN, let d = _clientD { return (n, d) }
        let der = clientPrivDER; var p = 0
        _ = readTL(der, &p, 0x30); _ = readTL(der, &p, 0x02); p += 1
        let al = readTL(der, &p, 0x30); p += al
        let pl = readTL(der, &p, 0x04)
        var q = p
        _ = readTL(der, &q, 0x30); _ = readTL(der, &q, 0x02); q += 1
        let nl = readTL(der, &q, 0x02); let nd = der.subdata(in: q..<(q+nl)); q += nl
        let el = readTL(der, &q, 0x02); q += el
        let dl = readTL(der, &q, 0x02); let dd = der.subdata(in: q..<(q+dl))
        _clientN = BigU512(nd); _clientD = BigU512(dd)
        return (_clientN!, _clientD!)
    }

    private func readTL(_ d: Data, _ p: inout Int, _ tag: UInt8) -> Int {
        let f = d[p+1]; p += 2
        if f < 128 { return Int(f) }
        let n = Int(f & 0x7F); var l = 0
        for i in 0..<n { l = (l << 8) | Int(d[p+i]) }; p += n; return l
    }

    // MARK: - AES

    func aesEncrypt(_ pt: String, key: Data) throws -> String {
        guard let d = pt.data(using: .utf8) else { throw PortCryptoError.aesEncryptFailed }
        return try aesCrypt(CCOperation(kCCEncrypt), d, key).base64EncodedString()
    }
    func aesDecrypt(_ b64: String, key: Data) throws -> String {
        guard let d = Data(base64Encoded: b64) else { throw PortCryptoError.aesDecryptFailed }
        let r = try aesCrypt(CCOperation(kCCDecrypt), d, key)
        guard let s = String(data: r, encoding: .utf8) else { throw PortCryptoError.aesDecryptFailed }; return s
    }
    private func aesCrypt(_ op: CCOperation, _ d: Data, _ k: Data) throws -> Data {
        var n = 0; let sz = d.count + kCCBlockSizeAES128; var b = Data(count: sz)
        let st = k.withUnsafeBytes { kb in d.withUnsafeBytes { db in b.withUnsafeMutableBytes { bb in
            CCCrypt(op, CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                    kb.baseAddress, kCCKeySizeAES256, nil, db.baseAddress, d.count, bb.baseAddress, sz, &n) } } }
        guard st == kCCSuccess else { throw op == kCCEncrypt ? PortCryptoError.aesEncryptFailed : PortCryptoError.aesDecryptFailed }
        return b.prefix(n)
    }
}
