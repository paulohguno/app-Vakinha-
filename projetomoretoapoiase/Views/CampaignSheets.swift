import SwiftUI
import MapKit
import CoreLocation

// MARK: - Mapa Interativo de Vaquinhas Próximas por GPS (MapKit + CoreLocation)
struct CampaignsMapView: View {
    @ObservedObject var vm: NexoViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .camera(
            MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: -27.1004, longitude: -52.6152),
                distance: 15000
            )
        )
    )
    @State private var radiusKm: Double = 50.0
    @State private var filterByRadius: Bool = false
    
    private var geoCampaigns: [CampaignItem] {
        vm.campaigns.filter { cmp in
            guard let lat = cmp.latitude, let lon = cmp.longitude else { return false }
            if filterByRadius, let userLoc = vm.locationManager.userLocation {
                let cmpLoc = CLLocation(latitude: lat, longitude: lon)
                let distKm = userLoc.distance(from: cmpLoc) / 1000.0
                return distKm <= radiusKm
            }
            return true
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Controle de Filtro de Raio por GPS
                HStack(spacing: 12) {
                    Toggle("Filtrar próximas (\(Int(radiusKm)) km)", isOn: $filterByRadius)
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if filterByRadius {
                        Slider(value: $radiusKm, in: 5...100, step: 5)
                            .tint(.vakinhaBlue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.vakinhaCardBg)
                
                // Mapa Nativo Apple MapKit
                Map(position: $position) {
                    UserAnnotation()
                    ForEach(geoCampaigns) { cmp in
                        if let lat = cmp.latitude, let lon = cmp.longitude {
                            Annotation(cmp.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                                NavigationLink {
                                    CampaignDetailView(vm: vm, campaign: cmp)
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: "heart.circle.fill")
                                            .resizable()
                                            .frame(width: 34, height: 34)
                                            .foregroundColor(.vakinhaBlue)
                                            .background(Color.white.clipShape(Circle()))
                                            .shadow(radius: 3)
                                        Text(cmp.percentFormatted)
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.vakinhaBlue)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
            }
            .navigationTitle("Vaquinhas no Mapa (\(geoCampaigns.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Modal de Criação de Campanha (Upload de Imagem + URL HTTP + Geolocalização GPS)
struct CreateCampaignSheet: View {
    @ObservedObject var vm: NexoViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var goal: String = ""
    @State private var selectedCategory: String = ""
    @State private var locationName: String = ""
    @State private var imageURLInput: String = ""
    
    // Câmera & Galeria Nativa (Enviada ao endpoint /api/uploads para gerar URL HTTP limpa)
    @State private var selectedImage: UIImage? = nil
    @State private var showingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Capa da Vaquinha (URL HTTP ou Câmera Nativa)") {
                    TextField("URL da Imagem (https://...)", text: $imageURLInput)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                            .cornerRadius(12)
                    } else if let previewURL = AppConfig.shared.resolveImageURL(imageURLInput) {
                        AsyncImage(url: previewURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipped()
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                    HStack {
                        Button {
                            imageSource = .camera
                            showingImagePicker = true
                        } label: {
                            Label("Câmera", systemImage: "camera.fill")
                                .foregroundColor(.vakinhaBlue)
                        }
                        
                        Spacer()
                        
                        Button {
                            imageSource = .photoLibrary
                            showingImagePicker = true
                        } label: {
                            Label("Galeria", systemImage: "photo.on.rectangle")
                                .foregroundColor(.vakinhaBlue)
                        }
                    }
                }
                
                Section("Informações da Campanha") {
                    TextField("Título da vaquinha", text: $title)
                    TextField("História completa e finalidade do recurso...", text: $description, axis: .vertical)
                        .lineLimit(4...8)
                    TextField("Meta de Arrecadação (R$)", text: $goal)
                        .keyboardType(.decimalPad)
                }
                
                Section("Localização (Geolocalização GPS)") {
                    HStack {
                        TextField("Cidade / Local (ex: Chapecó/SC)", text: $locationName)
                        Button {
                            locationName = vm.locationManager.cityName
                        } label: {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(.vakinhaBlue)
                        }
                    }
                }
                
                Section("Categoria") {
                    Picker("Selecione", selection: $selectedCategory) {
                        Text("Sem categoria").tag("")
                        ForEach(vm.categories) { cat in
                            Text(cat.name).tag(cat.id)
                        }
                    }
                }
                
                Section {
                    Button {
                        guard let goalVal = Double(goal.replacingOccurrences(of: ",", with: ".")), !title.isEmpty else { return }
                        let jpegData = selectedImage?.jpegData(compressionQuality: 0.7)
                        let trimmedURL = imageURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            let catId = selectedCategory.isEmpty ? nil : selectedCategory
                            let success = await vm.createCampaign(
                                title: title,
                                description: description,
                                goalAmount: goalVal,
                                categoryId: catId,
                                imageUrl: trimmedURL.isEmpty ? nil : trimmedURL,
                                imageData: jpegData,
                                locationName: locationName.isEmpty ? nil : locationName
                            )
                            if success { dismiss() }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Publicar Vaquinha")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .buttonStyle(VakinhaPrimaryButtonStyle())
                    .disabled(title.isEmpty || goal.isEmpty)
                }
            }
            .navigationTitle("Nova Vaquinha")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage, sourceType: imageSource)
            }
            .onAppear {
                if locationName.isEmpty {
                    locationName = vm.locationManager.cityName
                }
            }
        }
    }
}

// MARK: - Gerenciamento de Categorias (CRUD 7)
struct CategoriesManagementSheet: View {
    @ObservedObject var vm: NexoViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var newCategoryName = ""
    @State private var newCategoryIcon = "heart.circle.fill"
    
    var body: some View {
        NavigationStack {
            List {
                Section("Cadastrar Nova Categoria no PostgreSQL") {
                    TextField("Nome da Categoria", text: $newCategoryName)
                    TextField("Ícone SF Symbol", text: $newCategoryIcon)
                    
                    Button("Salvar Categoria") {
                        guard !newCategoryName.isEmpty else { return }
                        Task {
                            let ok = await vm.createCategory(name: newCategoryName, iconName: newCategoryIcon)
                            if ok { newCategoryName = "" }
                        }
                    }
                    .foregroundColor(.vakinhaBlue)
                    .disabled(newCategoryName.isEmpty)
                }
                
                Section("Categorias no Banco (\(vm.categories.count))") {
                    ForEach(vm.categories) { cat in
                        HStack {
                            Image(systemName: cat.iconName)
                                .foregroundColor(.vakinhaBlue)
                            Text(cat.name)
                                .foregroundColor(.vakinhaBlack)
                            Spacer()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await vm.deleteCategory(id: cat.id) }
                            } label: {
                                Label("Excluir", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Categorias (CRUD)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluir") { dismiss() }
                }
            }
        }
    }
}
