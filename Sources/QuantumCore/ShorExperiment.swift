import Foundation

public struct ShorRecovery: Equatable, Sendable {
    public let order: Int
    public let p: Int
    public let q: Int
    public var modulus: Int { p * q }

    public func rsaPrivateExponent(publicExponent: Int) -> Int? {
        modularInverse(publicExponent, modulus: (p - 1) * (q - 1))
    }
}

public struct RSAExample: Sendable {
    public let modulus: Int
    public let publicExponent: Int
    public let message = 2
    public let ciphertext: Int

    public init(modulus: Int = 15) {
        self.modulus = [15, 21, 35].contains(modulus) ? modulus : 15
        publicExponent = self.modulus == 15 ? 3 : 5
        ciphertext = modularPower(message, exponent: publicExponent, modulus: self.modulus)
    }

    public func recoveredMessage(using recovery: ShorRecovery) -> Int? {
        guard recovery.modulus == modulus,
              let d = recovery.rsaPrivateExponent(publicExponent: publicExponent) else { return nil }
        return modularPower(ciphertext, exponent: d, modulus: modulus)
    }
}

/// Exact ideal order-finding circuit for small composite moduli. Starting from
/// Q^-1/2 sum_x |x>|a^x mod N>, the inverse QFT is applied independently to the
/// amplitudes attached to each distinct work-register value, and its squared
/// magnitudes are summed. The marginal is calculated from modularValues; the
/// classicalOrder reference never participates in the quantum distribution or
/// measurement recovery. The transform sign does not change this marginal.
public struct ShorExperiment: Sendable {
    public let modulus: Int
    public let base: Int
    public let quantumRegisterSize: Int
    public let modularValues: [Int]
    public let phaseProbabilities: [Double]
    public let isValid: Bool

    /// Supported educational moduli are 15, 21, and 35. An invalid or noncoprime
    /// input is represented with isValid=false and empty arrays, never replaced
    /// by a hidden example. A noncoprime base already yields a classical factor.
    public init(modulus: Int = 15, base: Int = 2) {
        self.modulus = modulus
        self.base = base
        isValid = [15, 21, 35].contains(modulus) && base > 1 && base < modulus && gcd(base, modulus) == 1
        guard isValid else {
            quantumRegisterSize = 0
            modularValues = []
            phaseProbabilities = []
            return
        }
        var registerSize = 1
        while registerSize < modulus * modulus { registerSize <<= 1 }
        quantumRegisterSize = registerSize
        var values = [Int]()
        values.reserveCapacity(registerSize)
        var residue = 1
        for _ in 0..<registerSize {
            values.append(residue)
            residue = residue * base % modulus
        }
        modularValues = values
        var result = Array(repeating: 0.0, count: registerSize)
        for workValue in Set(values).sorted() {
            var amplitudes = values.map { Complex(real: $0 == workValue ? 1 : 0, imaginary: 0) }
            fft(&amplitudes)
            for index in 0..<registerSize {
                result[index] += amplitudes[index].squaredMagnitude / Double(registerSize * registerSize)
            }
        }
        // Only roundoff normalization; no period or factor information is used.
        let norm = result.reduce(0, +)
        phaseProbabilities = result.map { $0 / norm }
    }

    public var precisionQubits: Int {
        quantumRegisterSize > 0 ? quantumRegisterSize.trailingZeroBitCount : 0
    }

    /// Classical reference for explanation and cross-checking only.
    public var classicalOrder: Int {
        guard isValid else { return 0 }
        for candidate in 1..<modulus {
            if modularPower(base, exponent: candidate, modulus: modulus) == 1 { return candidate }
        }
        return 0
    }

    public func measure(unitSample: Double) -> Int {
        guard isValid else { return 0 }
        let sample = unitSample.isFinite ? min(1.nextDown, max(0, unitSample)) : 0
        var cumulative = 0.0
        for (index, probability) in phaseProbabilities.enumerated() {
            cumulative += probability
            if sample < cumulative { return index }
        }
        return quantumRegisterSize - 1
    }

