# Quantum Toy

A native SwiftUI, iPhone-only quantum computing instrument. Requires iOS 26 or later. All computation stays on the device as a classical educational simulation.

## Workbenches

- **Shor:** prepare an order-finding register, calculate modular exponentiation, inspect exact inverse-QFT measurement probabilities, sample a phase, recover a period with continued fractions and verify factors. Use recovered factors to decrypt a tiny textbook RSA message. Moduli 15, 21 and 35 keep the mathematics inspectable.
- **Grover:** change the register and marked answer, inspect signed amplitudes, apply the oracle and diffusion separately, and measure. Extra iterations demonstrate over-rotation rather than guaranteeing success.
- **Keys:** manipulate an elliptic-curve public key over F17 and recover its tiny scalar. Includes the September 21, 2026 16-bit ECC research result and primary source. The local key-search model explicitly uses classical enumeration; the referenced experiment used quantum annealing and classical processing.
- **Qubit Lab:** driven, damped Bloch evolution; live energy-gap, drive-detuning and Rabi-frequency controls; temperature, dephasing and readout noise; T1/T2, purity, coherence, probability traces and shot sampling. A thermal-excitation target defines a cold operating band instead of claiming a universal optimal temperature.

## Build

```sh
cd QuantumToy
xcodegen generate
xcodebuild -project QuantumToy.xcodeproj -scheme QuantumToy -destination 'generic/platform=iOS Simulator' build
swift test --scratch-path /tmp/quantum-toy-core-build
```

The Xcode project has an iPhone-only app, a QuantumCore framework and UI tests. The Swift package independently tests the platform-neutral core. Metro Station's edition 1.0 palette, background, panels, touch boundaries and native Liquid Glass establish the design foundation. The domain illustrations use native Canvas drawing.

Source provenance and scientific limits are in [Documentation/Research.md](Documentation/Research.md), and the app's Model Guide. T1, dephasing and the pulse-quality proxy use illustrative coefficients, not calibration data. Effective qubit temperature is distinct from a refrigerator sensor. No quantum hardware, decryption service or live telemetry is connected.

For Documents-directory file-coordination stalls, stage an identical source copy into a temporary build directory and compare its hashes before trusting the build. Build, simulator interaction and physical-device validation are separate evidence categories.


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
