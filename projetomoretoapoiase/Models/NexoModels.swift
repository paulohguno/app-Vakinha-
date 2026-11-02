import Foundation

// MARK: - Entidade Base Identificável e Decodificável
public protocol NexoEntity: Identifiable, Codable, Equatable {
    var id: String { get set }
}

// MARK: - 1. Categoria (CRUD 7)
public struct CategoryItem: NexoEntity {
    public var id: String
    public var name: String
    public var iconName: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconName = "icon_name"
    }
    
    public init(id: String = UUID().uuidString, name: String, iconName: String = "folder.fill") {
        self.id = id
        self.name = name
        self.iconName = iconName
    }
}

// MARK: - Usuário e Sessão com Localização (CRUD 0)
public struct AppUser: NexoEntity {
    public var id: String
    public var name: String
    public var email: String
    public var role: String
    public var avatarURL: String?
    public var latitude: Double?
    public var longitude: Double?
    public var city: String?
    public var state: String?
    public var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case role
        case avatarURL = "avatar_url"
        case latitude
        case longitude
        case city
        case state
        case createdAt = "created_at"
    }
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        email: String,
        role: String = "Doador",
        avatarURL: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        city: String? = nil,
        state: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.avatarURL = avatarURL
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.state = state
        self.createdAt = createdAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "Doador"
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        if let latD = try? container.decode(Double.self, forKey: .latitude) {
            latitude = latD
        } else if let latS = try? container.decode(String.self, forKey: .latitude), let parsed = Double(latS) {
            latitude = parsed
        } else {
            latitude = nil
        }
        
        if let lonD = try? container.decode(Double.self, forKey: .longitude) {
            longitude = lonD
        } else if let lonS = try? container.decode(String.self, forKey: .longitude), let parsed = Double(lonS) {
            longitude = parsed
        } else {
            longitude = nil
        }
    }
}

// Resposta de Autenticação
public struct AuthResponse: Codable {
    public let user: AppUser
    public let token: String
}

// MARK: - 2. Campanha com Geolocalização e Fotos (CRUD 1)
public struct CampaignItem: NexoEntity {
    public var id: String
    public var creatorId: String
    public var categoryId: String?
    public var title: String
    public var description: String
    public var goalAmount: Double
    public var currentAmount: Double
    public var status: String
    public var imageUrl: String?
    public var latitude: Double?
    public var longitude: Double?
    public var locationName: String?
    public var categoryName: String?
    public var categoryIcon: String?
    public var creatorName: String?
    public var donationsCount: String?
    public var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case categoryId = "category_id"
        case title
        case description
        case goalAmount = "goal_amount"
        case currentAmount = "current_amount"
        case status
        case imageUrl = "image_url"
        case latitude
        case longitude
        case locationName = "location_name"
        case categoryName = "category_name"
        case categoryIcon = "category_icon"
        case creatorName = "creator_name"
        case donationsCount = "donations_count"
        case createdAt = "created_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        creatorId = try container.decode(String.self, forKey: .creatorId)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "ativa"
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        categoryIcon = try container.decodeIfPresent(String.self, forKey: .categoryIcon)
        creatorName = try container.decodeIfPresent(String.self, forKey: .creatorName)
        donationsCount = try container.decodeIfPresent(String.self, forKey: .donationsCount)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        if let gDouble = try? container.decode(Double.self, forKey: .goalAmount) {
            goalAmount = gDouble
        } else if let gStr = try? container.decode(String.self, forKey: .goalAmount), let parsed = Double(gStr) {
            goalAmount = parsed
        } else {
            goalAmount = 0.0
        }
        
        if let cDouble = try? container.decode(Double.self, forKey: .currentAmount) {
            currentAmount = cDouble
        } else if let cStr = try? container.decode(String.self, forKey: .currentAmount), let parsed = Double(cStr) {
            currentAmount = parsed
        } else {
            currentAmount = 0.0
        }
        
        if let latD = try? container.decode(Double.self, forKey: .latitude) {
            latitude = latD
        } else if let latS = try? container.decode(String.self, forKey: .latitude), let parsed = Double(latS) {
            latitude = parsed
        } else {
            latitude = nil
        }
        
        if let lonD = try? container.decode(Double.self, forKey: .longitude) {
            longitude = lonD
        } else if let lonS = try? container.decode(String.self, forKey: .longitude), let parsed = Double(lonS) {
            longitude = parsed
        } else {
            longitude = nil
        }
    }
    
    public var progress: Double {
        guard goalAmount > 0 else { return 0 }
        return min(currentAmount / goalAmount, 1.0)
    }
    
    public var percentFormatted: String {
        let pct = Int(progress * 100)
        return "\(pct)%"
    }
}

