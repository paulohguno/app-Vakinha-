import SwiftUI

// MARK: - MainView (TabView Principal com Controle de Acesso Dinâmico por Papel - RBAC)
struct ContentView: View {
    @StateObject private var vm = NexoViewModel.shared
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Aba 1: Feed Principal de Vaquinhas (Acessível a todos os perfis)
            CampaignsFeedView(vm: vm)
                .tabItem {
                    Label("Vaquinhas", systemImage: "sparkles")
                }
                .tag(0)
            
            // Aba 2: Histórico de Doações & Favoritos (Acessível a todos os perfis)
            DonorHistoryView(vm: vm)
                .tabItem {
                    Label("Minhas Doações", systemImage: "heart.fill")
                }
                .tag(1)
            
            // Aba 3: Painel do Criador & Saques PIX (Restrita estritamente a Criador, ONG e Admin)
            if vm.canAccessCreatorDashboard {
                CreatorDashboardView(vm: vm)
                    .tabItem {
                        Label("Painel do Criador", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(2)
            }
            
            // Aba 4: Moderação & Homologação de ONG (Restrita estritamente a Admin e ONG)
            if vm.canAccessAdminONGPanel {
                AdminONGView(vm: vm)
                    .tabItem {
                        Label(
                            vm.isAdmin ? "Admin / Moderação" : "Homologação ONG",
                            systemImage: "shield.checkerboard"
                        )
                    }
                    .tag(3)
            }
            
            // Aba 5: Minha Conta, Troca de Perfil, Config de Servidor & Notificações
            ProfileView(vm: vm)
                .tabItem {
                    Label("Perfil", systemImage: "person.crop.circle")
                }
                .badge(vm.notifications.filter { !$0.isRead }.count)
                .tag(4)
        }
        .tint(.vakinhaBlue)
        .onChange(of: vm.currentUser?.role) { _, _ in
            // Caso o usuário troque para um perfil sem acesso à aba atual, volta com segurança ao Feed
            if selectedTab == 2 && !vm.canAccessCreatorDashboard {
                selectedTab = 0
            } else if selectedTab == 3 && !vm.canAccessAdminONGPanel {
                selectedTab = 0
            }
        }
        .onAppear {
            vm.locationManager.requestPermission()
            vm.notificationManager.requestPermission()
        }
    }
}

#Preview {
    ContentView()
}
