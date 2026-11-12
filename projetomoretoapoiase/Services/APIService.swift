import Foundation

// MARK: - Erro Tipado da API REST NEXO
public struct APIError: LocalizedError {
    public let statusCode: Int
    public let message: String
    
    public var errorDescription: String? { message }
}

// MARK: - APIService (Comunicação REST Assíncrona com Injeção Automática de JWT e URL Dinâmica)
public final class APIService {
    public static let shared = APIService()
    
    public var baseURL: String {
        get { AppConfig.shared.apiBaseURL }
        set { AppConfig.shared.apiBaseURL = newValue }
    }
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }
    
    // Injeta cabeçalhos padrão e o Bearer Token JWT armazenado no Keychain
    private func buildRequest(endpoint: String, method: String) throws -> URLRequest {
        let cleanEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        guard let url = URL(string: "\(baseURL)/\(cleanEndpoint)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method == "POST" || method == "PUT" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = KeychainHelper.shared.currentJWTToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    // MARK: - Generic GET
    public func get<T: Decodable>(endpoint: String) async throws -> T {
        let request = try buildRequest(endpoint: endpoint, method: "GET")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Generic POST
    public func post<T: Decodable, B: Encodable>(endpoint: String, body: B) async throws -> T {
        var request = try buildRequest(endpoint: endpoint, method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Generic PUT
    public func put<T: Decodable, B: Encodable>(endpoint: String, body: B) async throws -> T {
        var request = try buildRequest(endpoint: endpoint, method: "PUT")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Generic DELETE
    public func delete(endpoint: String) async throws {
        let request = try buildRequest(endpoint: endpoint, method: "DELETE")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }
    
    // MARK: - Upload de Imagem para o Servidor (Retorna URL HTTP limpa)
    public func uploadImage(jpegData: Data) async throws -> String {
        struct UploadPayload: Encodable {
            let image_data: String
        }
        struct UploadResponse: Decodable {
            let url: String
        }
        let dataUri = "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
        let response: UploadResponse = try await post(endpoint: "uploads", body: UploadPayload(image_data: dataUri))
        return response.url
    }
    
    // MARK: - Validação HTTP e Extração de Mensagem de Erro do Backend
    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            struct ErrorBody: Decodable { let error: String }
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
                ?? "Erro no servidor (código \(httpResponse.statusCode))"
            throw APIError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}
