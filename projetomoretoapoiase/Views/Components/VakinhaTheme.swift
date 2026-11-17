import SwiftUI

// MARK: - Sistema de Cores Apple HIG: 60% Branco, 30% Azul, 10% Preto
public extension Color {
    // 60% Dominante - Base Limpa & Superfícies (Branco / Tons Claros)
    static let vakinhaBackground = Color(.systemGroupedBackground)
    static let vakinhaCardBg = Color(.secondarySystemGroupedBackground)
    
    // 30% Estrutura & Destaque - Azul Apple Vibrante
    static let vakinhaBlue = Color(red: 0.0, green: 0.48, blue: 1.0) // Apple System Blue (#007AFF)
    static let vakinhaBlueLight = Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.12)
    static let vakinhaBlueDark = Color(red: 0.0, green: 0.35, blue: 0.8)
    
    // 10% Contraste & Tipografia - Preto Apple Profundo
    static let vakinhaBlack = Color(.label)
    static let vakinhaBlackMuted = Color(.secondaryLabel)
    
    // Acentos Auxiliares
    static let vakinhaSuccess = Color(red: 0.15, green: 0.68, blue: 0.38)
    static let vakinhaDanger = Color(red: 0.95, green: 0.26, blue: 0.21)
}

public struct VakinhaPrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isDestructive ? Color.vakinhaDanger : Color.vakinhaBlue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .shadow(color: isDestructive ? Color.vakinhaDanger.opacity(0.25) : Color.vakinhaBlue.opacity(0.3), radius: 6, y: 3)
    }
}

public struct VakinhaSecondaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.vakinhaBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.vakinhaBlueLight)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

