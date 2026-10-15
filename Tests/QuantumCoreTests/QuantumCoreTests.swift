import Foundation
import Testing
@testable import QuantumCore

@Test func groverMatchesClosedFormAndPreservesProbability() {
    for qubits in 2...6 {
        var experiment = GroverExperiment(qubitCount: qubits, target: (1 << qubits) - 2)
        let theta = asin(1 / sqrt(Double(experiment.stateCount)))
        for iteration in 0..<100 {
            #expect(abs(experiment.probabilities.reduce(0, +) - 1) < 1e-11)
            let expected = pow(sin(Double(2 * iteration + 1) * theta), 2)
            #expect(abs(experiment.targetProbability - expected) < 1e-11)
            experiment.step()
        }
    }
}

@Test func oracleOnlyChangesPhaseAndDiffusionIsGated() {
    var experiment = GroverExperiment(qubitCount: 3, target: 5)
    let initial = experiment.probabilities
    experiment.diffuse()
    #expect(experiment.iteration == 0)
    experiment.oracle()
    #expect(experiment.stage == .oracleApplied)
    #expect(experiment.probabilities == initial)
    #expect(experiment.amplitudes[5] < 0)
    experiment.oracle()
    #expect(experiment.amplitudes[5] < 0)
    experiment.step()
    #expect(experiment.iteration == 1)
    #expect(abs(experiment.targetProbability - 0.78125) < 1e-12)
    experiment.reset()
    #expect(experiment.stage == .ready)
    #expect(experiment.probabilities == initial)
}

@Test func groverOverRotationAndWeightedShots() {
    var eight = GroverExperiment(qubitCount: 3, target: 3)
    #expect(eight.optimalIteration == 2)
    eight.step(); eight.step()
    #expect(abs(eight.targetProbability - 0.9453125) < 1e-12)
    eight.step()
    #expect(abs(eight.targetProbability - 0.330078125) < 1e-12)

    var sixteen = GroverExperiment(qubitCount: 4, target: 11)
    #expect(sixteen.optimalIteration == 3)
    for _ in 0..<3 { sixteen.step() }
    #expect(abs(sixteen.targetProbability - 0.9613189697265625) < 1e-12)
    let stateBeforeShots = sixteen.amplitudes
    let shots = (0..<10_000).map { sixteen.measure(unitSample: (Double($0) + 0.5) / 10_000) }
    let hitRate = Double(shots.filter { $0 == 11 }.count) / 10_000
    #expect(abs(hitRate - sixteen.targetProbability) < 0.0002)
    #expect(sixteen.amplitudes == stateBeforeShots)
    sixteen.step()
    #expect(sixteen.targetProbability < 0.59)
}

@Test func groverBoundsAndNonfiniteSample() {
    let experiment = GroverExperiment(qubitCount: 300, target: -1)
    #expect(experiment.qubitCount == 6)
    #expect(experiment.target == 0)
    #expect(experiment.measure(unitSample: .nan) == 0)
    #expect(experiment.measure(unitSample: 1) == 63)
}

@Test func shorQuarterPhasesForFifteenAreExact() {
    let experiment = ShorExperiment(modulus: 15, base: 2)
    #expect(experiment.quantumRegisterSize == 256)
    #expect(experiment.precisionQubits == 8)
    #expect(Array(experiment.modularValues.prefix(8)) == [1, 2, 4, 8, 1, 2, 4, 8])
    for index in experiment.phaseProbabilities.indices {
        let expected = index % 64 == 0 ? 0.25 : 0.0
        #expect(abs(experiment.phaseProbabilities[index] - expected) < 1e-12)
    }
    #expect(experiment.postprocess(measurement: 0) == nil)
    for phase in [64, 128, 192] {
        let recovery = experiment.postprocess(measurement: phase)
        #expect(recovery?.order == 4)
        #expect(recovery?.p == 3)
        #expect(recovery?.q == 5)
    }
    #expect(experiment.postprocess(measurement: 1) == nil)
}

@Test func shorFFTMatchesIndependentJointAmplitudeCalculation() {
    let experiment = ShorExperiment(modulus: 21, base: 2)
    #expect(experiment.quantumRegisterSize == 512)
    // Direct circuit amplitudes supply a separate numerical cross-check of the
    // FFT, including non-dyadic periods and small side lobes between peaks.
    for measurement in [0, 1, 84, 85, 86, 171, 256, 341, 427, 511] {
        var probability = 0.0
        for residue in Set(experiment.modularValues) {
            var real = 0.0, imaginary = 0.0
            for x in experiment.modularValues.indices where experiment.modularValues[x] == residue {
                let angle = 2 * Double.pi * Double(x * measurement) / Double(experiment.quantumRegisterSize)
                real += cos(angle)
                imaginary += sin(angle)
            }
            probability += (real * real + imaginary * imaginary) /
                Double(experiment.quantumRegisterSize * experiment.quantumRegisterSize)
        }
        #expect(abs(experiment.phaseProbabilities[measurement] - probability) < 1e-11)
    }
}

