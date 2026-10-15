import Foundation

/// Controls for a single driven two-level qubit in a rotating frame.
/// temperatureMK is the effective qubit temperature, not a refrigerator sensor
/// reading. frequencyGHz sets the energy gap; matching the drive to it does not
/// cool the qubit. MHz is cycles per microsecond for the dynamical model.
public struct QubitControl: Sendable, Equatable {
    public var temperatureMK: Double
    public var frequencyGHz: Double
    public var driveDetuningMHz: Double
    public var rabiMHz: Double
    public var dephasingNoise: Double
    public var readoutNoise: Double

    public init(temperatureMK: Double = 20, frequencyGHz: Double = 5,
                driveDetuningMHz: Double = 0, rabiMHz: Double = 1,
                dephasingNoise: Double = 0.1, readoutNoise: Double = 0.02) {
        self.temperatureMK = temperatureMK
        self.frequencyGHz = frequencyGHz
        self.driveDetuningMHz = driveDetuningMHz
        self.rabiMHz = rabiMHz
        self.dephasingNoise = dephasingNoise
        self.readoutNoise = readoutNoise
    }

    /// Bounds apply at evaluation as controls can be mutated by the interface.
    public var bounded: Self {
        Self(temperatureMK: bound(temperatureMK, 5...300, fallback: 20),
             frequencyGHz: bound(frequencyGHz, 0.1...15, fallback: 5),
             driveDetuningMHz: bound(driveDetuningMHz, -20...20, fallback: 0),
             rabiMHz: bound(rabiMHz, 0...10, fallback: 1),
             dephasingNoise: bound(dephasingNoise, 0...1, fallback: 0.1),
             readoutNoise: bound(readoutNoise, 0...0.5, fallback: 0.02))
    }
}

/// Equilibrium thermal population follows the two-level Boltzmann formula.
/// T1, T2, and the gateFidelity score are illustrative engineering telemetry,
/// not device-calibrated predictions. The T1 heuristic saturates below 20 mK;
/// reducing temperature further still affects Boltzmann population, but it does
/// not remove the independent dephasing or readout-noise controls. No universal
/// optimal temperature is implied. T2 is always constrained to <= 2 T1.
public struct QubitTelemetry: Sendable {
    public let thermalExcitedPopulation: Double
    public let t1Microseconds: Double
    public let t2Microseconds: Double
    /// Heuristic preparation/control/readout score, not average gate fidelity.
    /// Includes the detuned-drive amplitude envelope; omits its pulse sine term.
    public let gateFidelity: Double
    public let recommendedTemperatureMK = 20.0
    public let frequencyGHz: Double

    public init(control: QubitControl) {
        let control = control.bounded
        frequencyGHz = control.frequencyGHz
        let gapOverThermalEnergy = 47.992430733 * control.frequencyGHz / control.temperatureMK
        thermalExcitedPopulation = 1 / (1 + exp(gapOverThermalEnergy))
        let warmPenalty = 0.025 * max(0, control.temperatureMK - 20)
        t1Microseconds = 100 / (1 + warmPenalty)
        let pureDephasingRate = 1 / 160.0 + control.dephasingNoise / 15
        t2Microseconds = 1 / (1 / (2 * t1Microseconds) + pureDephasingRate)
        guard control.rabiMHz > 0 else {
            gateFidelity = 0
            return
        }
        let pulseDuration = 1 / (2 * control.rabiMHz)
        let coherentDriveFraction = control.rabiMHz * control.rabiMHz /
            (control.rabiMHz * control.rabiMHz + control.driveDetuningMHz * control.driveDetuningMHz)
        gateFidelity = bound((1 - control.readoutNoise) * (1 - thermalExcitedPopulation) *
                             exp(-pulseDuration / t2Microseconds) * coherentDriveFraction,
                             0...1, fallback: 0)
    }

