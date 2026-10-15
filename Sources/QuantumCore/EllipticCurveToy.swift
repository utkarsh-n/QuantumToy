import Foundation

public struct CurvePoint: Equatable, Hashable, Sendable {
    public let x: Int?
    public let y: Int?
    public var isInfinity: Bool { x == nil || y == nil }
    public static let infinity = Self()

    public init(x: Int? = nil, y: Int? = nil) {
        if let x, let y {
            self.x = ((x % 17) + 17) % 17
            self.y = ((y % 17) + 17) % 17
        } else {
            self.x = nil
            self.y = nil
        }
    }
}

public struct ScalarCandidate: Equatable, Sendable {
    public let scalar: Int
    public let point: CurvePoint
    public let matchesPublicKey: Bool
}

/// A classical visualization of elliptic-curve discrete logarithms in F17.
/// The curve y²=x³+2x+2 has 19 points, and G=(5,1) has order 19.
/// Exhaustively testing the 18 nonzero scalars is feasible only because this
/// group is tiny. This enumeration is not a simulation of Shor's elliptic-curve
/// quantum circuit and makes no claim to attack a real secp256k1 private key.
public struct EllipticCurveToy: Sendable {
    public let fieldModulus = 17
    public let groupOrder = 19
    public let secret: Int
    public let generator = CurvePoint(x: 5, y: 1)
    public let publicKey: CurvePoint
    public let candidates: [ScalarCandidate]
    public let curvePoints: [CurvePoint]
    public var recoveredSecret: Int? { candidates.first { $0.matchesPublicKey }?.scalar }

    public init(secret: Int = 7) {
        self.secret = min(18, max(1, secret))
        let key = Self.multiply(CurvePoint(x: 5, y: 1), scalar: self.secret)
        publicKey = key
        candidates = (1...18).map { scalar in
            let point = Self.multiply(CurvePoint(x: 5, y: 1), scalar: scalar)
            return ScalarCandidate(scalar: scalar, point: point, matchesPublicKey: point == key)
        }
        var points = [CurvePoint.infinity]
        for x in 0..<17 {
            for y in 0..<17 where y * y % 17 == (x * x * x + 2 * x + 2) % 17 {
                points.append(CurvePoint(x: x, y: y))
            }
        }
        curvePoints = points
    }

    public func add(_ lhs: CurvePoint, _ rhs: CurvePoint) -> CurvePoint { Self.add(lhs, rhs) }
    public func multiply(_ point: CurvePoint, scalar: Int) -> CurvePoint { Self.multiply(point, scalar: scalar) }

    public func isOnCurve(_ point: CurvePoint) -> Bool {
        guard let x = point.x, let y = point.y else { return true }
        return y * y % 17 == (x * x * x + 2 * x + 2) % 17
    }

    private static func add(_ lhs: CurvePoint, _ rhs: CurvePoint) -> CurvePoint {
        guard let x1 = lhs.x, let y1 = lhs.y else { return rhs }
        guard let x2 = rhs.x, let y2 = rhs.y else { return lhs }
        if x1 == x2 && (y1 + y2) % 17 == 0 { return .infinity }
        let numerator = lhs == rhs ? 3 * x1 * x1 + 2 : y2 - y1
        let denominator = lhs == rhs ? 2 * y1 : x2 - x1
        guard let inverse = modularInverse(denominator, modulus: 17) else { return .infinity }
        let slope = normalize(numerator * inverse)
        let x3 = normalize(slope * slope - x1 - x2)
        return CurvePoint(x: x3, y: normalize(slope * (x1 - x3) - y1))
    }

    private static func multiply(_ point: CurvePoint, scalar: Int) -> CurvePoint {
        var count = normalizeScalar(scalar)
        var result = CurvePoint.infinity
        var summand = point
        while count > 0 {
            if count & 1 == 1 { result = add(result, summand) }
            summand = add(summand, summand)
            count >>= 1
        }
        return result
    }

    private static func normalize(_ value: Int) -> Int { ((value % 17) + 17) % 17 }
    private static func normalizeScalar(_ value: Int) -> Int { ((value % 19) + 19) % 19 }
}
