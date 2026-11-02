import SwiftUI

// MARK: - Painel do Criador (CRUD 1: Campanhas do Criador, CRUD 9: Solicitações de Saque)
struct CreatorDashboardView: View {
    @ObservedObject var vm: NexoViewModel
    
    var myCampaigns: [CampaignItem] {
        guard let user = vm.currentUser else { return [] }
        return vm.campaigns.filter { $0.creatorId == user.id }
    }
    
    var totalRaised: Double {
        myCampaigns.reduce(0) { $0 + $1.currentAmount }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Card de Resumo (Design 60/30/10)
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Painel Financeiro do Criador")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.vakinhaBlue)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Arrecadado")
                                    .font(.caption)
                                    .foregroundColor(.vakinhaBlackMuted)
                                Text("R$ \(String(format: "%.2f", totalRaised))")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.vakinhaBlue)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Minhas Campanhas")
                                    .font(.caption)
                                    .foregroundColor(.vakinhaBlackMuted)
                                Text("\(myCampaigns.count)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.vakinhaBlack)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Minhas Vaquinhas
                Section("Minhas Campanhas no PostgreSQL (\(myCampaigns.count))") {
                    if myCampaigns.isEmpty {
                        Text("Você ainda não criou nenhuma vaquinha.")
                            .font(.subheadline)
                            .foregroundColor(.vakinhaBlackMuted)
                    } else {
                        ForEach(myCampaigns) { campaign in
                            NavigationLink {
                                CampaignDetailView(vm: vm, campaign: campaign)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(campaign.title)
                                        .font(.headline)
                                        .foregroundColor(.vakinhaBlack)
                                    ProgressView(value: campaign.progress)
                                        .tint(.vakinhaBlue)
                                    HStack {
                                        Text("R$ \(String(format: "%.2f", campaign.currentAmount)) de R$ \(String(format: "%.2f", campaign.goalAmount))")
                                            .font(.caption)
                                            .foregroundColor(.vakinhaBlackMuted)
                                        Spacer()
                                        Text(campaign.percentFormatted)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.vakinhaBlue)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                
                // CRUD 9: Solicitações de Saque
                Section("Solicitações de Transferência / PIX") {
                    if vm.withdrawals.isEmpty {
                        Text("Nenhum pedido de saque realizado.")
                            .font(.caption)
                            .foregroundColor(.vakinhaBlackMuted)
                    } else {
                        ForEach(vm.withdrawals) { wth in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(wth.campaignTitle ?? "Campanha")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.vakinhaBlack)
                                    Text("Chave PIX: \(wth.pixKey)")
                                        .font(.caption2)
                                        .foregroundColor(.vakinhaBlackMuted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("R$ \(String(format: "%.2f", wth.amount))")
                                        .font(.footnote)
                                        .fontWeight(.bold)
                                        .foregroundColor(.vakinhaBlue)
                                    Text(wth.status.uppercased())
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(wth.status == "aprovado" ? Color.vakinhaBlueLight : Color.orange.opacity(0.15))
                                        .foregroundColor(wth.status == "aprovado" ? .vakinhaBlue : .orange)
                                        .cornerRadius(4)
                                }
                            }
                            .swipeActions {
                                if wth.status == "em_analise" {
                                    Button(role: .destructive) {
                                        Task { await vm.deleteWithdrawal(id: wth.id) }
                                    } label: {
                                        Label("Cancelar", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Painel do Criador")
            .refreshable {
                await vm.fetchCampaigns()
                await vm.fetchWithdrawals()
            }
        }
    }
}