@Test func shorRecoveryAndRSAUseMeasuredPhase() throws {
    for (modulus, order, p, q, ciphertext, privateExponent) in [
        (15, 4, 3, 5, 8, 3), (21, 6, 3, 7, 11, 5), (35, 12, 5, 7, 32, 5)
    ] {
        let experiment = ShorExperiment(modulus: modulus, base: 2)
        #expect(abs(experiment.phaseProbabilities.reduce(0, +) - 1) < 1e-12)
        #expect(experiment.phaseProbabilities.allSatisfy { $0 >= 0 })
        #expect(experiment.quantumRegisterSize >= modulus * modulus)
        #expect(experiment.quantumRegisterSize / 2 < modulus * modulus)
        let measured = Int((Double(experiment.quantumRegisterSize) / Double(order)).rounded())
        let recovery = try #require(experiment.postprocess(measurement: measured))
        #expect(recovery.order == order)
        #expect(recovery.p == p)
        #expect(recovery.q == q)
        let rsa = RSAExample(modulus: modulus)
        #expect(rsa.ciphertext == ciphertext)
        #expect(rsa.recoveredMessage(using: recovery) == 2)
        let d = try #require(recovery.rsaPrivateExponent(publicExponent: rsa.publicExponent))
        #expect(d == privateExponent)
        for message in 0..<modulus {
            let encrypted = modularPower(message, exponent: rsa.publicExponent, modulus: modulus)
            #expect(modularPower(encrypted, exponent: d, modulus: modulus) == message)
        }
    }
}

@Test func shorRejectsBadInputsAndUnhelpfulPeriods() {
    for (modulus, base) in [(0, 2), (17, 2), (15, 3), (21, 1), (35, 35)] {
        let experiment = ShorExperiment(modulus: modulus, base: base)
        #expect(!experiment.isValid)
        #expect(experiment.phaseProbabilities.isEmpty)
        #expect(experiment.postprocess(measurement: 1) == nil)
    }
    let oddOrder = ShorExperiment(modulus: 21, base: 4)
    #expect(oddOrder.classicalOrder == 3)
    #expect(oddOrder.postprocess(measurement: 171) == nil)
    let minusOne = ShorExperiment(modulus: 15, base: 14)
    #expect(minusOne.classicalOrder == 2)
    #expect(minusOne.postprocess(measurement: 128) == nil)
    let usefulTwo = ShorExperiment(modulus: 35, base: 6)
    #expect(usefulTwo.postprocess(measurement: 1_024)?.order == 2)
    #expect(usefulTwo.postprocess(measurement: -1) == nil)
    #expect(usefulTwo.postprocess(measurement: 2_048) == nil)
}

@Test func exactThermalNumbersAndTemperatureCeiling() {
    let cold = QubitTelemetry(control: QubitControl(temperatureMK: 20))
    let warm = QubitTelemetry(control: QubitControl(temperatureMK: 50))
    let hot = QubitTelemetry(control: QubitControl(temperatureMK: 100))
    #expect(abs(cold.thermalExcitedPopulation - 0.000006155812261) < 1e-12)
    #expect(abs(warm.thermalExcitedPopulation - 0.008168701469) < 1e-10)
    #expect(abs(hot.thermalExcitedPopulation - 0.0832015607669) < 1e-10)
    #expect(abs(cold.thermalLimitMK() - 52.219999) < 0.01)
    let threshold = cold.thermalLimitMK(targetPop: 0.001)
    let atThreshold = QubitTelemetry(control: QubitControl(temperatureMK: threshold))
    #expect(abs(atThreshold.thermalExcitedPopulation - 0.001) < 1e-12)
    #expect(cold.thermalLimitMK(targetPop: 0) == 0)
}

