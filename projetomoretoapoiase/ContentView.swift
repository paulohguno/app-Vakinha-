import SwiftUI

struct ContentView: View {
    @StateObject private var vm = NexoViewModel.shared
    
    var body: some View {
        TabView {
            // Tab 1: Feed Principal de Campanhas
            CampaignsFeedView(vm: vm)
                .tabItem {
                    Label("Vaquinhas", systemImage: "sparkles")
                }
            
            // Tab 2: Minhas Doações & Favoritos
            DonorHistoryView(vm: vm)
                .tabItem {
                    Label("Minhas Doações", systemImage: "heart.fill")
                }
            
            // Tab 3: Painel do Criador & Saques
            CreatorDashboardView(vm: vm)
                .tabItem {
                    Label("Criador", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            // Tab 4: Moderação de Denúncias & Selos de ONG
            AdminONGView(vm: vm)
                .tabItem {
                    Label("Admin / ONG", systemImage: "shield.checkerboard")
                }
            
            // Tab 5: Minha Conta, Permissões & Notificações
            ProfileView(vm: vm)
                .tabItem {
                    Label("Perfil", systemImage: "person.crop.circle")
                }
                .badge(vm.notifications.filter { !$0.isRead }.count)
        }
        .tint(.vakinhaBlue) // 30% Azul nos seletores e abas
        .onAppear {
            vm.locationManager.requestPermission()
            vm.notificationManager.requestPermission()
        }
    }
}

#Preview {
    ContentView()
}
