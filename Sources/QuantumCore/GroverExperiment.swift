import Foundation

public enum GroverStage: String, Sendable, CaseIterable {
    case ready
    case oracleApplied
    case diffused
}

/// Exact real state-vector simulation for one marked basis state.
/// The oracle changes a phase, not a probability. Diffusion then converts that
/// relative phase into amplitude amplification. Real amplitudes suffice for
/// this circuit because every gate in the demonstration is real.
public struct GroverExperiment: Sendable {
    public let qubitCount: Int
    public let target: Int
    public private(set) var amplitudes: [Double]
    public private(set) var iteration = 0
    public private(set) var stage: GroverStage = .ready

    /// Educational register sizes are clamped to 2...6; targets to 0..<2^n.
    public init(qubitCount: Int = 3, target: Int = 5) {
        self.qubitCount = min(6, max(2, qubitCount))
        let count = 1 << self.qubitCount
        self.target = min(count - 1, max(0, target))
        amplitudes = Array(repeating: 1 / sqrt(Double(count)), count: count)
    }

    public var stateCount: Int { amplitudes.count }
    public var probabilities: [Double] { amplitudes.map { $0 * $0 } }
    public var targetProbability: Double { amplitudes[target] * amplitudes[target] }
    public var optimalIteration: Int {
        max(0, Int((Double.pi / (4 * asin(1 / sqrt(Double(stateCount)))) - 0.5).rounded()))
    }

    public mutating func oracle() {
        guard stage != .oracleApplied else { return }
        amplitudes[target] *= -1
        stage = .oracleApplied
    }

    public mutating func diffuse() {
        guard stage == .oracleApplied else { return }
        let mean = amplitudes.reduce(0, +) / Double(stateCount)
        amplitudes = amplitudes.map { 2 * mean - $0 }
        iteration += 1
        stage = .diffused
    }

    public mutating func step() {
        oracle()
        diffuse()
    }

    public mutating func reset() {
        amplitudes = Array(repeating: 1 / sqrt(Double(stateCount)), count: stateCount)
        iteration = 0
        stage = .ready
    }

    /// Samples the current Born distribution. Pass a random value in [0,1)
    /// or a fixed value for deterministic replay. This samples without collapse
    /// so the user can compare repeated shots of the same prepared circuit.
    public func measure(unitSample: Double) -> Int {
        let sample = unitSample.isFinite ? min(1.nextDown, max(0, unitSample)) : 0
        var cumulative = 0.0
        for (index, amplitude) in amplitudes.enumerated() {
            cumulative += amplitude * amplitude
            if sample < cumulative { return index }
        }
        return stateCount - 1
    }
}
