import SwiftUI

struct FeedView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var campanhas: [Campanha] = []
    @State private var categorias: [Categoria] = []
    @State private var busca = ""
    @State private var categoria: Int?
    @State private var carregado = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if busca.isEmpty { destaque }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(titulo: "Todas", icone: "square.grid.2x2", selecionado: categoria == nil) { categoria = nil }
                        ForEach(categorias) { cat in
                            Chip(titulo: cat.nome, icone: EstiloCategoria(cat.nome).icone, selecionado: categoria == cat.id) {
                                categoria = cat.id
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.horizontal, -16)
                .sensoryFeedback(.selection, trigger: categoria)

                if !carregado {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if campanhas.isEmpty {
                    ContentUnavailableView("Nenhuma campanha encontrada", systemImage: "magnifyingglass",
                                           description: Text("Tente outra busca ou categoria."))
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(campanhas) { c in
                            NavigationLink(value: c) { CampanhaCard(c: c) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("NEXO")
        .navigationDestination(for: Campanha.self) { CampanhaDetalhe(c: $0) }
        .searchable(text: $busca, prompt: "Buscar causas ou cidades")
        .task(id: "\(busca)|\(categoria ?? 0)") { await carregar() }
        .refreshable { await carregar() }
        .animation(.snappy, value: campanhas.map(\.id))
    }

    var destaque: some View {
        HStack(spacing: 14) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white, .green)
                .symbolEffect(.pulse)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sua Doação, Seu Impacto").font(.headline)
                Text("Pequenas doações, grandes transformações.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    func carregar() async {
        if categorias.isEmpty { categorias = await vm.tentar { try await vm.categorias() } ?? [] }
        campanhas = await vm.tentar { try await vm.feed(busca: busca, categoria: categoria) } ?? []
        carregado = true
    }
}

#Preview {
    NavigationStack { FeedView() }.environmentObject(AppViewModel.preview()).tint(.green)
}
