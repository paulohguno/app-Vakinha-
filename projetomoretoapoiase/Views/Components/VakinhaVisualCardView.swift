import SwiftUI

// MARK: - Banner e Ilustracao Tematica por Categoria
public struct CategoryCardHeader: View {
    public let categoryName: String?
    public let iconName: String?
    public let imageUrl: String?
    
    public init(categoryName: String?, iconName: String?, imageUrl: String?) {
        self.categoryName = categoryName
        self.iconName = iconName
        self.imageUrl = imageUrl
    }
    
    // Cores e Icones tematicos baseados na categoria do banco
    private var categoryColor: Color {
        let name = (categoryName ?? "").lowercased()
        if name.contains("anim") {
            return Color(red: 0.98, green: 0.60, blue: 0.15) // Laranja Animais (exatamente como no print)
        } else if name.contains("saud") {
            return Color(red: 0.90, green: 0.28, blue: 0.28) // Vermelho/Rosa Saude
        } else if name.contains("comun") {
            return Color(red: 0.20, green: 0.70, blue: 0.40) // Verde Comunidade
        } else if name.contains("emerg") {
            return Color(red: 0.95, green: 0.35, blue: 0.20) // Laranja/Vermelho Emergencia
        } else if name.contains("cult") {
            return Color(red: 0.55, green: 0.30, blue: 0.85) // Roxo Cultura
        } else {
            return Color(red: 0.18, green: 0.58, blue: 1.0) // Azul Educacao (exatamente como no print)
        }
    }
    
    private var watermarkIcon: String {
        let name = (categoryName ?? "").lowercased()
        if name.contains("anim") {
            return "pawprint.fill"
        } else if name.contains("saud") {
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
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Fundo Colorido com Watermark
            Rectangle()
                .fill(categoryColor)
                .frame(height: 180)
            
            // Marca d'agua em marca grande no canto direito (exatamente igual ao print)
            HStack {
                Spacer()
                Image(systemName: watermarkIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .foregroundColor(.white.opacity(0.25))
                    .offset(x: 20, y: 15)
            }
            .frame(height: 180)
            .clipped()
            
            // Pill / Tag de Categoria com icone e fundo branco translúcido
            HStack(spacing: 6) {
                Image(systemName: iconName ?? watermarkIcon)
                    .font(.system(size: 13, weight: .bold))
                Text(categoryName ?? "Geral")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.85))
            .cornerRadius(20)
            .padding(.top, 16)
            .padding(.leading, 16)
        }
    }
}

// MARK: - Card Fiel ao Design Solicitado (Imagem do Usuario)
public struct VakinhaVisualCardView: View {
    public let campaign: CampaignItem
    public let isFavorite: Bool
    public let onFavoriteToggle: () -> Void
    public let onDonateTapped: () -> Void
    
    public init(
        campaign: CampaignItem,
        isFavorite: Bool,
        onFavoriteToggle: @escaping () -> Void,
        onDonateTapped: @escaping () -> Void
    ) {
        self.campaign = campaign
        self.isFavorite = isFavorite
        self.onFavoriteToggle = onFavoriteToggle
        self.onDonateTapped = onDonateTapped
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. HEADER ILUSTRADO DA CATEGORIA
            CategoryCardHeader(
                categoryName: campaign.categoryName,
                iconName: campaign.categoryIcon,
                imageUrl: campaign.imageUrl
            )
            
            // 2. CORPO DO CARD (Branco com tipografia e metadados)
            VStack(alignment: .leading, spacing: 10) {
                // Titulo da Campanha
                Text(campaign.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                // Localizacao e Nome do Criador com o icone de pino
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.systemGray))
                    
                    Text("\(campaign.locationName ?? "Brasil") · \(campaign.creatorName ?? "Criador")")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.systemGray))
                        .lineLimit(1)
                }
                
                // Barra de Progresso Verde
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.15, green: 0.78, blue: 0.45)) // Verde Vakinha exatamente como no print
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
                
                // Quantidade de Apoiadores
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.systemGray))
                    
                    let apoios = Int(campaign.donationsCount ?? "0") ?? 1
                    Text(apoios == 1 ? "1 apoiador" : "\(apoios) apoiadores")
                        .font(.system(size: 14))
                        .foregroundColor(Color(.systemGray))
                    
                    Spacer()
                    
                    // Botao de Favoritar discreto
                    Button(action: onFavoriteToggle) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorite ? .red : Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.white)
        }
        .cornerRadius(24) // Borda arredondada exatamente como no print
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
