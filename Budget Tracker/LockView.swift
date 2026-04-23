import SwiftUI
import LocalAuthentication

struct LockView: View {
    let onUnlocked: () -> Void

    @State private var failed = false
    @State private var animateLogo = false

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── App icon + name ───────────────────────────────────────
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [DS.blue, DS.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 88, height: 88)
                            .scaleEffect(animateLogo ? 1 : 0.85)
                            .opacity(animateLogo ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateLogo)

                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white)
                            .scaleEffect(animateLogo ? 1 : 0.85)
                            .opacity(animateLogo ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15), value: animateLogo)
                    }

                    VStack(spacing: 6) {
                        Text("Budget Tracker")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(DS.text)
                            .opacity(animateLogo ? 1 : 0)
                            .offset(y: animateLogo ? 0 : 8)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: animateLogo)

                        Text("Your financial overview")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.textSub)
                            .opacity(animateLogo ? 1 : 0)
                            .offset(y: animateLogo ? 0 : 6)
                            .animation(.easeOut(duration: 0.4).delay(0.25), value: animateLogo)
                    }
                }

                Spacer()

                // ── Unlock button ─────────────────────────────────────────
                VStack(spacing: 20) {
                    if failed {
                        Text("Authentication failed — try again")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.red)
                            .transition(.opacity)
                    }

                    Button { authenticate() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: biometricIcon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(biometricLabel)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(
                                    colors: [DS.blue, DS.purple],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(animateLogo ? 1 : 0)
                    .offset(y: animateLogo ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.35), value: animateLogo)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            animateLogo = true
            // Wait for the entrance animation to finish before triggering
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                authenticate()
            }
        }
    }

    // ── Biometric helpers ─────────────────────────────────────────────────
    private var biometricType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.fill"
        }
    }

    private var biometricLabel: String {
        switch biometricType {
        case .faceID:  return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        default:       return "Unlock with Passcode"
        }
    }

    private func authenticate() {
        failed = false
        let ctx = LAContext()
        var error: NSError?

        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }

        ctx.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock Budget Tracker"
        ) { success, authError in
            DispatchQueue.main.async {
                if success {
                    withAnimation(.easeIn(duration: 0.2)) { onUnlocked() }
                } else if let err = authError as? LAError {
                    switch err.code {
                    case .authenticationFailed:
                        // Wrong face / fingerprint — show the error
                        withAnimation { failed = true }
                    case .userFallback:
                        // User tapped "Enter Passcode" — system handles it, no error shown
                        break
                    default:
                        // userCancel, systemCancel, appCancel — silently wait,
                        // user can tap the button to try again
                        break
                    }
                }
            }
        }
    }
}