    /// Temperature ceiling for a requested ideal equilibrium excited population.
    /// This is a tolerance threshold, not an optimum or a cooling guarantee.
    public func thermalLimitMK(targetPop: Double = 0.01) -> Double {
        guard targetPop.isFinite, targetPop > 0, targetPop < 0.5 else { return 0 }
        return 47.992430733 * frequencyGHz / log((1 - targetPop) / targetPop)
    }
}

/// Density matrix rho=(I+x sigma_x+y sigma_y+z sigma_z)/2, with z=+1
/// denoting |0> (ground). The driven Bloch equations use angular frequencies
/// Omega=2 pi rabiMHz and Delta=2 pi driveDetuningMHz in radians/microsecond:
/// x'=-Delta*y-x/T2; y'=Delta*x-Omega*z-y/T2;
/// z'=Omega*y-(z-zEquilibrium)/T1. A symmetric split of exact coherent rotation
/// and generalized amplitude/phase damping preserves physical states even at
/// large timesteps. Fine substeps improve agreement with the continuous model.
public struct BlochState: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double = 0, y: Double = 0, z: Double = 1) {
        self.x = x; self.y = y; self.z = z
        makePhysical()
    }

    public var groundProbability: Double { bound((1 + z) / 2, 0...1, fallback: 1) }
    public var excitedProbability: Double { 1 - groundProbability }
    public var purity: Double { bound((1 + x * x + y * y + z * z) / 2, 0.5...1, fallback: 1) }

    public mutating func reset() { self = Self() }

    /// Subdivision is capped at 512 steps to bound execution. For quantitative
    /// continuous evolution, use small increments (the app uses <=0.08 us).
    /// Very long coherent intervals preserve physicality but can lose accuracy.
    public mutating func advance(control: QubitControl, deltaMicroseconds: Double) {
        guard deltaMicroseconds.isFinite, deltaMicroseconds > 0 else { return }
        makePhysical()
        let control = control.bounded
        let telemetry = QubitTelemetry(control: control)
        let omega = 2 * Double.pi * control.rabiMHz
        let detuning = 2 * Double.pi * control.driveDetuningMHz
        let rotationRate = hypot(omega, detuning)
        let duration = min(1_000_000, deltaMicroseconds)
        let desiredSteps = max(1.0, ceil(duration * max(rotationRate, 1 / telemetry.t2Microseconds) / 0.2))
        let steps = Int(min(512, desiredSteps))
        let stepDuration = duration / Double(steps)
        let equilibrium = 1 - 2 * telemetry.thermalExcitedPopulation
        for _ in 0..<steps {
            relax(duration: stepDuration / 2, telemetry: telemetry, equilibrium: equilibrium)
            if rotationRate > 0 {
                let nx = omega / rotationRate, nz = detuning / rotationRate
                let angle = rotationRate * stepDuration
                let cosine = cos(angle), sine = sin(angle)
                let dot = nx * x + nz * z
                let nextX = x * cosine - nz * y * sine + nx * dot * (1 - cosine)
                let nextY = y * cosine + (nz * x - nx * z) * sine
                let nextZ = z * cosine + nx * y * sine + nz * dot * (1 - cosine)
                x = nextX; y = nextY; z = nextZ
            }
            relax(duration: stepDuration / 2, telemetry: telemetry, equilibrium: equilibrium)
        }
        makePhysical()
    }

    private mutating func relax(duration: Double, telemetry: QubitTelemetry, equilibrium: Double) {
        let transverse = exp(-duration / telemetry.t2Microseconds)
        x *= transverse
        y *= transverse
        z = equilibrium + (z - equilibrium) * exp(-duration / telemetry.t1Microseconds)
    }

    private mutating func makePhysical() {
        guard x.isFinite, y.isFinite, z.isFinite else { x = 0; y = 0; z = 1; return }
        let radius = sqrt(x * x + y * y + z * z)
        if !radius.isFinite { x = 0; y = 0; z = 1 }
        else if radius > 1 { x /= radius; y /= radius; z /= radius }
    }
}

private func bound(_ value: Double, _ limits: ClosedRange<Double>, fallback: Double) -> Double {
    value.isFinite ? min(limits.upperBound, max(limits.lowerBound, value)) : fallback
}
