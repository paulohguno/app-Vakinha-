import SwiftUI

// MARK: - Header Visual com Carregamento Assíncrono de Imagem HTTP (AsyncImage) e Fallback Ilustrado
public struct CategoryCardHeader: View {
    public let categoryName: String?
    public let iconName: String?
    public let imageUrl: String?
    
    public init(categoryName: String?, iconName: String?, imageUrl: String?) {
        self.categoryName = categoryName
        self.iconName = iconName
        self.imageUrl = imageUrl
    }
    
    private var categoryColor: Color {
        let name = (categoryName ?? "").lowercased()
        if name.contains("anim") {
            return Color(red: 0.98, green: 0.60, blue: 0.15)
        } else if name.contains("saud") || name.contains("saúd") {
            return Color(red: 0.90, green: 0.28, blue: 0.28)
        } else if name.contains("comun") {
            return Color(red: 0.20, green: 0.70, blue: 0.40)
        } else if name.contains("emerg") {
            return Color(red: 0.95, green: 0.35, blue: 0.20)
        } else if name.contains("cult") {
            return Color(red: 0.55, green: 0.30, blue: 0.85)
        } else {
            return Color(red: 0.18, green: 0.58, blue: 1.0)
        }
    }
    
    private var watermarkIcon: String {
        let name = (categoryName ?? "").lowercased()
        if name.contains("anim") {
            return "pawprint.fill"
        } else if name.contains("saud") || name.contains("saúd") {
            return "cross.case.fill"
        } else if name.contains("comun") {
            return "person.3.fill"
        } else if name.contains("emerg") {
            return "flame.fill"
        } else if name.contains("cult") {
            return "paintpalette.fill"
        } else {
            return "graduationcap.fill"
        }
    }
    
    private var fallbackBanner: some View {
        ZStack {
            Rectangle()
                .fill(categoryColor)
                .frame(height: 185)
            
            HStack {
                Spacer()
                Image(systemName: watermarkIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .foregroundColor(.white.opacity(0.25))
                    .offset(x: 20, y: 15)
            }
            .frame(height: 185)
            .clipped()
        }
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            if let resolvedURL = AppConfig.shared.resolveImageURL(imageUrl) {
                AsyncImage(url: resolvedURL, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        ZStack(alignment: .bottom) {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 185)
                                .clipped()
                            
                            LinearGradient(
                                colors: [Color.black.opacity(0.35), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                            .frame(height: 185)
                        }
                    case .empty:
                        ZStack {
                            fallbackBanner
                            ProgressView()
                                .tint(.white)
                        }
                    case .failure:
                        fallbackBanner
                    @unknown default:
                        fallbackBanner
                    }
                }
                .frame(height: 185)
                .clipped()
            } else {
                fallbackBanner
            }
            
            // Tag de Categoria Flutuante
            HStack(spacing: 6) {
                Image(systemName: iconName ?? watermarkIcon)
                    .font(.system(size: 13, weight: .bold))
                Text(categoryName ?? "Geral")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.90))
            .cornerRadius(20)
            .padding(.top, 16)
            .padding(.leading, 16)
        }
    }
}

// MARK: - Card Visual Completo de Vaquinha para o Feed (Com Favoritar, Compartilhar e Doar)
public struct VakinhaVisualCardView: View {
    public let campaign: CampaignItem
    public let isFavorite: Bool
    public let distanceLabel: String
    public let onFavoriteToggle: () -> Void
    public let onShareTapped: () -> Void
    public let onDonateTapped: () -> Void
    
    public init(
        campaign: CampaignItem,
        isFavorite: Bool,
        distanceLabel: String = "",
        onFavoriteToggle: @escaping () -> Void,
        onShareTapped: @escaping () -> Void = {},
        onDonateTapped: @escaping () -> Void
    ) {
        self.campaign = campaign
        self.isFavorite = isFavorite
        self.distanceLabel = distanceLabel
        self.onFavoriteToggle = onFavoriteToggle
        self.onShareTapped = onShareTapped
        self.onDonateTapped = onDonateTapped
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Header com AsyncImage Otimizado
            CategoryCardHeader(
                categoryName: campaign.categoryName,
                iconName: campaign.categoryIcon,
                imageUrl: campaign.imageUrl
            )
            
            // 2. Corpo do Card
            VStack(alignment: .leading, spacing: 10) {
                Text(campaign.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.systemGray))
                    
                    Text("\(campaign.locationName ?? "Brasil") · \(campaign.creatorName ?? "Criador")")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                    
                    if !distanceLabel.isEmpty {
                        Spacer()
                        Text(distanceLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.vakinhaBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.vakinhaBlueLight)
                            .cornerRadius(6)
                    }
                }
                
                // Barra de Progresso
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.15, green: 0.78, blue: 0.45))
                            .frame(width: max(geo.size.width * CGFloat(campaign.progress), 4), height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.top, 2)
                
                // Valores Arrecadados e Porcentagem
                HStack(alignment: .firstTextBaseline) {
                    Text("R$ \(String(format: "%.2f", campaign.currentAmount).replacingOccurrences(of: ".", with: ","))")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("de R$ \(String(format: "%.2f", campaign.goalAmount).replacingOccurrences(of: ".", with: ","))")
                        .font(.system(size: 15))
                        .foregroundColor(Color(.systemGray))
                    
                    Spacer()
                    
                    Text(campaign.percentFormatted)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.45))
                }
                
                // Rodapé do Card: Apoiadores, Compartilhar, Favoritar e Ação Rápida de Doar
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(.systemGray))
                        
                        let apoios = Int(campaign.donationsCount ?? "0") ?? 0
                        Text(apoios == 1 ? "1 apoiador" : "\(apoios) apoiadores")
                            .font(.system(size: 14))
                            .foregroundColor(Color(.systemGray))
                    }
                    
                    Spacer()
                    
                    // Botão de Compartilhar Nativo
                    Button(action: onShareTapped) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.vakinhaBlue)
                    }
                    .buttonStyle(.plain)
                    
                    // Botão de Favoritar
                    Button(action: onFavoriteToggle) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorite ? .red : Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                    
                    // Botão Rápido Apoiar
                    Button(action: onDonateTapped) {
                        Text("Doar")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.vakinhaBlue)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white)
        }
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
