import SwiftUI

struct SplashScreenView: View {
    @Binding var isActive: Bool
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Gradient background (Uber-inspired)
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.05),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Logo icon (using SF Symbol as placeholder)
                Image(systemName: "person.2.badge.gearshape.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accentColor, Theme.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // App name
                Text("Konektly")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Tagline
                Text("On-Demand Staffing")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(2.0))
                withAnimation(.easeInOut(duration: 0.4)) {
                    isActive = false
                }
            }
        }
    }
}

#Preview {
    SplashScreenView(isActive: .constant(true))
}
