import SwiftUI

struct MinhasCampanhasView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var campanhas: [Campanha] = []
    @State private var nova = false

    var total: Double { campanhas.reduce(0) { $0 + $1.arrecadado } }

    var body: some View {
        List {
            if !campanhas.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        Metrica(titulo: "Arrecadado", valor: total.formatted(brl), icone: "chart.line.uptrend.xyaxis", cor: .green)
                        Metrica(titulo: "Apoiadores", valor: "\(campanhas.reduce(0) { $0 + $1.doadores })", icone: "person.2.fill", cor: .blue)
                        Metrica(titulo: "Ativas", valor: "\(campanhas.filter { $0.status == "ativa" }.count)", icone: "bolt.heart.fill", cor: .orange)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                Section("Suas campanhas") {
                    ForEach(campanhas) { c in NavigationLink(value: c) { CampanhaRow(c: c) } }
                }
            }
        }
        .overlay {
            if campanhas.isEmpty {
                ContentUnavailableView {
                    Label("Nenhuma campanha", systemImage: "rectangle.stack.badge.plus")
                } description: {
                    Text("Crie sua primeira vaquinha em menos de 5 minutos.")
                } actions: {
                    Button("Criar campanha") { nova = true }.buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Minhas campanhas")
        .navigationDestination(for: Campanha.self) { CampanhaDetalhe(c: $0) }
        .toolbar {
            Button { nova = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                .accessibilityLabel("Nova campanha")
        }
        .sheet(isPresented: $nova, onDismiss: { Task { await carregar() } }) {
            NavigationStack { CampanhaForm(c: nil) }
        }
        .task { await carregar() }
        .refreshable { await carregar() }
    }

    func carregar() async { campanhas = await vm.tentar { try await vm.minhasCampanhas() } ?? [] }
}

struct CampanhaForm: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let c: Campanha?
    @State private var passo = 0
    @State private var titulo = ""
    @State private var descricao = ""
    @State private var meta = 1000.0
    @State private var cidade = ""
    @State private var categoria: Int?
    @State private var categorias: [Categoria] = []
    @State private var publicada = false

    let passos = ["Sobre a causa", "Categoria e local", "Meta", "Revisão"]

    var podeAvancar: Bool {
        switch passo {
        case 0: !titulo.isEmpty && !descricao.isEmpty
        case 1: categoria != nil && !cidade.isEmpty
        case 2: meta > 0
        default: true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Passo \(passo + 1) de \(passos.count)").font(.caption.bold()).foregroundStyle(.green)
                    Spacer()
                    Text(passos[passo]).font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: Double(passo + 1), total: Double(passos.count)).tint(.green)
            }
            .padding()

            Form {
                switch passo {
                case 0:
                    Section {
                        TextField("Ex.: Cirurgia do Seu João", text: $titulo)
                    } header: { Text("Título") } footer: { Text("Um título curto e claro atrai mais apoiadores.") }
                    Section("Conte a história") {
                        TextField("Por que você precisa de ajuda?", text: $descricao, axis: .vertical).lineLimit(5...12)
                    }
                case 1:
                    Section("Categoria") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                            ForEach(categorias) { cat in
                                let e = EstiloCategoria(cat.nome)
                                Button { categoria = cat.id } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: e.icone).font(.title2)
                                        Text(cat.nome).font(.caption).multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 70)
                                    .foregroundStyle(categoria == cat.id ? .white : e.cor)
                                    .background(categoria == cat.id ? AnyShapeStyle(e.cor) : AnyShapeStyle(e.cor.opacity(0.12)),
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                        .sensoryFeedback(.selection, trigger: categoria)
                    }
                    Section("Localização") {
                        Label {
                            TextField("Cidade - UF", text: $cidade)
                        } icon: { Image(systemName: "mappin.and.ellipse").foregroundStyle(.green) }
                    }
                case 2:
                    Section {
                        VStack(spacing: 12) {
                            Text(meta, format: brl).font(.system(.largeTitle, design: .rounded).bold()).contentTransition(.numericText())
                            Slider(value: $meta, in: 100...50_000, step: 100).tint(.green)
                        }
                        .padding(.vertical)
                        LabeledContent("Valor exato") {
                            TextField("Meta", value: $meta, format: brl).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    } header: { Text("Quanto você precisa?") } footer: {
                        Text("Você pode solicitar o saque do valor arrecadado a qualquer momento.")
                    }
                default:
                    Section("Revise antes de publicar") {
                        LabeledContent("Título", value: titulo)
                        LabeledContent("Categoria", value: categorias.first { $0.id == categoria }?.nome ?? "-")
                        LabeledContent("Cidade", value: cidade)
                        LabeledContent("Meta", value: meta.formatted(brl))
                    }
                    Section("História") { Text(descricao) }
                }
            }
            .animation(.snappy, value: passo)

            HStack {
                if passo > 0 {
                    Button { passo -= 1 } label: { Text("Voltar").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).controlSize(.large)
                }
                Button {
                    if passo < passos.count - 1 { passo += 1 } else { salvar() }
                } label: {
                    Text(passo < passos.count - 1 ? "Continuar" : (c == nil ? "Publicar campanha" : "Salvar alterações"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!podeAvancar)
            }
            .padding()
            .background(.bar)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(c == nil ? "Nova campanha" : "Editar campanha")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
        .sensoryFeedback(.success, trigger: publicada)
        .task {
            categorias = await vm.tentar { try await vm.categorias() } ?? []
            if let c {
                titulo = c.titulo; descricao = c.descricao; meta = c.meta; cidade = c.cidade
                categoria = categorias.first { $0.nome == c.categoria }?.id
            }
        }
    }

    func salvar() {
        Task {
            if await vm.tentar({ try await vm.salvarCampanha(id: c?.id, titulo: titulo, descricao: descricao,
                                                             meta: meta, cidade: cidade, categoria: categoria) }) != nil {
                publicada = true
                dismiss()
            }
        }
    }
}

#Preview("Minhas campanhas") {
    NavigationStack { MinhasCampanhasView() }.environmentObject(AppViewModel.preview(logado: "ana@nexo.com")).tint(.green)
}

#Preview("Nova campanha") {
    NavigationStack { CampanhaForm(c: nil) }.environmentObject(AppViewModel.preview(logado: "ana@nexo.com")).tint(.green)
}