    /// Continued fractions approximate the observed phase y/Q. A convergent
    /// must lie within half a measured bin, then its denominator and up to eight
    /// multiples are checked with modular exponentiation. Valid periods are
    /// reduced to the minimal order, and the even-period factor step is checked.
    /// y=0 carries no period information and deliberately returns nil. Some
    /// shots fail, as the algorithm does; users must prepare and sample again.
    public func postprocess(measurement: Int) -> ShorRecovery? {
        guard isValid, measurement > 0, measurement < quantumRegisterSize else { return nil }
        let phase = Double(measurement) / Double(quantumRegisterSize)
        var numerator = measurement, denominator = quantumRegisterSize
        var previousP = 0, p = 1, previousQ = 1, q = 0
        while denominator != 0 {
            let quotient = numerator / denominator
            let nextP = quotient * p + previousP
            let nextQ = quotient * q + previousQ
            (previousP, p) = (p, nextP)
            (previousQ, q) = (q, nextQ)
            guard q < modulus else { break }
            if q > 1 && abs(phase - Double(p) / Double(q)) <= 0.5 / Double(quantumRegisterSize) + 1e-12 {
                for multiplier in 1...8 {
                    let proposedOrder = q * multiplier
                    guard proposedOrder < modulus else { break }
                    guard modularPower(base, exponent: proposedOrder, modulus: modulus) == 1 else { continue }
                    let order = minimalValidatedOrder(proposedOrder)
                    guard order % 2 == 0 else { continue }
                    let halfPower = modularPower(base, exponent: order / 2, modulus: modulus)
                    guard halfPower != 1, halfPower != modulus - 1 else { continue }
                    let factor1 = gcd(halfPower - 1, modulus)
                    let factor2 = gcd(halfPower + 1, modulus)
                    guard factor1 > 1, factor2 > 1, factor1 * factor2 == modulus else { continue }
                    return ShorRecovery(order: order, p: min(factor1, factor2), q: max(factor1, factor2))
                }
            }
            (numerator, denominator) = (denominator, numerator % denominator)
        }
        return nil
    }

    private func minimalValidatedOrder(_ candidate: Int) -> Int {
        var order = candidate
        var divisor = 2
        while divisor <= order {
            while order % divisor == 0 && modularPower(base, exponent: order / divisor, modulus: modulus) == 1 {
                order /= divisor
            }
            divisor += 1
        }
        return order
    }
}

private struct Complex {
    var real: Double
    var imaginary: Double
    var squaredMagnitude: Double { real * real + imaginary * imaginary }
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(real: lhs.real + rhs.real, imaginary: lhs.imaginary + rhs.imaginary)
    }
    static func - (lhs: Self, rhs: Self) -> Self {
        Self(real: lhs.real - rhs.real, imaginary: lhs.imaginary - rhs.imaginary)
    }
    static func * (lhs: Self, rhs: Self) -> Self {
        Self(real: lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
             imaginary: lhs.real * rhs.imaginary + lhs.imaginary * rhs.real)
    }
}

/// Unnormalized radix-2 Fourier transform. Shor's two factors of 1/sqrt(Q)
/// (initial superposition and QFT) are accounted for in probability evaluation.
private func fft(_ values: inout [Complex]) {
    let count = values.count
    var reversed = 0
    for index in 1..<count {
        var bit = count >> 1
        while reversed & bit != 0 { reversed ^= bit; bit >>= 1 }
        reversed ^= bit
        if index < reversed { values.swapAt(index, reversed) }
    }
    var length = 2
    while length <= count {
        let angle = -2 * Double.pi / Double(length)
        let root = Complex(real: cos(angle), imaginary: sin(angle))
        for offset in stride(from: 0, to: count, by: length) {
            var factor = Complex(real: 1, imaginary: 0)
            for index in 0..<(length / 2) {
                let first = values[offset + index]
                let second = values[offset + index + length / 2] * factor
                values[offset + index] = first + second
                values[offset + index + length / 2] = first - second
                factor = factor * root
            }
        }
        length <<= 1
    }
}
