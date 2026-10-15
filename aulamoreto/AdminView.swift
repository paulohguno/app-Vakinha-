import SwiftUI

struct AdminView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var fila = AppViewModel.Fila.denuncias
    @State private var itens: [Item] = []
    @State private var metricas: Metricas?

    var status: [String] {
        switch fila {
        case .denuncias: ["em_analise", "resolvida", "arquivada"]
        case .saques: ["em_analise", "aprovado", "rejeitado"]
        case .verificacoes_ong: ["aprovado", "reprovado", "pendente_documento"]
        }
    }

    var icone: String {
        switch fila {
        case .denuncias: "flag.fill"
        case .saques: "banknote.fill"
        case .verificacoes_ong: "checkmark.seal.fill"
        }
    }

    var body: some View {
        List {
            if let m = metricas {
                Section {
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            Metrica(titulo: "Total arrecadado", valor: m.arrecadado.formatted(brl), icone: "chart.line.uptrend.xyaxis", cor: .green)
                            Metrica(titulo: "Campanhas ativas", valor: "\(m.campanhasAtivas)", icone: "bolt.heart.fill", cor: .orange)
                        }
                        GridRow {
                            Metrica(titulo: "Doações", valor: "\(m.doacoes)", icone: "heart.fill", cor: .pink)
                            Metrica(titulo: "Usuários", valor: "\(m.usuarios)", icone: "person.3.fill", cor: .blue)
                        }
                        GridRow {
                            Metrica(titulo: "Denúncias abertas", valor: "\(m.denunciasPendentes)", icone: "flag.fill", cor: .red)
                            Metrica(titulo: "Saques em análise", valor: "\(m.saquesPendentes)", icone: "banknote.fill", cor: .teal)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: { Text("Dashboard") }
            }

            Section {
                Picker("Fila", selection: $fila) {
                    Text("Denúncias").tag(AppViewModel.Fila.denuncias)
                    Text("Saques").tag(AppViewModel.Fila.saques)
                    Text("ONGs").tag(AppViewModel.Fila.verificacoes_ong)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                if itens.isEmpty {
                    ContentUnavailableView("Fila vazia", systemImage: "tray", description: Text("Nada pendente por aqui."))
                }
                ForEach(itens) { i in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icone).foregroundStyle(.secondary).frame(width: 24)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(i.titulo).font(.subheadline.bold()).lineLimit(1)
                                Spacer()
                                StatusBadge(status: i.status)
                            }
                            Text(i.detalhe).font(.caption).foregroundStyle(.secondary)
                            Menu {
                                ForEach(status, id: \.self) { s in
                                    Button(rotulo(s)) { acao { try await vm.mudarStatus(fila, id: i.id, s) } }
                                }
                            } label: {
                                Label("Alterar status", systemImage: "arrow.triangle.2.circlepath").font(.caption.bold())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions {
                        Button("Excluir", systemImage: "trash", role: .destructive) { acao { try await vm.excluir(fila, id: i.id) } }
                    }
                }
            } header: { Text("Fila de moderação") }
        }
        .navigationTitle("Admin")
        .task(id: fila) { await carregar() }
        .refreshable { await carregar() }
        .sensoryFeedback(.selection, trigger: fila)
    }

    func acao(_ f: @escaping () async throws -> Void) { Task { await vm.tentar(f); await carregar() } }

    func carregar() async {
        itens = await vm.tentar { try await vm.fila(fila) } ?? []
        metricas = await vm.tentar { try await vm.metricas() }
    }
}

#Preview {
    NavigationStack { AdminView() }.environmentObject(AppViewModel.preview(logado: "admin@nexo.com")).tint(.green)
}
