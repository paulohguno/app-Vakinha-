import SwiftUI

// MARK: - Stories de Categorias
public struct InstagramStoriesBarView: View {
    public let categories: [CategoryItem]
    public let selectedCategoryId: String?
    public let onSelectCategory: (String?) -> Void
    
    public init(
        categories: [CategoryItem],
        selectedCategoryId: String?,
        onSelectCategory: @escaping (String?) -> Void
    ) {
        self.categories = categories
        self.selectedCategoryId = selectedCategoryId
        self.onSelectCategory = onSelectCategory
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                // Story Todas
                Button {
                    onSelectCategory(nil)
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .strokeBorder(selectedCategoryId == nil ? Color.vakinhaBlue : Color.clear, lineWidth: 2.5)
                                .frame(width: 66, height: 66)
                            
                            Circle()
                                .fill(selectedCategoryId == nil ? Color.vakinhaBlue : Color.white)
                                .frame(width: 58, height: 58)
                                .shadow(color: Color.black.opacity(0.06), radius: 3)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(selectedCategoryId == nil ? .white : .vakinhaBlue)
                        }
                        
                        Text("Todas")
                            .font(.system(size: 11, weight: selectedCategoryId == nil ? .bold : .regular))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }
                }
                
                // Stories de Categorias
                ForEach(categories) { cat in
                    let isSelected = selectedCategoryId == cat.id
                    Button {
                        onSelectCategory(cat.id)
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: isSelected ? [.vakinhaBlue, .blue.opacity(0.8)] : [.gray.opacity(0.3), .gray.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 66, height: 66)
                                
                                Circle()
                                    .fill(isSelected ? Color.vakinhaBlueLight : Color.white)
                                    .frame(width: 58, height: 58)
                                    .shadow(color: Color.black.opacity(0.06), radius: 3)
                                
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 20))
                                    .foregroundColor(.vakinhaBlue)
                            }
                            
                            Text(cat.name.components(separatedBy: " ").first ?? cat.name)
                                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                                .foregroundColor(.black)
                                .frame(width: 66)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color.white)
    }
}
