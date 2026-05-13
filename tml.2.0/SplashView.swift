//
//  SplashView.swift
//  tml.2.0
//
//  Created by mike on 5/13/26.
//


import SwiftUI

struct SplashView: View {

    @State private var pulse = false
    @State private var glow = false

    var body: some View {

        ZStack {

            // MARK: Background

            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.07, green: 0.07, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {

                // MARK: Logo + Pulse Animation

                ZStack {

                    // Outer Pulse Ring

                    Circle()
                        .stroke(
                            Color.white.opacity(0.35),
                            lineWidth: 3
                        )
                        .frame(width: 220, height: 220)
                        .scaleEffect(pulse ? 1.35 : 0.75)
                        .opacity(pulse ? 0 : 1)

                    // Secondary Pulse Ring

                    Circle()
                        .stroke(
                            Color.white.opacity(0.20),
                            lineWidth: 2
                        )
                        .frame(width: 220, height: 220)
                        .scaleEffect(pulse ? 1.15 : 0.9)
                        .opacity(pulse ? 0 : 0.7)

                    // Static Ring

                    Circle()
                        .stroke(
                            Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                        .frame(width: 190, height: 190)

                    // Glow Effect

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(glow ? 0.22 : 0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 120
                            )
                        )
                        .frame(width: 220, height: 220)

                    // Logo

                    Image("checkmark")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.white.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: .white.opacity(0.18),
                            radius: 18
                        )
                }
                .frame(height: 260)

                // MARK: Title

                VStack(spacing: 10) {

                    Text("Line Check")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Operations & Shift Readiness")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }

                // MARK: Loading Indicator

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.05)
                    .padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
        .onAppear {

            // Pulse Animation

            withAnimation(
                .easeOut(duration: 2)
                .repeatForever(autoreverses: false)
            ) {
                pulse = true
            }

            // Glow Animation

            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                glow.toggle()
            }
        }
    }
}

#Preview {
    SplashView()
}
