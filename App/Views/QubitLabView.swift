import SwiftUI
import QuantumCore

struct QubitLabView: View {
    var isSelected: Bool = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var control = QubitControl()
    @State private var state = BlochState()
    @State private var running = false
    @State private var driveOn = true
    @State private var elapsed = 0.0
    @State private var history: [QubitSample] = []
    @State private var speed = 0.025
    @State private var samples = 0
    @State private var excitedCounts = 0
    @State private var shotExpectedP1 = 0.0

    private var telemetry: QubitTelemetry { QubitTelemetry(control: control) }
    private var live: Bool { running && isSelected && scenePhase == .active }
    private var coherent: Double { sqrt(state.x * state.x + state.y * state.y) }
    private var observedP1: Double {
        let e = control.readoutNoise
        return e + (1 - 2 * e) * state.excitedProbability
    }
    private var coldLimit: Double { telemetry.thermalLimitMK(targetPop: 0.001) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LabHeader(eyebrow: "04 / coherent control", title: "Keep a qubit alive.",
                          subtitle: "Tune the drive. Cool the model. Watch a state lose its quantum character.")
                BlochInstrument(state: state, purity: state.purity)
                    .frame(height: 285)
                HStack {
                    InstrumentMetricReadout("P(|1⟩)", value: percent(state.excitedProbability), unit: "%")
                    InstrumentMetricReadout("COHERENCE", value: percent(coherent), unit: "%", color: InstrumentPalette.spectrum)
                    InstrumentMetricReadout("TIME", value: String(format: "%.1f", elapsed), unit: "μs", color: InstrumentPalette.actionAmber)
                }
                GlassEffectContainer {
                    HStack(spacing: 12) {
                        LabAction(title: running ? "Pause" : "Run", symbol: running ? "pause.fill" : "play.fill", accent: InstrumentPalette.actionAmber) {
                            running.toggle(); QuantumFeedback.selection()
                        }.accessibilityIdentifier("qubitRun")
                        LabAction(title: "Reset", symbol: "arrow.counterclockwise") { reset() }
                            .accessibilityIdentifier("qubitReset")
                    }
                }
                InstrumentContentPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Microwave drive", systemImage: "waveform")
                                .font(.headline)
                            Spacer()
                            Toggle("Drive enabled", isOn: $driveOn).labelsHidden()
                        }
                        QuantumSlider(title: "QUBIT ENERGY GAP", value: $control.frequencyGHz,
                                      range: 3...8, step: 0.05,
                                      formatted: String(format: "%.2f GHz", control.frequencyGHz))
                        QuantumSlider(title: "DRIVE OFFSET Δ", value: $control.driveDetuningMHz,
                                      range: -5...5, step: 0.05,
                                      formatted: String(format: "%+.2f MHz", control.driveDetuningMHz), accent: InstrumentPalette.actionAmber)
                        QuantumSlider(title: "RABI FREQUENCY Ω / 2π", value: $control.rabiMHz,
                                      range: 0.1...3, step: 0.05,
                                      formatted: String(format: "%.2f MHz", control.rabiMHz))
                        Text(String(format: "DRIVE %.5f GHz • rotating-frame dynamics", control.frequencyGHz + control.driveDetuningMHz / 1000))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(InstrumentPalette.secondaryInk)
                        Picker("Simulation time per frame", selection: $speed) {
                            Text("Slow").tag(0.008)
                            Text("Medium").tag(0.025)
                            Text("Fast").tag(0.08)
                        }.pickerStyle(.segmented)
                        Text(String(format: "1 second ≈ %.2f μs in the model. Frequency edits preserve the current state.", speed * 30))
                            .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    }
                }
                InstrumentContentPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Thermal & noise bench", systemImage: "thermometer.snowflake").font(.headline)
                        QuantumSlider(title: "EFFECTIVE QUBIT TEMPERATURE", value: $control.temperatureMK,
                                      range: 5...180, step: 1,
                                      formatted: String(format: "%.0f mK", control.temperatureMK), accent: InstrumentPalette.actionAmber)
                            .accessibilityIdentifier("temperatureSlider")
                        QuantumSlider(title: "DEPHASING NOISE", value: $control.dephasingNoise,
                                      range: 0...1, step: 0.01, formatted: percent(control.dephasingNoise) + " %", accent: InstrumentPalette.spectrum)
                        QuantumSlider(title: "READOUT FLIP PROBABILITY", value: $control.readoutNoise,
                                      range: 0...0.2, step: 0.005, formatted: percent(control.readoutNoise) + " %")
                        HStack {
                            InstrumentMetricReadout("T₁", value: String(format: "%.1f", telemetry.t1Microseconds), unit: "μs")
                            InstrumentMetricReadout("T₂", value: String(format: "%.1f", telemetry.t2Microseconds), unit: "μs", color: InstrumentPalette.spectrum)
                            InstrumentMetricReadout("THERMAL P₁", value: thermalPercent(telemetry.thermalExcitedPopulation), unit: "%", color: InstrumentPalette.actionAmber)
                        }
                        Text("T₁ and T₂ are illustrative model telemetry. Thermal population follows the two-level equilibrium equation.")
                            .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    }
                }
                coldBand
                InstrumentContentPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("LIVE STATE TRACE").font(.system(.caption, design: .monospaced)).tracking(1)
                            Spacer()
                            Text(live ? "SIMULATING" : "PAUSED").foregroundStyle(live ? InstrumentPalette.actionAmber : InstrumentPalette.secondaryInk)
                                .font(.system(.caption2, design: .monospaced))
                        }
                        QubitTrace(samples: history).frame(height: 140)
                        HStack(spacing: 18) {
                            traceLegend("P(|1⟩)", InstrumentPalette.actionCyan)
                            traceLegend("Coherence", InstrumentPalette.spectrum)
                            traceLegend("Readout P₁", InstrumentPalette.actionAmber)
                        }
                        Text(String(format: "Window %.1f simulated μs • vertical scale 0–1", speed * 100))
                            .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    }
                }
                preparePanel
                LabNote(title: "A driven, open quantum system",
                        text: "The vector rotates around the microwave field and shrinks as relaxation and dephasing erase information. Detuning tips its rotation axis. Noise is represented by ensemble damping, not a measured device signal. A pure state lies on the sphere; a mixed state lies inside.",
                        equation: "H/ℏ = (Ωσₓ + Δσ𝓏)/2\n1/T₂ = 1/(2T₁) + 1/Tφ")
                Text("LOCAL CLASSICAL SIMULATION • NO HARDWARE TELEMETRY")
                    .font(.system(.caption2, design: .monospaced)).tracking(1)
                    .foregroundStyle(InstrumentPalette.secondaryInk)
            }.padding(20).padding(.bottom, 20)
        }
        .task(id: live) {
            guard live else { return }
            while !Task.isCancelled {
                tick()
                do { try await Task.sleep(for: .milliseconds(33)) }
                catch { break }
            }
        }
        .onChange(of: speed) { _, _ in history = [] }
    }

    private var coldBand: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Find a cold operating band").font(.headline)
                HStack(alignment: .firstTextBaseline) {
                    Text("≤ \(String(format: "%.1f", coldLimit))")
                        .font(.system(.largeTitle, design: .rounded, weight: .light)).monospacedDigit()
                        .foregroundStyle(InstrumentPalette.actionCyan)
                    Text("mK").font(.system(.callout, design: .monospaced))
                    Spacer()
                    Image(systemName: control.temperatureMK <= coldLimit ? "checkmark.circle" : "thermometer.medium")
                        .foregroundStyle(InstrumentPalette.actionAmber).font(.title2)
                }
                ThermalCurve(frequencyGHz: control.frequencyGHz, temperatureMK: control.temperatureMK,
                             limitMK: coldLimit).frame(height: 96)
                Text("For ideal equilibrium P₁ ≤ 0.1% at \(String(format: "%.2f", control.frequencyGHz)) GHz. Cooling below this band reduces thermal excitation; real devices can retain residual excitation and have other noise limits.")
                    .font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
                LabAction(title: "Set 20 mK & match resonance", symbol: "scope") {
                    control.temperatureMK = 20
                    control.driveDetuningMHz = 0
                    QuantumFeedback.selection()
                }.accessibilityIdentifier("coldTune")
                Text("P₁ = 1 / (1 + exp(hf / kᴮT))")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(InstrumentPalette.actionCyan)
                Text("This target defines a useful model band. It is not a universal optimum, and microwave tuning does not cool a refrigerator.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
            }
        }
    }

    private var preparePanel: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Prepare & measure").font(.headline)
                GlassEffectContainer {
                    HStack(spacing: 8) {
                        LabAction(title: "|0⟩", symbol: "arrow.up") { prepare(BlochState()) }
                        LabAction(title: "|+⟩", symbol: "arrow.right") { prepare(BlochState(x: 1, y: 0, z: 0)) }
                        LabAction(title: "|1⟩", symbol: "arrow.down") { prepare(BlochState(x: 0, y: 0, z: -1)) }
                    }
                }
                Text("For a Ramsey-like decay: prepare |+⟩, turn the drive off, and raise dephasing. For thermal relaxation: prepare |0⟩, turn the drive off, and warm the qubit.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                LabAction(title: "Sample 100 shots", symbol: "chart.bar.xaxis") {
                    shotExpectedP1 = observedP1
                    excitedCounts = (0..<100).reduce(0) { sum, _ in sum + (Double.random(in: 0..<1) < observedP1 ? 1 : 0) }
                    samples = 100; QuantumFeedback.event()
                }
                if samples > 0 {
                    Text("\(excitedCounts) / \(samples) excited • expected at sampling \(percent(shotExpectedP1))%")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(InstrumentPalette.actionAmber)
                }
                Text("Shots sample independent copies of the current state with readout flips; the live state is preserved.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
            }
        }
    }

    private func tick() {
        var effective = control
        if !driveOn { effective.rabiMHz = 0 }
        state.advance(control: effective, deltaMicroseconds: speed)
        elapsed += speed
        history.append(QubitSample(p1: state.excitedProbability, coherence: coherent, readout: observedP1))
        if history.count > 100 { history.removeFirst(history.count - 100) }
    }
    private func reset() {
        running = false; state = BlochState(); elapsed = 0; history = []; samples = 0
        QuantumFeedback.selection()
    }
    private func prepare(_ newState: BlochState) {
        state = newState; elapsed = 0; history = []; samples = 0; QuantumFeedback.selection()
    }
    private func percent(_ x: Double) -> String { String(format: "%.1f", x * 100) }
    private func thermalPercent(_ x: Double) -> String {
        String(format: x < 0.001 ? "%.4f" : "%.2f", x * 100)
    }
    private func traceLegend(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.caption2).foregroundStyle(InstrumentPalette.secondaryInk)
        }
    }
}

