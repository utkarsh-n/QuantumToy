import SwiftUI

struct QuantumGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LabHeader(eyebrow: "Inside the toy", title: "Watch the mathematics.",
                              subtitle: "Every experiment runs locally on your iPhone. Small quantum models make amplitudes, interference, and stability visible.")
                    LabNote(title: "What is being simulated?",
                            text: "Quantum Toy uses classical computation to simulate small quantum systems. Shor and Grover show calculated probabilities; the key lab uses a miniature elliptic curve. The cryostat is a synthetic laboratory with an illustrative superconducting-qubit model.")
                    shorGuide
                    groverGuide
                    keyGuide
                    cryostatGuide
                    sources
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(InstrumentDesignBackground())
            .navigationTitle("Field guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                        .tint(InstrumentPalette.actionCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var shorGuide: some View {
        LabNote(title: "Shor · find a repeating pattern",
                text: "Repeated modular multiplication creates a period. Quantum interference and the Fourier transform concentrate probability near values that reveal that period. Classical continued fractions propose an order; modular arithmetic checks it. An even order can reveal the factors through two greatest-common-divisor calculations. Some measurements and bases need another attempt.\n\nThe app then derives a miniature RSA private exponent and decrypts a toy message. The small, unpadded example exposes the mechanics and does not represent production RSA security.",
                equation: "aʳ ≡ 1 (mod N)\ngcd(aʳ⁄² ± 1, N) → factors\nm = cᵈ mod N")
    }

    private var groverGuide: some View {
        LabNote(title: "Grover · amplify the marked state",
                text: "Start with equal amplitudes. The oracle changes the sign of the marked amplitude; diffusion reflects all amplitudes about their mean. Together they rotate probability toward the answer. Keep iterating past the best point and that probability falls again.\n\nFor one marked item, the ideal query count grows roughly with the square root of the search space. Building a real oracle also costs work. The toy's marked answer is a controlled teaching example.",
                equation: "aᵢ ← 2 mean(a) − aᵢ\nP(k) = sin²((2k + 1)θ)\nθ = asin(√(M/N))")
    }

    private var keyGuide: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("ECC · a small secret makes a public point")
                    .font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                Text("Q = kG    ·    y² ≡ x³ + 2x + 2 (mod 17)")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(InstrumentPalette.actionCyan)
                    .textSelection(.enabled)
                guideText("The key lab adds a generator point G to itself k times. It recovers k by testing the tiny set of candidates. This is a classical model of the discrete logarithm relationship, with 19 group elements including infinity.")
                guideText("On September 21, 2026, researchers reported a 16-bit elliptic-curve discrete-log demonstration on D-Wave Advantage2. Their experiment combined quantum annealing and classical index calculus. Our toy illustrates the mathematical target; it does not reproduce their annealing method or show a production 256-bit key break.")
                guideText("Shor can also address discrete logarithms on a sufficiently capable fault-tolerant quantum computer. A March 2026 Google Quantum AI paper estimates future resources for 256-bit ECC; those estimates describe proposed hardware, rather than an observed key recovery.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cryostatGuide: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cryostat · separate cooling from control")
                    .font(.headline).foregroundStyle(InstrumentPalette.displayInk)
                guideText("A superconducting qubit has an energy gap hf. At thermal equilibrium, higher temperature makes unwanted excitation more likely. The temperature that matters in this equation is the qubit's effective temperature; a refrigerator's sensor reading may differ.")
                equation("P₁ = 1 / (1 + exp(hf / kᴮT))\nhf/kᴮ = 47.9924 mK × f in GHz")
                guideText("At 5 GHz, the ideal equation predicts about 0.000615% excitation at 20 mK and 0.817% at 50 mK. This toy uses that ideal equation without a residual-excitation floor. In one real experiment, excitation remained around 0.1% below 35 mK; cooling alone therefore does not guarantee perfect initialization.")
                guideText("T₁ is the energy-relaxation time. T₂ is the coherence time. Pure dephasing adds phase uncertainty, so this simple Markovian model obeys:")
                equation("1/T₂ = 1/(2T₁) + 1/Tφ\nT₂ ≤ 2T₁")
                guideText("Microwave drive amplitude sets the rotation rate. Detuning is the difference between drive and qubit frequency; it changes the rotation axis and can spoil a calibrated pulse. These controls do not cool the refrigerator.")
                guideText("Temperature sets an illustrative T₁ response. Dephasing noise independently shortens Tφ and therefore T₂, without changing T₁. Readout noise is a separate probability of flipping a measured bit; it changes the observed counts without changing the simulated qubit state. These coefficients are not calibrated to a specific processor. The displayed telemetry is simulated.")
                guideText("The cold operating band is the ideal temperature ceiling for a chosen thermal-excitation target. It is not a universal optimum for real hardware. This toy's T₁ response stops improving below 20 mK, while its ideal thermal population keeps decreasing.")
                guideText("The two-level model omits correlated multi-qubit noise, higher-level leakage, and error correction. Scientific time can be slowed on screen to make the dynamics legible.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sources: some View {
        InstrumentContentPanel {
            VStack(alignment: .leading, spacing: 3) {
                Text("Original sources").font(.headline)
                    .foregroundStyle(InstrumentPalette.displayInk)
                    .padding(.bottom, 8)
                source("Shor · factoring and discrete logarithms", detail: "Primary paper · 1995 / 1996",
                       url: "https://arxiv.org/abs/quant-ph/9508027")
                source("Grover · quantum search", detail: "Primary paper · 1996",
                       url: "https://arxiv.org/abs/quant-ph/9605043")
                source("16-bit elliptic-curve experiment", detail: "Lin et al. · September 21, 2026",
                       url: "https://www.sciopen.com/article/10.23919/ICN.2026.0017")
                source("Future 256-bit ECC resource estimates", detail: "Google Quantum AI et al. · March 2026",
                       url: "https://arxiv.org/abs/2603.28846")
                source("Thermal and residual qubit excitation", detail: "Jin et al. · Physical Review Letters, 2015",
                       url: "https://arxiv.org/abs/1412.2772")
                source("Qubit characterization and telemetry", detail: "Hashim et al. · characterization tutorial",
                       url: "https://arxiv.org/abs/2408.12064")
                source("T₁ / T₂ relaxation model", detail: "IBM Quantum · noise-model documentation",
                       url: "https://quantum.cloud.ibm.com/docs/en/guides/build-noise-models")
                Text("Research checked October 12, 2026.")
                    .font(.caption).foregroundStyle(InstrumentPalette.secondaryInk)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func guideText(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(InstrumentPalette.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func equation(_ text: String) -> some View {
        Text(text).font(.system(.callout, design: .monospaced))
            .foregroundStyle(InstrumentPalette.actionCyan)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func source(_ title: String, detail: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline)
                        .foregroundStyle(InstrumentPalette.actionCyan)
                    Text(detail).font(.caption)
                        .foregroundStyle(InstrumentPalette.secondaryInk)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right").font(.caption)
                    .foregroundStyle(InstrumentPalette.secondaryInk)
            }
            .frame(minHeight: 54)
            .contentShape(.rect)
        }
    }
}
