import SwiftUI

// MARK: - Banner de Notificacao e Erro
struct StatusBannerView: View {
    let message: String
    var isError: Bool = false
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .foregroundColor(isError ? .vakinhaDanger : .vakinhaBlue)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.vakinhaBlack)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.vakinhaBlackMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isError ? Color.vakinhaDanger.opacity(0.12) : Color.vakinhaBlueLight)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 4)
    }
}