@Test func telemetryIsBoundedAndFrequencyMatchingDoesNotCool() {
    for temperature in stride(from: 5.0, through: 300, by: 5) {
        for noise in [0.0, 0.2, 1.0] {
            let telemetry = QubitTelemetry(control: QubitControl(temperatureMK: temperature, dephasingNoise: noise))
            #expect(telemetry.t2Microseconds <= 2 * telemetry.t1Microseconds)
            #expect((0...1).contains(telemetry.gateFidelity))
        }
    }
    let matched = QubitTelemetry(control: QubitControl(driveDetuningMHz: 0))
    let detuned = QubitTelemetry(control: QubitControl(driveDetuningMHz: 10))
    #expect(matched.thermalExcitedPopulation == detuned.thermalExcitedPopulation)
    #expect(matched.gateFidelity > detuned.gateFidelity)
    let lessDephasing = QubitTelemetry(control: QubitControl(dephasingNoise: 0))
    let moreDephasing = QubitTelemetry(control: QubitControl(dephasingNoise: 1))
    #expect(lessDephasing.t1Microseconds == moreDephasing.t1Microseconds)
    #expect(lessDephasing.t2Microseconds > moreDephasing.t2Microseconds)
    let invalid = QubitTelemetry(control: QubitControl(temperatureMK: .nan, frequencyGHz: .infinity,
                                                       rabiMHz: -1, dephasingNoise: -1, readoutNoise: 2))
    #expect(invalid.t1Microseconds.isFinite)
    #expect(invalid.gateFidelity == 0)
}

@Test func blochPiPulseAndOffResonanceResponse() {
    var resonant = BlochState()
    resonant.advance(control: QubitControl(dephasingNoise: 0), deltaMicroseconds: 0.5)
    #expect(resonant.excitedProbability > 0.99)
    var detuned = BlochState()
    detuned.advance(control: QubitControl(driveDetuningMHz: 10, dephasingNoise: 0), deltaMicroseconds: 0.5)
    #expect(detuned.excitedProbability < 0.02)
}

@Test func blochRelaxationReachesThermalEquilibriumWithoutDrive() {
    let control = QubitControl(temperatureMK: 100, rabiMHz: 0)
    let telemetry = QubitTelemetry(control: control)
    var state = BlochState(x: 0, y: 0, z: -1)
    state.advance(control: control, deltaMicroseconds: telemetry.t1Microseconds * 30)
    #expect(abs(state.excitedProbability - telemetry.thermalExcitedPopulation) < 1e-11)
    #expect(state.x == 0 && state.y == 0)
}

@Test func blochStatesRemainPhysicalUnderModulation() {
    var state = BlochState(x: 1, y: 0, z: 0)
    for iteration in 0..<300 {
        let control = QubitControl(temperatureMK: Double(iteration % 295 + 5),
                                   frequencyGHz: 0.1 + Double(iteration % 149) / 10,
                                   driveDetuningMHz: Double(iteration % 41 - 20),
                                   rabiMHz: Double(iteration % 11),
                                   dephasingNoise: Double(iteration % 11) / 10)
        let duration = [0.001, 0.1, 1.0, 1_000.0][iteration % 4]
        state.advance(control: control, deltaMicroseconds: duration)
        #expect(state.x.isFinite && state.y.isFinite && state.z.isFinite)
        #expect(state.x * state.x + state.y * state.y + state.z * state.z <= 1 + 1e-12)
        #expect((0.5...1).contains(state.purity))
        #expect(abs(state.groundProbability + state.excitedProbability - 1) < 1e-12)
    }
    state.advance(control: QubitControl(), deltaMicroseconds: .nan)
    #expect(state.z.isFinite)
    state.reset()
    #expect(state == BlochState())
}

@Test func ellipticCurveGroupAndDiscreteLogEnumeration() {
    let curve = EllipticCurveToy()
    #expect(curve.curvePoints.count == 19)
    #expect(Set(curve.candidates.map(\.point)).count == 18)
    #expect(curve.multiply(curve.generator, scalar: 19) == .infinity)
    #expect(curve.multiply(curve.generator, scalar: 2) == CurvePoint(x: 6, y: 3))
    #expect(curve.publicKey == CurvePoint(x: 0, y: 6))
    for lhs in curve.curvePoints {
        #expect(curve.add(lhs, .infinity) == lhs)
        for rhs in curve.curvePoints {
            #expect(curve.isOnCurve(curve.add(lhs, rhs)))
            #expect(curve.add(lhs, rhs) == curve.add(rhs, lhs))
            for third in curve.curvePoints {
                #expect(curve.add(curve.add(lhs, rhs), third) == curve.add(lhs, curve.add(rhs, third)))
            }
        }
    }
    for secret in 1...18 {
        let toy = EllipticCurveToy(secret: secret)
        #expect(toy.recoveredSecret == secret)
        #expect(toy.candidates.filter(\.matchesPublicKey).count == 1)
    }
}
