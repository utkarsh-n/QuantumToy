import Foundation

/// Euclidean GCD for the small, nonnegative integers used by these toys.
public func gcd(_ lhs: Int, _ rhs: Int) -> Int {
    var a = abs(lhs), b = abs(rhs)
    while b != 0 { (a, b) = (b, a % b) }
    return a
}

/// Repeated squaring. Inputs are limited to small toy moduli to avoid integer
/// overflow; this is not an implementation for cryptographic production use.
public func modularPower(_ base: Int, exponent: Int, modulus: Int) -> Int {
    guard modulus > 1, modulus <= 1_000_000, exponent >= 0 else { return 0 }
    var result = 1
    var factor = ((base % modulus) + modulus) % modulus
    var power = exponent
    while power > 0 {
        if power & 1 == 1 { result = result * factor % modulus }
        factor = factor * factor % modulus
        power >>= 1
    }
    return result
}

public func modularInverse(_ value: Int, modulus: Int) -> Int? {
    guard modulus > 1 else { return nil }
    var oldR = modulus, r = ((value % modulus) + modulus) % modulus
    var oldT = 0, t = 1
    while r != 0 {
        let quotient = oldR / r
        (oldR, r) = (r, oldR - quotient * r)
        (oldT, t) = (t, oldT - quotient * t)
    }
    guard oldR == 1 else { return nil }
    return ((oldT % modulus) + modulus) % modulus
}