private struct QubitSample {
    let p1: Double
    let coherence: Double
    let readout: Double
}

private struct QubitTrace: View {
    let samples: [QubitSample]
    var body: some View {
        Canvas { context, size in
            for i in 0...4 {
                let y = CGFloat(i) * size.height / 4
                var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(.white.opacity(0.07)), lineWidth: 0.5)
            }
            let channels: [(KeyPath<QubitSample, Double>, Color)] = [
                (\.p1, InstrumentPalette.actionCyan), (\.coherence, InstrumentPalette.spectrum), (\.readout, InstrumentPalette.actionAmber)
            ]
            for (key, color) in channels {
                var path = Path()
                for (i, sample) in samples.enumerated() {
                    let p = CGPoint(x: size.width * CGFloat(i) / 99,
                                    y: size.height * (1 - sample[keyPath: key]))
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                context.stroke(path, with: .color(color), lineWidth: 1.5)
            }
        }.accessibilityLabel("Live trace of excited-state probability, coherence, and readout probability")
    }
}

private struct ThermalCurve: View {
    let frequencyGHz: Double
    let temperatureMK: Double
    let limitMK: Double
    var body: some View {
        Canvas { context, size in
            func point(_ t: Double) -> CGPoint {
                let pop = 1 / (1 + exp(47.9924 * frequencyGHz / max(t, 0.001)))
                return CGPoint(x: (t - 5) / 175 * size.width, y: size.height * (1 - min(1, pop / 0.5)))
            }
            let band = CGRect(x: 0, y: 0, width: max(0, min(size.width, (limitMK - 5) / 175 * size.width)), height: size.height)
            context.fill(Path(band), with: .color(InstrumentPalette.actionCyan.opacity(0.06)))
            var path = Path()
            for t in 5...180 {
                if t == 5 { path.move(to: point(Double(t))) } else { path.addLine(to: point(Double(t))) }
            }
            context.stroke(path, with: .color(InstrumentPalette.actionAmber), lineWidth: 1.5)
            let p = point(temperatureMK)
            context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(InstrumentPalette.actionCyan))
            context.draw(Text("5 mK").font(.system(size: 9, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk), at: CGPoint(x: 20, y: 10))
            context.draw(Text("180 mK / 50%").font(.system(size: 9, design: .monospaced)).foregroundStyle(InstrumentPalette.secondaryInk), at: CGPoint(x: size.width - 57, y: 10))
        }.accessibilityLabel("Thermal excited-state population rises as temperature rises. Shaded band meets 0.1 percent target.")
    }
}

