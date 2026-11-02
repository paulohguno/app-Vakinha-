import Foundation
import Combine
import SwiftUI
import CoreLocation

// MARK: - ViewModel Central do Aplicativo Vakinha
@MainActor
public class NexoViewModel: ObservableObject {
    public static let shared = NexoViewModel()
    
    // Autenticação & Sessão Persistente
    @Published public var currentUser: AppUser?
    @Published public var isAuthenticated: Bool = false
    @Published public var availableUsers: [AppUser] = []
    
    // Entidades dos 10 CRUDs puxadas do PostgreSQL (vakinhadb)
    @Published public var campaigns: [CampaignItem] = []
    @Published public var categories: [CategoryItem] = []
    @Published public var donations: [DonationItem] = []
    @Published public var updates: [CampaignUpdateItem] = []
    @Published public var messages: [WallMessageItem] = []
    @Published public var reports: [ReportItem] = []
    @Published public var verifications: [NGOVerificationItem] = []
    @Published public var favorites: [FavoriteItem] = []
    @Published public var withdrawals: [WithdrawalRequestItem] = []
    @Published public var notifications: [NotificationItem] = []
    
    // Filtros e UI State
    @Published public var selectedCategoryId: String? = nil
    @Published public var searchText: String = ""
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var statusMessage: String? = nil
    
    private let api = APIService.shared
    public let locationManager = LocationManager.shared
    public let notificationManager = NotificationManager.shared
    
    public init() {
        restoreSession()
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Persistência Local e Autenticação Segura (CRUD 0)
    public func restoreSession() {
        if let savedUser = SessionManager.shared.loadUserSession() {
            self.currentUser = savedUser
            self.isAuthenticated = true
        }
    }
    
    public func login(email: String, password: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            struct LoginPayload: Encodable {
                let email: String
                let password: String
            }
            let response: AuthResponse = try await api.post(endpoint: "auth/login", body: LoginPayload(email: email, password: password))
            _ = KeychainHelper.shared.save(key: "auth_token", value: response.token)
            SessionManager.shared.saveUserSession(response.user)
            self.currentUser = response.user
            self.isAuthenticated = true
            self.statusMessage = "Bem-vindo de volta, \(response.user.name)!"
            notificationManager.sendLocalNotification(title: "Login Realizado", body: "Você está conectado como \(response.user.name).")
            await refreshUserData()
            return true
        } catch {
            errorMessage = "Erro no login: \(error.localizedDescription)"
            return false
        }
    }
    
