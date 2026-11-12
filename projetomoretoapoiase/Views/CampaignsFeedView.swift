import SwiftUI

// MARK: - Feed Principal de Vaquinhas (Busca, Categorias, MapKit GPS, ShareSheet e AsyncImage)
struct CampaignsFeedView: View {
    @ObservedObject var vm: NexoViewModel
    @State private var showingCreateModal = false
    @State private var showingCategoryManager = false
    @State private var showingAuthModal = false
    @State private var showingMapView = false
    @State private var showingSearchField = false
    
    @State private var selectedCampaignForDonate: CampaignItem?
    @State private var selectedCampaignForDetail: CampaignItem?
    @State private var campaignToShare: CampaignItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Superior NEXO Vakinha
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.vakinhaBlue)
                        
                        Text("Vakinha")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        // Busca Rápida
                        Button {
                            withAnimation {
                                showingSearchField.toggle()
                                if !showingSearchField && !vm.searchText.isEmpty {
                                    vm.searchText = ""
                                    Task { await vm.fetchCampaigns() }
                                }
                            }
                        } label: {
                            Image(systemName: showingSearchField ? "magnifyingglass.circle.fill" : "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(showingSearchField ? .vakinhaBlue : .black)
                        }
                        
                        // Mapa de Vaquinhas Próximas (MapKit + GPS)
                        Button {
                            showingMapView = true
                        } label: {
                            Image(systemName: "map")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        
                        // Gerenciador de Categorias
                        Button {
                            showingCategoryManager = true
                        } label: {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        
                        // Nova Campanha
                        Button {
                            if vm.isAuthenticated {
                                showingCreateModal = true
                            } else {
                                showingAuthModal = true
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.vakinhaBlue)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
                
                // Barra de Pesquisa Expansível
                if showingSearchField {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Buscar por título, causa ou cidade...", text: $vm.searchText)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await vm.fetchCampaigns() }
                            }
                        if !vm.searchText.isEmpty {
                            Button {
                                vm.searchText = ""
                                Task { await vm.fetchCampaigns() }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .background(Color.white)
                }
                
                Divider()
                
                // Banners de Feedback
                if let msg = vm.statusMessage {
                    StatusBannerView(message: msg, isError: false) {
                        vm.statusMessage = nil
                    }
                }
                if let err = vm.errorMessage {
                    StatusBannerView(message: err, isError: true) {
                        vm.errorMessage = nil
                    }
                }
                
                // Barra de Categorias (Stories)
                InstagramStoriesBarView(
                    categories: vm.categories,
                    selectedCategoryId: vm.selectedCategoryId
                ) { catId in
                    vm.selectedCategoryId = catId
                    Task { await vm.fetchCampaigns() }
                }
                .padding(.vertical, 4)
                
                // Feed Vertical Contínuo
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(vm.campaigns) { campaign in
                            VakinhaVisualCardView(
                                campaign: campaign,
                                isFavorite: vm.isFavorite(campaignId: campaign.id),
                                distanceLabel: vm.locationManager.distance(to: campaign.latitude, lon: campaign.longitude),
                                onFavoriteToggle: {
                                    Task { await vm.toggleFavorite(campaignId: campaign.id) }
                                },
                                onShareTapped: {
                                    campaignToShare = campaign
                                },
                                onDonateTapped: {
                                    if vm.isAuthenticated {
                                        selectedCampaignForDonate = campaign
                                    } else {
                                        showingAuthModal = true
                                    }
                                }
                            )
                            .onTapGesture {
                                selectedCampaignForDetail = campaign
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
                .refreshable {
                    await vm.fetchCampaigns()
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreateModal) {
                CreateCampaignSheet(vm: vm)
            }
            .sheet(isPresented: $showingCategoryManager) {
                CategoriesManagementSheet(vm: vm)
            }
            .sheet(isPresented: $showingAuthModal) {
                AuthView(vm: vm)
            }
            .sheet(isPresented: $showingMapView) {
                CampaignsMapView(vm: vm)
            }
            .sheet(item: $selectedCampaignForDonate) { cmp in
                DonateSheet(vm: vm, campaign: cmp) {
                    Task {
                        await vm.fetchCampaigns()
                    }
                }
            }
            .sheet(item: $campaignToShare) { cmp in
                ShareSheet(activityItems: [
                    "Apoie a vaquinha \"\(cmp.title)\" no NEXO Vakinha!\nMeta: R$ \(String(format: "%.2f", cmp.goalAmount)) (\(cmp.percentFormatted) arrecadado).\nLocal: \(cmp.locationName ?? "Brasil")"
                ])
            }
            .navigationDestination(item: $selectedCampaignForDetail) { cmp in
                CampaignDetailView(vm: vm, campaign: cmp)
            }
        }
    }
}
