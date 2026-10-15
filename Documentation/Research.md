# Quantum Toy research and scientific scope

Research checked against primary sources on October 12, 2026. All computation in the iPhone app runs as a classical simulation. It is an educational instrument, with deliberately small keys and explicitly synthetic laboratory telemetry.

## Recent cryptanalysis context

**Selected recent experiment — September 21, 2026.** Lin et al. report a 16-bit prime-field elliptic-curve discrete-log demonstration on D-Wave Advantage2, using quantum annealing combined with classical index calculus. This is a small research instance of ECC's underlying mathematical problem, rather than the recovery of a production 256-bit ECC key. Annealing and Shor's gate-model algorithm are different methods. The app can connect their shared mathematical target while keeping the methods distinct. [Primary journal article](https://www.sciopen.com/article/10.23919/ICN.2026.0017), DOI 10.23919/ICN.2026.0017.

Suggested app copy: “September 2026: researchers reported solving a 16-bit elliptic-curve problem with a D-Wave annealer. Try a miniature key-recovery model, then explore how Shor's algorithm uses interference.”

**Related resource estimate — March 30, 2026; revised April 15.** Google Quantum AI and collaborators estimate future hardware requirements for 256-bit ECC: alternative circuits use fewer than 1,200 logical qubits and 90 million Toffoli gates, or fewer than 1,450 logical qubits and 70 million Toffoli gates. Their superconducting-machine estimate assumes physical error rates of 0.1% and planar connectivity, with fewer than 500,000 physical qubits and a runtime measured in minutes. These are engineering estimates under stated assumptions, not an observed production-key break. [Primary paper](https://arxiv.org/abs/2603.28846), [authors' March 31 explanation](https://research.google/blog/safeguarding-cryptocurrency-by-disclosing-quantum-vulnerabilities-responsibly/).

**Another recent result — October 2026 journal issue.** Lee et al. encode one stage of a prior attack on the legacy satellite cipher A5-GMR-2 as a 2,048-variable QUBO and solve it with a D-Wave hybrid solver. Classical preprocessing handles the nonlinear structure. Their comparison finds the residual problem easy for classical methods too; the authors claim neither quantum speedup nor a practical cryptographic break. [Primary paper](https://www.sciencedirect.com/science/article/pii/S1877750326002073), DOI 10.1016/j.jocs.2026.102989. The article's accessible metadata specifies its issue month, rather than a verified exact publication day.

Use “toy key recovery,” “simulated textbook RSA decryption,” or “resource estimate.” Avoid presenting any of these as a recent break of production RSA-2048, AES, Bitcoin wallets, or arbitrary encrypted files. ECC signatures and key agreement are also distinct from message encryption.

## Shor / textbook RSA laboratory

Shor's algorithm turns integer factorization into quantum order finding. For a coprime base a and modulus N, the order r is the smallest positive integer with a^r mod N = 1. A quantum Fourier transform exposes periodicity in measurement probabilities. Continued fractions and classical verification recover a candidate r. When r is even and a^(r/2) is not −1 modulo N, gcd(a^(r/2)±1, N) gives nontrivial factors. Some bases and measurements fail; show retry behavior.

The RSA teaching example derives φ(N)=(p−1)(q−1), finds d=e⁻¹ mod φ(N), and recovers message m=c^d mod N. Small moduli and unpadded textbook RSA intentionally expose the mechanics; they represent neither production security nor a real hardware execution. The simulator should calculate its probability distribution, rather than animate a predetermined success. [Shor's primary paper](https://arxiv.org/abs/quant-ph/9508027).

## Grover laboratory

For N candidate states and M marked states, start with uniform amplitudes. The oracle changes the sign of marked amplitudes. Diffusion reflects every amplitude about the mean: a_i ← 2 mean(a) − a_i. With θ=asin(sqrt(M/N)), the ideal marked-state probability after k complete iterations is sin²((2k+1)θ). Overshooting the first maximum makes success decrease again. Query complexity is O(sqrt(N/M)); preparing the state and implementing the oracle also cost work. An oracle that marks a known toy answer is a teaching device, not a demonstrated cipher attack. [Grover's primary paper](https://arxiv.org/abs/quant-ph/9605043).

## Cryostat / qubit stability laboratory

For an ideal two-level qubit in equilibrium, with transition frequency f in Hz and effective qubit temperature T in kelvin:

```text
E_gap = h f
p_excited = 1 / (1 + exp(h f / (k_B T)))
z_equilibrium = 1 − 2 p_excited
h = 6.62607015 × 10⁻³⁴ J s
k_B = 1.380649 × 10⁻²³ J K⁻¹
E_gap / k_B = 47.9924 mK × f_GHz
```

For a 5 GHz qubit, this equation predicts approximately 0.000615% thermal excitation at 20 mK, 0.817% at 50 mK, and 8.32% at 100 mK. These are mathematical checks of this model. Real qubits need not thermalize to the refrigerator's sensor temperature: Jin et al.'s particular transmon experiment found residual excitation around 0.1% below 35 mK. A residual floor or a distinct effective temperature is therefore appropriate, labeled as a toy setting. [Jin et al., primary paper](https://arxiv.org/abs/1412.2772).

T1 describes energy relaxation; T2 describes loss of phase coherence. Under the simple Markovian relaxation/dephasing model:

```text
1/T2 = 1/(2 T1) + 1/Tphi
therefore T2 ≤ 2 T1
```

Use the same time unit for pulse durations and coherence times. Preserve this bound when temperature, noise, or user controls change. IBM's documented thermal-relaxation channel enforces it and includes equilibrium excited-state population as a separate parameter. [IBM Quantum noise-model documentation](https://quantum.cloud.ibm.com/docs/en/guides/build-noise-models).

In a chosen rotating-frame convention, a driven two-level model may evolve a Bloch vector r=(x,y,z) with effective angular-frequency vector ω=(Ω,0,Δ):

```text
dr/dt = ω × r − (x/T2, y/T2, (z−z_equilibrium)/T1)
Ω = 2π × Rabi_frequency_Hz
Δ = 2π × detuning_Hz
P(|1>) = (1−z)/2
purity = (1+|r|²)/2
fidelity to a pure target r_target = (1+r·r_target)/2
```

Define the detuning sign consistently with the Hamiltonian and plot legend. Microwave drive modulation changes the rotation speed and axis, while detuning reduces a resonant pulse's transfer efficiency. Laboratory characterization includes Rabi oscillations, Ramsey detuning, T1 decay, and dephasing. [Primary characterization tutorial](https://arxiv.org/abs/2408.12064), [primary superconducting-qubit noise spectroscopy experiment](https://arxiv.org/abs/1101.4707).

## Limits that should remain visible in the app

- All temperature, vibration, magnetic-noise, power, and coherence telemetry is synthesized from an educational model; no sensor or quantum computer is connected.
- The Bloch model represents one two-level qubit with Markovian damping. It omits multilevel leakage, correlated noise, device calibration, realistic microwave electronics, and error correction unless separately implemented.
- Any chosen relationship between temperature and T1/Tphi, heat load, vibration, or control error is an illustrative model assumption. Its numerical coefficients are not a fit to a particular processor.
- “Optimal temperature” means the best value for the displayed toy objective and current assumptions. Thermal excitation decreases as temperature falls; real machines also face residual excitation, heat flow, noise, cooling power, and architecture-specific constraints. There is no universal optimum temperature for all quantum computers.
- A sensible thermal objective is a specified maximum equilibrium excitation. Solve its threshold explicitly: T_max = h f / [k_B ln((1−p_target)/p_target)]. For f=5 GHz and p_target=0.001, T_max≈34.74 mK. A nonthermal residual floor above the target makes that target unattainable by cooling alone.
- Drive frequency matching does not cool a dilution refrigerator. Show cryostat control and microwave modulation as related but distinct controls.
- Animation time may be slowed for visibility. Display the scientific elapsed time and scale whenever they differ from wall-clock seconds.