private struct BlochInstrument: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let state: BlochState
    let purity: Double
    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(red: 0.11, green: 0.15, blue: 0.17), InstrumentPalette.canvas, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { Circle().stroke(.white.opacity(0.13), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.6), radius: 15, y: 10)
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = d * 0.36
                    func project(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
                        CGPoint(x: center.x + r * (x * 0.88 + y * 0.48),
                                y: center.y - r * (z * 0.88 + y * 0.30))
                    }
                    for i in 0..<60 {
                        let a = Double(i) / 60 * 2 * Double.pi
                        let outer = d * 0.47
                        let inner = outer - (i % 5 == 0 ? 9 : 4)
                        var tick = Path()
                        tick.move(to: CGPoint(x: center.x + inner * cos(a), y: center.y + inner * sin(a)))
                        tick.addLine(to: CGPoint(x: center.x + outer * cos(a), y: center.y + outer * sin(a)))
                        context.stroke(tick, with: .color(.white.opacity(i % 5 == 0 ? 0.25 : 0.12)), lineWidth: 1)
                    }
                    for plane in 0..<3 {
                        var ring = Path()
                        for i in 0...120 {
                            let a = Double(i) / 120 * 2 * Double.pi
                            let p: CGPoint
                            if plane == 0 { p = project(cos(a), sin(a), 0) }
                            else if plane == 1 { p = project(cos(a), 0, sin(a)) }
                            else { p = project(0, cos(a), sin(a)) }
                            if i == 0 { ring.move(to: p) } else { ring.addLine(to: p) }
                        }
                        context.stroke(ring, with: .color(InstrumentPalette.actionCyan.opacity(plane == 0 ? 0.32 : 0.13)), lineWidth: 1)
                    }
                    var axis = Path(); axis.move(to: project(0, 0, -1)); axis.addLine(to: project(0, 0, 1))
                    context.stroke(axis, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    let head = project(state.x, state.y, state.z)
                    var vector = Path(); vector.move(to: center); vector.addLine(to: head)
                    context.stroke(vector, with: .color(InstrumentPalette.actionAmber), lineWidth: 2.5)
                    context.fill(Path(ellipseIn: CGRect(x: head.x - 4, y: head.y - 4, width: 8, height: 8)), with: .color(InstrumentPalette.actionAmber))
                    context.draw(Text("|0⟩").font(.system(size: 12, design: .monospaced)).foregroundStyle(InstrumentPalette.actionCyan), at: project(0, 0, 1.14))
                    context.draw(Text("|1⟩").font(.system(size: 12, design: .monospaced)).foregroundStyle(InstrumentPalette.spectrum), at: project(0, 0, -1.14))
                }
                if !reduceTransparency {
                    Color.clear.frame(width: d * 0.77, height: d * 0.77).glassEffect(.clear, in: .circle)
                        .opacity(0.35).allowsHitTesting(false)
                }
                VStack {
                    Spacer()
                    Text(String(format: "PURITY %.3f", purity))
                        .font(.system(.caption2, design: .monospaced)).monospacedDigit()
                        .foregroundStyle(InstrumentPalette.secondaryInk).padding(.bottom, d * 0.14)
                }
            }.frame(width: d, height: d).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bloch sphere")
        .accessibilityValue(String(format: "x %.2f, y %.2f, z %.2f, purity %.3f", state.x, state.y, state.z, purity))
    }
}
