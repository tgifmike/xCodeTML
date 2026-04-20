//
//  CustomAlertView.swift
//  tml.2.0
//
//  Created by mike on 4/20/26.
//

import SwiftUI

struct CustomAlertView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let onDismiss: () -> Void
    
    @State private var animateIn = false
    @State private var didTriggerHaptics = false

    var body: some View {
            ZStack {

                // MARK: Background (system-style blur)
                VisualEffectBlur(style: .systemMaterialDark)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // optional: dismiss on outside tap
                        triggerDismiss()
                    }

                // MARK: Alert Card
                VStack(spacing: 14) {

                    Text(title)
                        .font(.title2)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.red)

                    Divider()


                    
                    Button(action: {
                        triggerDismiss()
                    }) {
                        Text(buttonTitle)
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                }
                .padding(18)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
                .scaleEffect(animateIn ? 1.0 : 0.85)
                .opacity(animateIn ? 1 : 0)
            }
            .transition(.scale.combined(with: .opacity))
            .onAppear {
                animateIn = true
                triggerHapticsAndSoundOnce()
            }
        }

        // MARK: - Dismiss Logic
        private func triggerDismiss() {
            triggerTapHaptic()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                animateIn = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onDismiss()
            }
        }

        // MARK: - Haptics + Sound

        private func triggerHapticsAndSoundOnce() {
            guard !didTriggerHaptics else { return }
            didTriggerHaptics = true

            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)

//            AudioServicesPlaySystemSound(1521) // subtle "pop" system sound
        }

        private func triggerTapHaptic() {
            let haptic = UIImpactFeedbackGenerator(style: .light)
            haptic.impactOccurred()
        }
    }

struct VisualEffectBlur: UIViewRepresentable {

    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
