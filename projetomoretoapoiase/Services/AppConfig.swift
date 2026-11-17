import Foundation

// MARK: - Configuração Dinâmica de Ambiente e Endpoint da API (Sem travar em localhost)
public final class AppConfig {
    public static let shared = AppConfig()
    
    private let customURLKey = "com.nexo.vakinha.custom_api_base_url"
    public let defaultSimulatorURL = "http://localhost:3000/api"
    
    private init() {}
    
    /// Resolve dinamicamente a URL da API na seguinte ordem de prioridade:
    /// 1. URL customizada pelo usuário/desenvolvedor na interface do app (salva no UserDefaults)
    /// 2. Variável de ambiente `NEXO_API_URL` injetada no Scheme do Xcode
    /// 3. Chave `API_BASE_URL` no Info.plist do Bundle
    /// 4. Fallback padrão (`http://localhost:3000/api`)
    public var apiBaseURL: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: customURLKey),
               !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return sanitize(saved)
            }
            if let envURL = ProcessInfo.processInfo.environment["NEXO_API_URL"],
               !envURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return sanitize(envURL)
            }
            if let plistURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
               !plistURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return sanitize(plistURL)
            }
            return defaultSimulatorURL
        }
        set {
            let cleaned = sanitize(newValue)
            if cleaned.isEmpty {
                UserDefaults.standard.removeObject(forKey: customURLKey)
            } else {
                UserDefaults.standard.set(cleaned, forKey: customURLKey)
            }
        }
    }
    
    /// Retorna a URL base raiz do servidor (ex: `http://192.168.1.10:3000`) para resolver caminhos relativos `/uploads/...`
    public var serverOriginURL: String {
        let base = apiBaseURL
        if base.hasSuffix("/api") {
            return String(base.dropLast(4))
        }
        return base
    }
    
    /// Converte qualquer caminho de imagem (absoluto ou relativo a `/uploads`) em uma `URL` válida para `AsyncImage`
    public func resolveImageURL(_ rawPath: String?) -> URL? {
        guard let raw = rawPath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        if raw.hasPrefix("/") {
            return URL(string: "\(serverOriginURL)\(raw)")
        }
        return URL(string: "\(serverOriginURL)/\(raw)")
    }
    
    public func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: customURLKey)
    }
    
    private func sanitize(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }
}
