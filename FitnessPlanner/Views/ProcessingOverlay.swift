import SwiftUI

struct ProcessingOverlay: ViewModifier {
    let isActive: Bool
    let message: String

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isActive)
            .overlay {
                if isActive {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView()
                                .controlSize(.large)
                            Text(message)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isActive)
    }
}

extension View {
    func processingOverlay(isActive: Bool, message: String) -> some View {
        modifier(ProcessingOverlay(isActive: isActive, message: message))
    }
}
