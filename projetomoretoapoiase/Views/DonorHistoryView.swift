import SwiftUI

// MARK: - Painel do Doador (Histórico de Doações e Favoritos)
struct DonorHistoryView: View {
    @ObservedObject var vm: NexoViewModel
    @State private var selectedSegment = 0 // 0: Doações, 1: Favoritos
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Visão", selection: $selectedSegment) {
                    Text("Minhas Doações (\(vm.donations.count))").tag(0)
                    Text("Favoritos (\(vm.favorites.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                if selectedSegment == 0 {
                    // CRUD 2: Histórico de Doações do PostgreSQL
                    List {
                        if vm.donations.isEmpty {
                            ContentUnavailableView("Nenhuma doação ainda", systemImage: "heart.slash", description: Text("Suas doações salvas no banco aparecerão aqui."))
                        } else {
                            ForEach(vm.donations) { don in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(don.campaignTitle ?? "Campanha Apoiada")
                                            .font(.headline)
                                            .foregroundColor(.vakinhaBlack)
                                        Spacer()
                                        Text("R$ \(String(format: "%.2f", don.amount))")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.vakinhaBlue)
                                    }
                                    
                                    HStack {
                                        Label(don.paymentMethod, systemImage: "creditcard.fill")
                                            .font(.caption)
                                            .foregroundColor(.vakinhaBlackMuted)
                                        Spacer()
                                        if let dt = don.createdAt {
                                            Text(dt.prefix(10))
                                                .font(.caption2)
                                                .foregroundColor(.vakinhaBlackMuted)
                                        }
                                    }
                                    
                                    if let msg = don.message, !msg.isEmpty {
                                        Text("\"\(msg)\"")
                                            .font(.caption)
                                            .italic()
                                            .foregroundColor(.vakinhaBlackMuted)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .refreshable {
                        await vm.fetchDonations()
                    }
                } else {
                    // CRUD 8: Favoritos do PostgreSQL
                    List {
                        if vm.favorites.isEmpty {
                            ContentUnavailableView("Sem Favoritos", systemImage: "heart.slash.fill", description: Text("Vaquinhas favoritadas serão sincronizadas com o PostgreSQL."))
                        } else {
                            ForEach(vm.favorites) { fav in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(fav.title ?? "Campanha")
                                            .font(.headline)
                                            .foregroundColor(.vakinhaBlack)
                                        if let loc = fav.locationName, !loc.isEmpty {
                                            Label(loc, systemImage: "mappin.circle.fill")
                                                .font(.caption2)
                                                .foregroundColor(.vakinhaBlue)
                                        }
                                    }
                                    Spacer()
                                    Button {
                                        Task { await vm.toggleFavorite(campaignId: fav.campaignId) }
                                    } label: {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task { await vm.toggleFavorite(campaignId: fav.campaignId) }
                                    } label: {
                                        Label("Remover", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        if let u = vm.currentUser {
                            await vm.fetchFavorites(userId: u.id)
                        }
                    }
                }
            }
            .background(Color.vakinhaBackground.ignoresSafeArea())
            .navigationTitle("Minhas Ações")
            .task {
                await vm.fetchDonations()
                if let u = vm.currentUser {
                    await vm.fetchFavorites(userId: u.id)
                }
            }
        }
    }
}
