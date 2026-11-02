import SwiftUI

// MARK: - Feed Principal de Vaquinhas (Exatamente no Modelo Solicitado + Suporte a Imagens e Categorias)
struct CampaignsFeedView: View {
    @ObservedObject var vm: NexoViewModel
    @State private var showingCreateModal = false
    @State private var showingCategoryManager = false
    @State private var showingAuthModal = false
    @State private var showingMapView = false
    
    @State private var selectedCampaignForDonate: CampaignItem?
    @State private var selectedCampaignForDetail: CampaignItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Superior Limpo
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
                        Button {
                            showingMapView = true
                        } label: {
                            Image(systemName: "map")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        
                        Button {
                            showingCategoryManager = true
                        } label: {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        
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
                
                Divider()
                
                // Mensagens de Feedback
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
                
                // Stories de Categorias no Topo
                InstagramStoriesBarView(
                    categories: vm.categories,
                    selectedCategoryId: vm.selectedCategoryId
                ) { catId in
                    vm.selectedCategoryId = catId
                    Task { await vm.fetchCampaigns() }
                }
                .padding(.vertical, 4)
                
                // FEED VERTICAL CONTÍNUO COM O DESIGN EXATO DA IMAGEM
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(vm.campaigns) { campaign in
                            VakinhaVisualCardView(
                                campaign: campaign,
                                isFavorite: vm.isFavorite(campaignId: campaign.id),
                                onFavoriteToggle: {
                                    Task { await vm.toggleFavorite(campaignId: campaign.id) }
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
            .navigationDestination(item: $selectedCampaignForDetail) { cmp in
                CampaignDetailView(vm: vm, campaign: cmp)
            }
        }
    }
}