// Necessário para navigationDestination(item:) no feed
extension CampaignItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 3. Doação (CRUD 2)
public struct DonationItem: NexoEntity {
    public var id: String
    public var campaignId: String
    public var userId: String?
    public var amount: Double
    public var paymentMethod: String
    public var message: String?
    public var userName: String?
    public var campaignTitle: String?
    public var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case campaignId = "campaign_id"
        case userId = "user_id"
        case amount
        case paymentMethod = "payment_method"
        case message
        case userName = "user_name"
        case campaignTitle = "campaign_title"
        case createdAt = "created_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        campaignId = try container.decode(String.self, forKey: .campaignId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod) ?? "PIX"
        message = try container.decodeIfPresent(String.self, forKey: .message)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
        campaignTitle = try container.decodeIfPresent(String.self, forKey: .campaignTitle)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        if let aDouble = try? container.decode(Double.self, forKey: .amount) {
            amount = aDouble
        } else if let aStr = try? container.decode(String.self, forKey: .amount), let parsed = Double(aStr) {
            amount = parsed
        } else {
            amount = 0.0
        }
    }
}

// MARK: - 4. Atualização da Campanha / Novidade (CRUD 3)
public struct CampaignUpdateItem: NexoEntity {
    public var id: String
    public var campaignId: String
    public var title: String
    public var content: String
    public var imageUrl: String?
    public var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case campaignId = "campaign_id"
        case title
        case content
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
}

// MARK: - 5. Mensagem do Mural (CRUD 4)
public struct WallMessageItem: NexoEntity {
    public var id: String
    public var campaignId: String
    public var userId: String?
    public var authorName: String?
    public var message: String
    public var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case campaignId = "campaign_id"
        case userId = "user_id"
        case authorName = "author_name"
        case message
        case createdAt = "created_at"
    }
}

// MARK: - 6. Denúncia (CRUD 5)
public struct ReportItem: NexoEntity {
    public var id: String
    public var campaignId: String
    public var reporterId: String?
    public var reason: String
    public var status: String
    public var campaignTitle: String?
    public var reporterName: String?
    public var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case campaignId = "campaign_id"
        case reporterId = "reporter_id"
        case reason
        case status
        case campaignTitle = "campaign_title"
        case reporterName = "reporter_name"
        case createdAt = "created_at"
    }
}

// MARK: - 7. Verificação de ONG (CRUD 6)
public struct NGOVerificationItem: NexoEntity {
    public var id: String
    public var userId: String
    public var organizationName: String
    public var documentNumber: String
    public var documentsUrl: String?
    public var status: String
    public var notes: String?
    public var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case organizationName = "organization_name"
        case documentNumber = "document_number"
        case documentsUrl = "documents_url"
        case status
        case notes
        case createdAt = "created_at"
    }
}

// MARK: - 8. Favorito (CRUD 8)
public struct FavoriteItem: NexoEntity {
    public var id: String
    public var userId: String
    public var campaignId: String
    public var title: String?
    public var description: String?
    public var goalAmount: Double?
    public var currentAmount: Double?
    public var locationName: String?
    public var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case campaignId = "campaign_id"
        case title
        case description
        case goalAmount = "goal_amount"
        case currentAmount = "current_amount"
        case locationName = "location_name"
        case createdAt = "created_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        campaignId = try container.decode(String.self, forKey: .campaignId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        if let gDouble = try? container.decode(Double.self, forKey: .goalAmount) {
            goalAmount = gDouble
        } else if let gStr = try? container.decode(String.self, forKey: .goalAmount), let parsed = Double(gStr) {
            goalAmount = parsed
        } else {
            goalAmount = nil
        }
        
        if let cDouble = try? container.decode(Double.self, forKey: .currentAmount) {
            currentAmount = cDouble
        } else if let cStr = try? container.decode(String.self, forKey: .currentAmount), let parsed = Double(cStr) {
            currentAmount = parsed
        } else {
            currentAmount = nil
        }
    }
}

// MARK: - 9. Solicitação de Saque (CRUD 9)
public struct WithdrawalRequestItem: NexoEntity {
    public var id: String
    public var campaignId: String
    public var creatorId: String
    public var amount: Double
    public var pixKey: String
    public var status: String
    public var campaignTitle: String?
    public var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case campaignId = "campaign_id"
        case creatorId = "creator_id"
        case amount
        case pixKey = "pix_key"
        case status
        case campaignTitle = "campaign_title"
        case createdAt = "created_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        campaignId = try container.decode(String.self, forKey: .campaignId)
        creatorId = try container.decode(String.self, forKey: .creatorId)
        pixKey = try container.decode(String.self, forKey: .pixKey)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "em_analise"
        campaignTitle = try container.decodeIfPresent(String.self, forKey: .campaignTitle)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        if let aDouble = try? container.decode(Double.self, forKey: .amount) {
            amount = aDouble
        } else if let aStr = try? container.decode(String.self, forKey: .amount), let parsed = Double(aStr) {
            amount = parsed
        } else {
            amount = 0.0
        }
    }
}

// MARK: - 10. Notificação (CRUD 10)
public struct NotificationItem: NexoEntity {
    public var id: String
    public var userId: String
    public var title: String
    public var content: String
    public var isRead: Bool
    public var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case content
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}
