import SwiftUI

// MARK: - Painel do Administrador & ONG (CRUD 5: Denúncias, CRUD 6: Verificação de ONG, CRUD 9: Aprovar Saques)
struct AdminONGView: View {
    @ObservedObject var vm: NexoViewModel
    @State private var showingSubmitNGOModal = false
    
    var body: some View {
        NavigationStack {
            List {
                // Perfil ONG - Solicitar Selo
                Section("Selo de Verificação de ONG (CRUD)") {
                    Button {
                        showingSubmitNGOModal = true
                    } label: {
                        Label("Solicitar Homologação de Selo de ONG", systemImage: "checkmark.seal.fill")
                            .foregroundColor(.vakinhaBlue)
                            .fontWeight(.semibold)
                    }
                    
                    if vm.verifications.isEmpty {
                        Text("Nenhuma verificação cadastrada.")
                            .font(.caption)
                            .foregroundColor(.vakinhaBlackMuted)
                    } else {
                        ForEach(vm.verifications) { ver in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(ver.organizationName)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.vakinhaBlack)
                                    Spacer()
                                    Text(ver.status.uppercased())
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(ver.status == "aprovado" ? Color.vakinhaBlueLight : Color.orange.opacity(0.15))
                                        .foregroundColor(ver.status == "aprovado" ? .vakinhaBlue : .orange)
                                        .cornerRadius(4)
                                }
                                Text("CNPJ: \(ver.documentNumber)")
                                    .font(.caption)
                                    .foregroundColor(.vakinhaBlackMuted)
                                
                                HStack {
                                    Button("Aprovar") {
                                        Task { await vm.updateVerificationStatus(id: ver.id, status: "aprovado") }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.vakinhaBlue)
                                    
                                    Button("Rejeitar") {
                                        Task { await vm.updateVerificationStatus(id: ver.id, status: "rejeitado") }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                                .padding(.top, 4)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.deleteVerification(id: ver.id) }
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                // Moderação de Denúncias (CRUD 5)
                Section("Moderação de Denúncias (\(vm.reports.count))") {
                    if vm.reports.isEmpty {
                        Text("Nenhuma denúncia pendente.")
                            .font(.caption)
                            .foregroundColor(.vakinhaBlackMuted)
                    } else {
                        ForEach(vm.reports) { rep in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(rep.campaignTitle ?? "Campanha denunciada")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.vakinhaBlack)
                                    Spacer()
                                    Text(rep.status.uppercased())
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(4)
                                        .background(Color.red.opacity(0.12))
                                        .foregroundColor(.red)
                                        .cornerRadius(4)
                                }
                                Text("Motivo: \(rep.reason)")
                                    .font(.caption)
                                    .foregroundColor(.vakinhaBlackMuted)
                                
                                HStack {
                                    Button("Resolver") {
                                        Task { await vm.updateReportStatus(id: rep.id, status: "resolvida") }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.vakinhaBlue)
                                    
                                    Button("Arquivar") {
                                        Task { await vm.updateReportStatus(id: rep.id, status: "arquivada") }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.secondary)
                                }
                                .padding(.top, 4)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.deleteReport(id: rep.id) }
                                } label: {
                                    Label("Remover", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                // Moderação de Saques Financeiros (CRUD 9 - Admin)
                Section("Aprovação de Saques no PostgreSQL") {
                    if vm.withdrawals.isEmpty {
                        Text("Nenhum pedido de saque em análise.")
                            .font(.caption)
                            .foregroundColor(.vakinhaBlackMuted)
                    } else {
                        ForEach(vm.withdrawals) { wth in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(wth.campaignTitle ?? "Campanha")
                                        .font(.subheadline)
                                        .foregroundColor(.vakinhaBlack)
                                    Spacer()
                                    Text("R$ \(String(format: "%.2f", wth.amount))")
                                        .font(.footnote)
                                        .fontWeight(.bold)
                                        .foregroundColor(.vakinhaBlue)
                                }
                                Text("Chave PIX: \(wth.pixKey)")
                                    .font(.caption2)
                                    .foregroundColor(.vakinhaBlackMuted)
                                
                                HStack {
                                    Button("Aprovar Pagamento") {
                                        Task { await vm.updateWithdrawalStatus(id: wth.id, status: "aprovado") }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.vakinhaBlue)
                                    
                                    Button("Recusar") {
                                        Task { await vm.updateWithdrawalStatus(id: wth.id, status: "rejeitado") }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Admin & Moderação")
            .refreshable {
                await vm.fetchVerifications()
                await vm.fetchReports()
                await vm.fetchWithdrawals()
            }
            .sheet(isPresented: $showingSubmitNGOModal) {
                SubmitNGOVerificationSheet(vm: vm)
            }
        }
    }
}

// MARK: - Sheet de Solicitar Selo ONG (CRUD 6: Create)
struct SubmitNGOVerificationSheet: View {
    @ObservedObject var vm: NexoViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var orgName = ""
    @State private var docNumber = ""
    @State private var docsUrl = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Identificação da Organização") {
                    TextField("Nome Oficial / Razão Social", text: $orgName)
                    TextField("CNPJ", text: $docNumber)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Link dos Documentos (Estatuto Social)", text: $docsUrl)
                }
                
                Section {
                    Button("Enviar Documentos") {
                        guard !orgName.isEmpty && !docNumber.isEmpty else { return }
                        Task {
                            let ok = await vm.submitNGOVerification(orgName: orgName, docNumber: docNumber, docsUrl: docsUrl)
                            if ok { dismiss() }
                        }
                    }
                    .buttonStyle(VakinhaPrimaryButtonStyle())
                    .disabled(orgName.isEmpty || docNumber.isEmpty)
                }
            }
            .navigationTitle("Homologar ONG")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
