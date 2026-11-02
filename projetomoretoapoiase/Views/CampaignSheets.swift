import SwiftUI
import MapKit

// MARK: - Visualização de Campanhas em Mapa Nativo (CoreLocation / MapKit)
struct CampaignsMapView: View {
    @ObservedObject var vm: NexoViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var position: MapCameraPosition = .userLocation(fallback: .camera(
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: -27.1004, longitude: -52.6152), distance: 15000)
    ))
    
    var body: some View {
        NavigationStack {
            Map(position: $position) {
                UserAnnotation()
                ForEach(vm.campaigns) { cmp in
                    if let lat = cmp.latitude, let lon = cmp.longitude {
                        Annotation(cmp.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            NavigationLink {
                                CampaignDetailView(vm: vm, campaign: cmp)
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: "heart.circle.fill")
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .foregroundColor(.vakinhaBlue)
                                        .background(Color.white.clipShape(Circle()))
                                    Text(cmp.percentFormatted)
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
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
            }
            .navigationTitle("Vaquinhas Próximas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Modal de Criação de Campanha (Câmera + Localização + CRUD 1)
struct CreateCampaignSheet: View {
    @ObservedObject var vm: NexoViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var goal: String = ""
    @State private var selectedCategory: String = ""
    @State private var locationName: String = ""
    
    // Câmera & Imagem Nativa
    @State private var selectedImage: UIImage? = nil
    @State private var showingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Capa da Vaquinha (Câmera Nativa)") {
                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                            .cornerRadius(12)
                    }
                    
                    HStack {
                        Button {
                            imageSource = .camera
                            showingImagePicker = true
                        } label: {
                            Label("Tirar Foto", systemImage: "camera.fill")
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
                    TextField("História completa e para que serve o recurso...", text: $description, axis: .vertical)
                        .lineLimit(4...8)
                    TextField("Meta de Arrecadação (R$)", text: $goal)
                        .keyboardType(.decimalPad)
                }
                
                Section("Localização (Geolocalização Nativa)") {
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
                        var base64String: String? = nil
                        if let img = selectedImage, let data = img.jpegData(compressionQuality: 0.6) {
                            base64String = data.base64EncodedString()
                        }
                        Task {
                            let catId = selectedCategory.isEmpty ? nil : selectedCategory
                            let success = await vm.createCampaign(
                                title: title,
                                description: description,
                                goalAmount: goalVal,
                                categoryId: catId,
                                imageBase64: base64String,
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
