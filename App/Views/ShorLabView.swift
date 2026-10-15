import SwiftUI
import QuantumCore

struct ShorLabView: View {
    @State private var modulus = 15
    @State private var experiment = ShorExperiment(modulus: 15, base: 2)
    @State private var stage = 0
    @State private var measurement: Int?
    @State private var recovery: ShorRecovery?
    @State private var attempts = 0
    @State private var isRunning = false
    @State private var runTask: Task<Void, Never>?
    @State private var runGeneration = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let stepNames = ["Prepare", "Modular power", "Inverse QFT", "Measure", "Recover"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LabHeader(eyebrow: "01 / Order finding", title: "Shor's algorithm",
                          subtitle: "Find a hidden repetition. Turn its period into two factors.")
                modulusControl
                ShorPeriodRotor(modulus: modulus, base: 2,
                                values: Array(experiment.modularValues.prefix(16)),
                                isPrepared: stage > 0, factors: recovery.map { "\($0.p) × \($0.q)" })
                circuitStrip
                stageExplanation
                circuitControls
                if stage >= 2 { phaseSpectrum }
                if stage == 4 { recoveryPanel }
                LabNote(title: "The quantum part finds an order",
                        text: "The period r is the smallest positive exponent that returns to 1. A useful measurement reveals a fraction s/r. Classical continued fractions and modular arithmetic then verify a candidate order and extract factors.",
                        equation: "2ʳ ≡ 1 (mod N)\ngcd(2ʳ⁄² ± 1, N) → factors")
                modelDisclosure
            }
            .padding(20)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .onDisappear { cancelRun() }
        .onChange(of: modulus) { _, _ in resetForModulus() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelRun() }
        }
    }

    private var modulusControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NUMBER TO FACTOR · BASE a = 2")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(InstrumentPalette.secondaryInk)
            Picker("Number to factor", selection: $modulus) {
                Text("15").tag(15)
                Text("21").tag(21)
                Text("35").tag(35)
            }
            .pickerStyle(.segmented)
            .tint(InstrumentPalette.actionCyan)
            .accessibilityIdentifier("shorModulusPicker")
            .disabled(isRunning)
            .accessibilityHint("Starts a new order-finding experiment with base 2.")
        }
    }

    private var circuitStrip: some View {
        HStack(alignment: .top, spacing: 3) {
            ForEach(stepNames.indices, id: \.self) { index in
                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(index == stage ? InstrumentPalette.actionCyan.opacity(0.13) : .white.opacity(0.025))
                        Circle().strokeBorder(index <= stage ? InstrumentPalette.actionCyan.opacity(0.6) : .white.opacity(0.12), lineWidth: 1)
                        if index < stage {
                            Image(systemName: "checkmark").font(.caption.weight(.semibold))
                        } else {
                            Text("\(index + 1)").font(.system(.caption, design: .monospaced))
                        }
                    }
                    .foregroundStyle(index <= stage ? InstrumentPalette.actionCyan : InstrumentPalette.secondaryInk)
                    .frame(width: 30, height: 30)
                    Text(stepNames[index])
                        .font(.system(.caption2, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(index == stage ? InstrumentPalette.displayInk : InstrumentPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Circuit progress")
        .accessibilityValue("Step \(stage + 1) of 5: \(stepNames[stage])")
    }

    private var stageExplanation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stepNames[stage])
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(InstrumentPalette.displayInk)
            Text(stageDescription)
                .font(.subheadline)
                .foregroundStyle(InstrumentPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("shorMeasurement")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stageDescription: String {
        switch stage {
        case 0:
            return "Hadamard gates prepare \(experiment.precisionQubits) counting qubits in an equal superposition of \(experiment.quantumRegisterSize) exponents."
        case 1:
            return "Compute 2ˣ mod \(modulus) coherently. Exponents with the same modular output become entangled with that output register. The wheel shows the first 16 powers."
        case 2:
            return "The inverse quantum Fourier transform converts repetition into phase peaks. Their spacing carries the order; it does not hand us a factor directly."
        case 3:
            let sample = measurement ?? 0
            return "The register returned y = \(sample). Now use continued fractions on \(sample)/\(experiment.quantumRegisterSize), then verify the candidate with modular exponentiation."
        default:
            if let recovery {
                return "Verified order r = \(recovery.order). The two greatest common divisors give \(recovery.p) and \(recovery.q), and \(recovery.p) × \(recovery.q) = \(modulus)."
            }
            return "This sample did not recover useful factors. Some outcomes give zero phase, an incomplete denominator, or an unusable order. Try another measurement."
        }
    }

    private var circuitControls: some View {
        VStack(spacing: 10) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    LabAction(title: nextStepTitle, symbol: "forward.end.fill", action: advance)
                        .disabled(isRunning || stage == 4)
                        .accessibilityIdentifier("shorNext")
                    LabAction(title: isRunning ? "Running…" : "Run circuit", symbol: "play.fill",
                              accent: InstrumentPalette.actionAmber, action: runCircuit)
                        .disabled(isRunning || stage == 4)
                }
            }
            HStack(spacing: 10) {
                if stage == 4 {
                    LabAction(title: "Sample again", symbol: "arrow.clockwise",
                              accent: InstrumentPalette.actionAmber) {
                        stage = 2
                        measurement = nil
                        recovery = nil
                        QuantumFeedback.selection()
                    }
                    .accessibilityIdentifier("shorRetry")
                }
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    resetCircuit()
                    QuantumFeedback.selection()
                }
                .font(.subheadline)
                .foregroundStyle(InstrumentPalette.secondaryInk)
                .frame(minHeight: 44)
                .disabled(isRunning)
                .accessibilityLabel("Reset Shor circuit")
                .accessibilityIdentifier("shorReset")
            }
        }
    }

    private var nextStepTitle: String {
        switch stage {
        case 0: "Apply powers"
        case 1: "Inverse QFT"
        case 2: "Measure"
        case 3: "Find factors"
        default: "Complete"
        }
    }

    private var phaseSpectrum: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("PHASE PROBABILITY")
                        .font(.system(.caption, design: .monospaced)).tracking(1)
                    Spacer()
                    Text("\(experiment.precisionQubits) QUBITS")
                        .font(.system(.caption2, design: .monospaced))
                }
                .foregroundStyle(InstrumentPalette.secondaryInk)
                ProbabilityBars(values: binnedProbabilities,
                                highlighted: measurement.map { min(63, $0 * 64 / experiment.quantumRegisterSize) },
                                labels: ["0", "y / Q", "1"])
                if let measurement {
                    HStack {
                        InstrumentMetricReadout("MEASURED y", value: "\(measurement)", unit: "",
                                                color: InstrumentPalette.actionAmber)
                        InstrumentMetricReadout("PHASE y / Q",
                                                value: (Double(measurement) / Double(experiment.quantumRegisterSize)).formatted(.number.precision(.fractionLength(4))),
                                                unit: "")
                    }
                }
                Text("64 bins sum the exact simulated probabilities. Peaks near s/r are useful; each measurement is sampled from the full distribution.")
                    .font(.caption)
                    .foregroundStyle(InstrumentPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var binnedProbabilities: [Double] {
        let probabilities = experiment.phaseProbabilities
        var bins = Array(repeating: 0.0, count: 64)
        for (index, probability) in probabilities.enumerated() {
            bins[min(63, index * 64 / probabilities.count)] += probability
        }
        return bins
    }

    private var recoveryPanel: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 14) {
                Label(recovery == nil ? "A retry is part of the algorithm" : "Factors verified",
                      systemImage: recovery == nil ? "arrow.trianglehead.2.clockwise.rotate.90" : "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(recovery == nil ? InstrumentPalette.actionAmber : InstrumentPalette.actionCyan)
                if let recovery {
                    Text("\(recovery.p) × \(recovery.q) = \(modulus)")
                        .font(.system(.largeTitle, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(InstrumentPalette.displayInk)
                        .accessibilityIdentifier("shorFactors")
                    let rsa = RSAExample(modulus: modulus)
                    if let decoded = rsa.recoveredMessage(using: recovery) {
                        Divider().overlay(.white.opacity(0.1))
                        Text("Why this matters for RSA").font(.headline)
                            .foregroundStyle(InstrumentPalette.displayInk)
                        Text("A tiny RSA example encrypts message \(rsa.message) as ciphertext \(rsa.ciphertext), using public exponent \(rsa.publicExponent). These factors recover a private exponent and decrypt it back to \(decoded).")
                            .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("c = mᵉ mod N    m = cᵈ mod N")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(InstrumentPalette.actionCyan)
                    }
                } else {
                    Text("Try again with the same circuit. This toy never fills in the answer from a precomputed order when a measurement fails.")
                        .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("\(attempts) measurement\(attempts == 1 ? "" : "s") in this experiment")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.secondaryInk)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var modelDisclosure: some View {
        DisclosureGroup("What this simulation assumes") {
            Text("An ideal, noiseless quantum circuit. Modular exponentiation and the inverse QFT are simulated numerically, then measurement is sampled. Classical recovery checks a continued-fraction candidate using arithmetic. The small numbers fit on your phone; factoring modern RSA keys requires vastly larger fault-tolerant machines.")
                .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
        }
        .font(.subheadline)
        .foregroundStyle(InstrumentPalette.displayInk)
        .tint(InstrumentPalette.actionCyan)
    }

    private func advance() {
        guard stage < 4 else { return }
        switch stage {
        case 0, 1:
            stage += 1
            QuantumFeedback.selection()
        case 2:
            measurement = experiment.measure(unitSample: Double.random(in: 0..<1))
            attempts += 1
            stage = 3
            QuantumFeedback.event()
        default:
            recovery = measurement.flatMap { experiment.postprocess(measurement: $0) }
            stage = 4
            QuantumFeedback.event(success: recovery != nil)
        }
    }

    private func runCircuit() {
        guard !isRunning, stage < 4 else { return }
        let generation = UUID()
        runGeneration = generation
        isRunning = true
        runTask = Task { @MainActor in
            while stage < 4 && !Task.isCancelled && runGeneration == generation {
                advance()
                if stage < 4 {
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 550))
                }
            }
            guard runGeneration == generation else { return }
            isRunning = false
            runTask = nil
        }
    }

    private func resetCircuit() {
        cancelRun()
        stage = 0
        measurement = nil
        recovery = nil
        attempts = 0
    }

    private func resetForModulus() {
        resetCircuit()
        experiment = ShorExperiment(modulus: modulus, base: 2)
        QuantumFeedback.selection()
    }

    private func cancelRun() {
        runGeneration = UUID()
        runTask?.cancel()
        runTask = nil
        isRunning = false
    }
}

private struct ShorPeriodRotor: View {
    let modulus: Int
    let base: Int
    let values: [Int]
    let isPrepared: Bool
    let factors: String?

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, 340)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 0.07, green: 0.095, blue: 0.11),
                                                  Color(red: 0.022, green: 0.034, blue: 0.043)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.7), radius: 18, y: 12)
                Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.035),
                                                               .black, .white.opacity(0.15)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                Circle().inset(by: 15).strokeBorder(.white.opacity(0.08), lineWidth: 1)
                Circle().inset(by: diameter * 0.22).strokeBorder(.white.opacity(0.07), lineWidth: 1)
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for index in 0..<64 {
                        let angle = Double(index) / 64 * .pi * 2 - .pi / 2
                        let inner = size.width * (index.isMultiple(of: 4) ? 0.455 : 0.465)
                        let outer = size.width * 0.48
                        var tick = Path()
                        tick.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                        tick.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                        context.stroke(tick, with: .color(.white.opacity(index.isMultiple(of: 4) ? 0.24 : 0.08)), lineWidth: 1)
                    }
                }.accessibilityHidden(true)
                ForEach(values.indices, id: \.self) { index in
                    let angle = Double(index) / Double(max(1, values.count)) * .pi * 2 - .pi / 2
                    let radius = diameter * 0.355
                    VStack(spacing: 2) {
                        Text(isPrepared ? "\(values[index])" : "\(index)")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(isPrepared && values[index] == 1 ? InstrumentPalette.actionAmber : InstrumentPalette.actionCyan)
                        Text(isPrepared ? "\(index)" : "x")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(InstrumentPalette.secondaryInk.opacity(0.8))
                    }
                    .position(x: diameter / 2 + cos(angle) * radius,
                              y: diameter / 2 + sin(angle) * radius)
                }
                VStack(spacing: 4) {
                    Text("N")
                        .font(.system(.caption, design: .monospaced)).tracking(3)
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                    Text("\(modulus)")
                        .font(.system(size: 64, weight: .light, design: .rounded)).monospacedDigit()
                        .foregroundStyle(InstrumentPalette.displayInk)
                    Text(factors ?? "\(base)ˣ mod \(modulus)")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(factors == nil ? InstrumentPalette.secondaryInk : InstrumentPalette.actionAmber)
                }
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 340)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPrepared ? "Modular power wheel" : "Prepared quantum register")
        .accessibilityValue(isPrepared ? "First powers of \(base) modulo \(modulus): \(values.map { String($0) }.joined(separator: ", ")). \(factors ?? "")" : "Equal superposition, number to factor \(modulus)")
    }
}
