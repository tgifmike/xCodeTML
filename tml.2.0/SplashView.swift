import SwiftUI

struct SplashView: View {
    @State private var logoScale = 0.94
    @State private var logoOpacity = 0.0
    @State private var progressOpacity = 0.0

    var body: some View {
        ZStack {
            background

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                Image("new_tml_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 34)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 10)

                VStack(spacing: 10) {
                    Text("Operations & Readiness")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Line Check")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .opacity(progressOpacity)

                ProgressView()
                    .tint(.blue)
                    .scaleEffect(1.05)
                    .opacity(progressOpacity)
                    .padding(.top, 4)

                Spacer(minLength: 70)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.86)) {
                logoScale = 1
                logoOpacity = 1
            }

            withAnimation(.easeIn(duration: 0.35).delay(0.25)) {
                progressOpacity = 1
            }
        }
    }

    private var background: some View {
        ZStack {
            Color(.systemBackground)

            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.08),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashView()
}