    public func register(name: String, email: String, password: String, role: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            struct RegisterPayload: Encodable {
                let name: String
                let email: String
                let password: String
                let role: String
                let latitude: Double?
                let longitude: Double?
                let city: String?
                let state: String?
            }
            let loc = locationManager.userLocation
            let payload = RegisterPayload(
                name: name,
                email: email,
                password: password,
                role: role,
                latitude: loc?.coordinate.latitude,
                longitude: loc?.coordinate.longitude,
                city: locationManager.cityName,
                state: "SC"
            )
            let response: AuthResponse = try await api.post(endpoint: "auth/register", body: payload)
            _ = KeychainHelper.shared.save(key: "auth_token", value: response.token)
            SessionManager.shared.saveUserSession(response.user)
            self.currentUser = response.user
            self.isAuthenticated = true
            self.statusMessage = "Conta criada com sucesso!"
            notificationManager.sendLocalNotification(title: "Conta Criada", body: "Seja muito bem-vindo ao Vakinha!")
            await refreshUserData()
            return true
        } catch {
            errorMessage = "Erro no cadastro: \(error.localizedDescription)"
            return false
        }
    }
    
    public func logout() {
        SessionManager.shared.clearSession()
        self.currentUser = nil
        self.isAuthenticated = false
        self.favorites = []
        self.notifications = []
        self.statusMessage = "Sessão encerrada com segurança."
    }
    
    // MARK: - Carregamento Geral do PostgreSQL
    public func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }
        
        await fetchCategories()
        await fetchCampaigns()
        await fetchUsers()
        await refreshUserData()
    }
    
    public func refreshUserData() async {
        guard let user = currentUser else { return }
        await fetchFavorites(userId: user.id)
        await fetchNotifications(userId: user.id)
        await fetchWithdrawals()
        await fetchReports()
        await fetchVerifications()
    }
    
    // MARK: - 1. Campanhas CRUD
    public func fetchCampaigns() async {
        do {
            var endpoint = "campaigns"
            var queryParts: [String] = []
            if let catId = selectedCategoryId {
                queryParts.append("category=\(catId)")
            }
            if !searchText.isEmpty {
                queryParts.append("search=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
            }
            if !queryParts.isEmpty {
                endpoint += "?" + queryParts.joined(separator: "&")
            }
            self.campaigns = try await api.get(endpoint: endpoint)
        } catch {
            self.errorMessage = "Erro ao buscar vaquinhas: \(error.localizedDescription)"
        }
    }
    
    public func createCampaign(title: String, description: String, goalAmount: Double, categoryId: String?, imageBase64: String? = nil, locationName: String? = nil, lat: Double? = nil, lon: Double? = nil) async -> Bool {
        guard let user = currentUser else {
            errorMessage = "Faça login para criar uma vaquinha."
            return false
        }
        do {
            struct NewCampaignPayload: Encodable {
                let title: String
                let description: String
                let goal_amount: Double
                let category_id: String?
                let creator_id: String
                let image_url: String?
                let location_name: String?
                let latitude: Double?
                let longitude: Double?
            }
            let payload = NewCampaignPayload(
                title: title,
                description: description,
                goal_amount: goalAmount,
                category_id: categoryId,
                creator_id: user.id,
                image_url: imageBase64,
                location_name: locationName ?? locationManager.cityName,
                latitude: lat ?? locationManager.userLocation?.coordinate.latitude,
                longitude: lon ?? locationManager.userLocation?.coordinate.longitude
            )
            let _: CampaignItem = try await api.post(endpoint: "campaigns", body: payload)
            await fetchCampaigns()
            statusMessage = "Vaquinha publicada com sucesso!"
            notificationManager.sendLocalNotification(title: "Campanha Criada!", body: "Sua vaquinha \"\(title)\" já está no ar arrecadando.")
            return true
        } catch {
            errorMessage = "Erro ao criar vaquinha: \(error.localizedDescription)"
            return false
        }
    }
    
    public func updateCampaign(id: String, title: String, description: String, goalAmount: Double, categoryId: String?, status: String, locationName: String?) async -> Bool {
        do {
            struct UpdateCampaignPayload: Encodable {
                let title: String
                let description: String
                let goal_amount: Double
                let category_id: String?
                let status: String
                let location_name: String?
            }
            let payload = UpdateCampaignPayload(title: title, description: description, goal_amount: goalAmount, category_id: categoryId, status: status, location_name: locationName)
            let _: CampaignItem = try await api.put(endpoint: "campaigns/\(id)", body: payload)
            await fetchCampaigns()
            statusMessage = "Vaquinha atualizada!"
            return true
        } catch {
            errorMessage = "Erro ao editar vaquinha: \(error.localizedDescription)"
            return false
        }
    }
    
    public func deleteCampaign(id: String) async {
        do {
            try await api.delete(endpoint: "campaigns/\(id)")
            self.campaigns.removeAll { $0.id == id }
            statusMessage = "Vaquinha excluída do PostgreSQL."
        } catch {
            errorMessage = "Erro ao excluir vaquinha: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 2. Doações CRUD
    public func fetchDonations(for campaignId: String? = nil) async {
        do {
            var endpoint = "donations"
            if let cid = campaignId {
                endpoint += "?campaignId=\(cid)"
            }
            self.donations = try await api.get(endpoint: endpoint)
        } catch {
            errorMessage = "Erro ao buscar doações: \(error.localizedDescription)"
        }
    }
    
    public func makeDonation(campaignId: String, amount: Double, paymentMethod: String, message: String?) async -> Bool {
        guard let user = currentUser else {
            errorMessage = "Faça login para doar."
            return false
        }
        do {
            struct DonationPayload: Encodable {
                let campaign_id: String
                let user_id: String
                let amount: Double
                let payment_method: String
                let message: String?
            }
            let payload = DonationPayload(campaign_id: campaignId, user_id: user.id, amount: amount, payment_method: paymentMethod, message: message)
            let _: DonationItem = try await api.post(endpoint: "donations", body: payload)
            await fetchCampaigns()
            await fetchDonations(for: campaignId)
            await fetchNotifications(userId: user.id)
            statusMessage = "Doação de R$ \(String(format: "%.2f", amount)) realizada com sucesso!"
            notificationManager.sendLocalNotification(
                title: "Doacao Confirmada!",
                body: "Obrigado! Seu apoio de R$ \(String(format: "%.2f", amount)) foi processado via \(paymentMethod)."
            )
            return true
        } catch {
            errorMessage = "Erro ao processar doação: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - 3. Atualizações / Novidades CRUD
    public func fetchUpdates(for campaignId: String) async {
        do {
            self.updates = try await api.get(endpoint: "updates?campaignId=\(campaignId)")
        } catch {
            errorMessage = "Erro ao carregar novidades: \(error.localizedDescription)"
        }
    }
    
    public func createUpdate(campaignId: String, title: String, content: String, imageUrl: String? = nil) async -> Bool {
        do {
            struct UpdatePayload: Encodable {
                let campaign_id: String
                let title: String
                let content: String
                let image_url: String?
            }
            let payload = UpdatePayload(campaign_id: campaignId, title: title, content: content, image_url: imageUrl)
            let _: CampaignUpdateItem = try await api.post(endpoint: "updates", body: payload)
            await fetchUpdates(for: campaignId)
            statusMessage = "Novidade postada no mural!"
            return true
        } catch {
            errorMessage = "Erro ao postar novidade: \(error.localizedDescription)"
            return false
        }
    }
    
    public func deleteUpdate(id: String, campaignId: String) async {
        do {
            try await api.delete(endpoint: "updates/\(id)")
            await fetchUpdates(for: campaignId)
        } catch {
            errorMessage = "Erro ao excluir novidade: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 4. Mensagens do Mural CRUD
    public func fetchMessages(for campaignId: String) async {
        do {
            self.messages = try await api.get(endpoint: "messages?campaignId=\(campaignId)")
        } catch {
            errorMessage = "Erro ao buscar mensagens do mural: \(error.localizedDescription)"
        }
    }
    
    public func postMessage(campaignId: String, message: String) async -> Bool {
        let user = currentUser
        do {
            struct MessagePayload: Encodable {
                let campaign_id: String
                let user_id: String
                let author_name: String
                let message: String
            }
            let payload = MessagePayload(campaign_id: campaignId, user_id: user?.id ?? "usr-anon", author_name: user?.name ?? "Apoiador Anônimo", message: message)
            let _: WallMessageItem = try await api.post(endpoint: "messages", body: payload)
            await fetchMessages(for: campaignId)
            return true
        } catch {
            errorMessage = "Erro ao enviar mensagem: \(error.localizedDescription)"
            return false
        }
    }
    
    public func deleteMessage(id: String, campaignId: String) async {
        do {
            try await api.delete(endpoint: "messages/\(id)")
            await fetchMessages(for: campaignId)
        } catch {
            errorMessage = "Erro ao apagar mensagem: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 5. Denúncias CRUD
    public func fetchReports() async {
        do {
            self.reports = try await api.get(endpoint: "reports")
        } catch {
            errorMessage = "Erro ao carregar denúncias: \(error.localizedDescription)"
        }
    }
    
    public func createReport(campaignId: String, reason: String) async -> Bool {
        let user = currentUser
        do {
            struct ReportPayload: Encodable {
                let campaign_id: String
                let reporter_id: String
                let reason: String
            }
            let payload = ReportPayload(campaign_id: campaignId, reporter_id: user?.id ?? "usr-1", reason: reason)
            let _: ReportItem = try await api.post(endpoint: "reports", body: payload)
            await fetchReports()
            statusMessage = "Denúncia registrada para análise da moderação."
            return true
        } catch {
            errorMessage = "Erro ao registrar denúncia: \(error.localizedDescription)"
            return false
        }
    }
    
    public func updateReportStatus(id: String, status: String) async {
        do {
            struct StatusPayload: Encodable { let status: String }
            let _: ReportItem = try await api.put(endpoint: "reports/\(id)", body: StatusPayload(status: status))
            await fetchReports()
        } catch {
            errorMessage = "Erro ao atualizar denúncia: \(error.localizedDescription)"
        }
    }
    
    public func deleteReport(id: String) async {
        do {
            try await api.delete(endpoint: "reports/\(id)")
            await fetchReports()
        } catch {
            errorMessage = "Erro ao deletar denúncia: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 6. Verificação de ONG CRUD
    public func fetchVerifications() async {
        do {
            self.verifications = try await api.get(endpoint: "verifications")
        } catch {
            errorMessage = "Erro ao carregar verificações: \(error.localizedDescription)"
        }
    }
    
    public func submitNGOVerification(orgName: String, docNumber: String, docsUrl: String) async -> Bool {
        guard let user = currentUser else { return false }
        do {
            struct NGOPayload: Encodable {
                let user_id: String
                let organization_name: String
                let document_number: String
                let documents_url: String?
            }
            let payload = NGOPayload(user_id: user.id, organization_name: orgName, document_number: docNumber, documents_url: docsUrl)
            let _: NGOVerificationItem = try await api.post(endpoint: "verifications", body: payload)
            await fetchVerifications()
            statusMessage = "Documentação enviada para homologação do selo de ONG!"
            return true
        } catch {
            errorMessage = "Erro ao submeter verificação: \(error.localizedDescription)"
            return false
        }
    }
    
    public func updateVerificationStatus(id: String, status: String, notes: String? = nil) async {
        do {
            struct VerStatusPayload: Encodable {
                let status: String
                let notes: String?
            }
            let _: NGOVerificationItem = try await api.put(endpoint: "verifications/\(id)", body: VerStatusPayload(status: status, notes: notes))
            await fetchVerifications()
        } catch {
            errorMessage = "Erro ao atualizar verificação: \(error.localizedDescription)"
        }
    }
    
    public func deleteVerification(id: String) async {
        do {
            try await api.delete(endpoint: "verifications/\(id)")
            await fetchVerifications()
        } catch {
            errorMessage = "Erro ao cancelar verificação: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 7. Categorias CRUD
    public func fetchCategories() async {
        do {
            self.categories = try await api.get(endpoint: "categories")
        } catch {
            errorMessage = "Erro ao buscar categorias: \(error.localizedDescription)"
        }
    }
    
    public func createCategory(name: String, iconName: String) async -> Bool {
        do {
            struct CatPayload: Encodable {
                let name: String
                let icon_name: String
            }
            let _: CategoryItem = try await api.post(endpoint: "categories", body: CatPayload(name: name, icon_name: iconName))
            await fetchCategories()
            return true
        } catch {
            errorMessage = "Erro ao criar categoria: \(error.localizedDescription)"
            return false
        }
    }
    
    public func deleteCategory(id: String) async {
        do {
            try await api.delete(endpoint: "categories/\(id)")
            await fetchCategories()
        } catch {
            errorMessage = "Erro ao deletar categoria: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 8. Favoritos CRUD
    public func fetchFavorites(userId: String? = nil) async {
        let uid = userId ?? currentUser?.id ?? "usr-1"
        do {
            self.favorites = try await api.get(endpoint: "favorites?userId=\(uid)")
        } catch {
            errorMessage = "Erro ao buscar favoritos: \(error.localizedDescription)"
        }
    }
    
    public func toggleFavorite(campaignId: String) async {
        guard let user = currentUser else {
            errorMessage = "Faça login para favoritar."
            return
        }
        let isFav = favorites.contains { $0.campaignId == campaignId }
        do {
            if isFav {
                try await api.delete(endpoint: "favorites?userId=\(user.id)&campaignId=\(campaignId)")
            } else {
                struct FavPayload: Encodable {
                    let user_id: String
                    let campaign_id: String
                }
                let _: FavoriteItem? = try? await api.post(endpoint: "favorites", body: FavPayload(user_id: user.id, campaign_id: campaignId))
            }
            await fetchFavorites(userId: user.id)
        } catch {
            errorMessage = "Erro ao atualizar favoritos: \(error.localizedDescription)"
        }
    }
    
    public func isFavorite(campaignId: String) -> Bool {
        favorites.contains { $0.campaignId == campaignId }
    }
    
    // MARK: - 9. Solicitações de Saque CRUD
    public func fetchWithdrawals() async {
        do {
            self.withdrawals = try await api.get(endpoint: "withdrawals")
        } catch {
            errorMessage = "Erro ao buscar saques: \(error.localizedDescription)"
        }
    }
    
    public func createWithdrawal(campaignId: String, amount: Double, pixKey: String) async -> Bool {
        guard let user = currentUser else { return false }
        do {
            struct WithPayload: Encodable {
                let campaign_id: String
                let creator_id: String
                let amount: Double
                let pix_key: String
            }
            let payload = WithPayload(campaign_id: campaignId, creator_id: user.id, amount: amount, pix_key: pixKey)
            let _: WithdrawalRequestItem = try await api.post(endpoint: "withdrawals", body: payload)
            await fetchWithdrawals()
            statusMessage = "Solicitação de saque de R$ \(String(format: "%.2f", amount)) enviada para conferência!"
            return true
        } catch {
            errorMessage = "Erro ao solicitar saque: \(error.localizedDescription)"
            return false
        }
    }
    
    public func updateWithdrawalStatus(id: String, status: String) async {
        do {
            struct WStatusPayload: Encodable { let status: String }
            let _: WithdrawalRequestItem = try await api.put(endpoint: "withdrawals/\(id)", body: WStatusPayload(status: status))
            await fetchWithdrawals()
        } catch {
            errorMessage = "Erro ao atualizar status de saque: \(error.localizedDescription)"
        }
    }
    
    public func deleteWithdrawal(id: String) async {
        do {
            try await api.delete(endpoint: "withdrawals/\(id)")
            await fetchWithdrawals()
        } catch {
            errorMessage = "Erro ao cancelar saque: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 10. Notificações CRUD
    public func fetchNotifications(userId: String? = nil) async {
        let uid = userId ?? currentUser?.id ?? "usr-1"
        do {
            self.notifications = try await api.get(endpoint: "notifications?userId=\(uid)")
        } catch {
            errorMessage = "Erro ao carregar notificações: \(error.localizedDescription)"
        }
    }
    
    public func markNotificationAsRead(id: String) async {
        do {
            struct EmptyPayload: Encodable {}
            let _: NotificationItem = try await api.put(endpoint: "notifications/\(id)/read", body: EmptyPayload())
            if let user = currentUser {
                await fetchNotifications(userId: user.id)
            }
        } catch {
            errorMessage = "Erro ao marcar notificação: \(error.localizedDescription)"
        }
    }
    
    public func deleteNotification(id: String) async {
        do {
            try await api.delete(endpoint: "notifications/\(id)")
            if let user = currentUser {
                await fetchNotifications(userId: user.id)
            }
        } catch {
            errorMessage = "Erro ao remover notificação: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Usuários do PostgreSQL
    public func fetchUsers() async {
        do {
            self.availableUsers = try await api.get(endpoint: "users")
            if self.currentUser == nil, let first = availableUsers.first {
                self.currentUser = first
                self.isAuthenticated = true
                SessionManager.shared.saveUserSession(first)
                await refreshUserData()
            }
        } catch {
            print("Aviso ao buscar usuários: \(error.localizedDescription)")
        }
    }
    
    public func switchUser(user: AppUser) {
        self.currentUser = user
        self.isAuthenticated = true
        SessionManager.shared.saveUserSession(user)
        Task {
            await refreshUserData()
        }
    }
}
