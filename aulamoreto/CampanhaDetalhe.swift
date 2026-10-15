import SwiftUI

struct CampanhaDetalhe: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State var c: Campanha
    @State private var mensagens: [Post] = []
    @State private var novidades: [Post] = []
    @State private var favorito = false
    @State private var texto = ""
    @State private var aba = Aba.sobre
    @State private var sheet: Sheet?
    @State private var confirmarExclusao = false
    @State private var confirmarSaque = false
    @State private var saqueEnviado = false

    enum Aba: String, CaseIterable { case sobre = "Sobre", novidades = "Novidades", mural = "Mural" }
    enum Sheet: String, Identifiable { case doar, denunciar, novidade, editar, login; var id: String { rawValue } }
    var dono: Bool { vm.usuario?.id == c.criadorId }
    var admin: Bool { vm.usuario?.perfil == "admin" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CapaCampanha(c: c, altura: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    HStack { StatusBadge(status: c.status); Spacer() }
                    Text(c.titulo).font(.title2.bold())
                    HStack(spacing: 10) {
                        Avatar(nome: c.criador, tamanho: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                Text(c.criador).font(.subheadline.weight(.semibold))
                                if c.criadorVerificado {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                                        .accessibilityLabel("ONG verificada")
                                }
                            }
                            Label(c.cidade, systemImage: "mappin").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(spacing: 14) {
                    Progresso(c: c)
                    Divider()
                    HStack {
                        estatistica("\(c.doadores)", "apoiadores", "person.2.fill")
                        Divider().frame(height: 32)
                        estatistica("\(novidades.count)", "novidades", "megaphone.fill")
                        Divider().frame(height: 32)
                        estatistica("\(mensagens.count)", "mensagens", "bubble.left.fill")
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if dono { gestao }

                Picker("Seção", selection: $aba) {
                    ForEach(Aba.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                switch aba {
                case .sobre: Text(c.descricao).font(.body).frame(maxWidth: .infinity, alignment: .leading)
                case .novidades: listaNovidades
                case .mural: mural
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if c.status == "ativa" && !dono {
                Button { sheet = vm.usuario == nil ? .login : .doar } label: {
                    Label("Doar agora", systemImage: "heart.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: URL(string: "https://nexo.app/campanha/\(c.id)")!,
                          subject: Text(c.titulo),
                          message: Text("Apoie \"\(c.titulo)\" no NEXO 💚"))
                if vm.usuario != nil {
                    Button {
                        favorito.toggle()
                        let f = favorito
                        acao { try await vm.alternarFavorito(c, f) }
                    } label: {
                        Image(systemName: favorito ? "heart.fill" : "heart")
                            .foregroundStyle(favorito ? .pink : .accentColor)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .sensoryFeedback(.impact, trigger: favorito)
                    .accessibilityLabel(favorito ? "Remover dos favoritos" : "Favoritar")
                    if !dono {
                        Menu {
                            Button("Denunciar campanha", systemImage: "flag", role: .destructive) { sheet = .denunciar }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
        }
        .sheet(item: $sheet, onDismiss: { Task { await carregar() } }) { s in
            NavigationStack {
                switch s {
                case .doar: DoarView(c: c)
                case .denunciar:
                    TextoSheet(titulo: "Denunciar", placeholder: "Descreva o problema encontrado", icone: "flag.fill") {
                        try await vm.denunciar(c, motivo: $0)
                    }
                case .novidade:
                    TextoSheet(titulo: "Nova novidade", placeholder: "Conte aos apoiadores o que aconteceu", icone: "megaphone.fill", anexo: true) {
                        try await vm.publicarNovidade(c, $0, anexo: $1)
                    }
                case .editar: CampanhaForm(c: c)
                case .login: LoginView()
                }
            }
            .presentationDetents(s == .doar || s == .editar || s == .login ? [.large] : [.medium, .large])
        }
        .confirmationDialog("Excluir esta campanha?", isPresented: $confirmarExclusao, titleVisibility: .visible) {
            Button("Excluir", role: .destructive) {
                Task { if await vm.tentar({ try await vm.excluir(c) }) != nil { dismiss() } }
            }
        } message: { Text("Essa ação não pode ser desfeita.") }
        .alert("Solicitar saque de \(c.arrecadado, format: brl)?", isPresented: $confirmarSaque) {
            Button("Cancelar", role: .cancel) {}
            Button("Solicitar") { acao { try await vm.solicitarSaque(c); saqueEnviado = true } }
        } message: { Text("O pedido será analisado após a validação dos seus documentos.") }
        .sensoryFeedback(.success, trigger: saqueEnviado)
        .task { await carregar() }
    }

    func estatistica(_ valor: String, _ titulo: String, _ icone: String) -> some View {
        VStack(spacing: 2) {
            Text(valor).font(.headline)
            Label(titulo, systemImage: icone).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    var gestao: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Painel do criador", systemImage: "slider.horizontal.3").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    botaoGestao("Editar", "pencil") { sheet = .editar }
                    botaoGestao("Novidade", "megaphone") { sheet = .novidade }
                    if c.status == "ativa" {
                        botaoGestao("Pausar", "pause.circle") { acao { try await vm.mudarStatus(c, "pausada") } }
                    } else {
                        botaoGestao("Reativar", "play.circle") { acao { try await vm.mudarStatus(c, "ativa") } }
                    }
                    if c.status != "encerrada" {
                        botaoGestao("Encerrar", "stop.circle") { acao { try await vm.mudarStatus(c, "encerrada") } }
                    }
                    botaoGestao("Saque", "banknote") { confirmarSaque = true }.disabled(c.arrecadado <= 0)
                    botaoGestao("Excluir", "trash", cor: .red) { confirmarExclusao = true }
                }
            }
            if saqueEnviado {
                Label("Saque solicitado. Acompanhe pelas notificações.", systemImage: "checkmark.circle.fill")
                    .font(.footnote).foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    func botaoGestao(_ titulo: String, _ icone: String, cor: Color = .green, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            VStack(spacing: 6) {
                Image(systemName: icone).font(.title3)
                Text(titulo).font(.caption)
            }
            .frame(width: 72, height: 64)
        }
        .buttonStyle(.bordered)
        .tint(cor)
    }

    @ViewBuilder var listaNovidades: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dono {
                Button { sheet = .novidade } label: {
                    Label("Publicar novidade", systemImage: "plus.bubble").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
            if novidades.isEmpty {
                ContentUnavailableView("Sem novidades", systemImage: "megaphone",
                                       description: Text("As atualizações do criador aparecem aqui."))
            }
            ForEach(novidades) { n in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Atualização", systemImage: "megaphone.fill").font(.caption.bold()).foregroundStyle(.green)
                        Spacer()
                        Text(n.data, format: .relative(presentation: .named)).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(n.texto)
                    if let url = URL(string: n.autor), !n.autor.isEmpty {
                        Link(destination: url) { Label("Ver anexo", systemImage: "paperclip") }.font(.subheadline)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contextMenu {
                    if dono { Button("Excluir", systemImage: "trash", role: .destructive) { acao { try await vm.excluirNovidade(n.id) } } }
                }
            }
        }
    }

    @ViewBuilder var mural: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.usuario != nil {
                HStack(alignment: .bottom) {
                    TextField("Deixe uma mensagem de apoio", text: $texto, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Button {
                        let t = texto; texto = ""
                        acao { try await vm.enviarMensagem(c, t) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                    }
                    .disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Enviar mensagem")
                }
            }
            if mensagens.isEmpty {
                ContentUnavailableView("Mural vazio", systemImage: "bubble.left.and.bubble.right",
                                       description: Text("Seja o primeiro a deixar uma mensagem de apoio."))
            }
            ForEach(mensagens) { m in
                HStack(alignment: .top, spacing: 10) {
                    Avatar(nome: m.autor, tamanho: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(m.autor).font(.subheadline.bold())
                            Spacer()
                            Text(m.data, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(m.texto)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .contextMenu {
                    if admin || m.autor == vm.usuario?.nome {
                        Button("Excluir", systemImage: "trash", role: .destructive) { acao { try await vm.excluirMensagem(m.id) } }
                    }
                }
            }
        }
    }

    func acao(_ f: @escaping () async throws -> Void) {
        Task { await vm.tentar(f); await carregar() }
    }

    func carregar() async {
        if let atual = await vm.tentar({ try await vm.feed(busca: "", categoria: nil) + vm.minhasCampanhas() })?
            .first(where: { $0.id == c.id }) { c = atual }
        mensagens = await vm.tentar { try await vm.mensagens(c) } ?? []
        novidades = await vm.tentar { try await vm.novidades(c) } ?? []
        if vm.usuario != nil { favorito = await vm.tentar { try await vm.isFavorito(c) } ?? false }
    }
}

struct DoarView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let c: Campanha
    @State private var valor = 50.0
    @State private var metodo = "pix"
    @State private var numero = ""
    @State private var validade = ""
    @State private var cvv = ""
    @State private var nomeCartao = ""
    @State private var processando = false
    @State private var ok = false
    @State private var copiado = false

    let sugestoes: [Double] = [20, 50, 100, 200]
    var cartaoValido: Bool { metodo == "pix" || (numero.count >= 13 && validade.count >= 4 && cvv.count >= 3 && !nomeCartao.isEmpty) }

    var body: some View {
        Group {
            if ok { confirmacao } else { formulario }
        }
        .navigationTitle(ok ? "" : "Doar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !ok { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
        }
        .sensoryFeedback(.success, trigger: ok)
    }

    var formulario: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    CapaCampanha(c: c, altura: 48).frame(width: 48).clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading) {
                        Text(c.titulo).font(.headline)
                        Text("por \(c.criador)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Valor da doação") {
                HStack {
                    ForEach(sugestoes, id: \.self) { v in
                        Button { valor = v } label: {
                            Text(v, format: brl.precision(.fractionLength(0))).font(.subheadline.bold()).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(valor == v ? .green : .secondary)
                    }
                }
                .sensoryFeedback(.selection, trigger: valor)
                LabeledContent("Outro valor") {
                    TextField("Valor", value: $valor, format: brl).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
            }
            Section("Forma de pagamento") {
                Picker("Pagamento", selection: $metodo) {
                    Label("Pix", systemImage: "qrcode").tag("pix")
                    Label("Cartão", systemImage: "creditcard").tag("cartao")
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                if metodo == "pix" {
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 110))
                            .padding()
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.black)
                        Button {
                            UIPasteboard.general.string = "00020126nexo.pix.\(c.id)"
                            copiado = true
                        } label: {
                            Label(copiado ? "Código copiado" : "Copiar código Pix", systemImage: copiado ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .sensoryFeedback(.success, trigger: copiado)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    TextField("Número do cartão", text: $numero).keyboardType(.numberPad).textContentType(.creditCardNumber)
                    TextField("Nome impresso", text: $nomeCartao).textContentType(.name)
                    HStack {
                        TextField("Validade (MM/AA)", text: $validade).keyboardType(.numbersAndPunctuation)
                        Divider()
                        SecureField("CVV", text: $cvv).keyboardType(.numberPad)
                    }
                }
            }
            Section {
                Label("Pagamento seguro. O NEXO não armazena dados do cartão.", systemImage: "lock.shield.fill")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                processando = true
                Task {
                    ok = await vm.tentar { try await vm.doar(c, valor: valor, metodo: metodo) } != nil
                    processando = false
                }
            } label: {
                Group {
                    if processando { ProgressView().tint(.white) }
                    else { Text("Doar \(valor, format: brl)") }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(valor <= 0 || !cartaoValido || processando)
            .padding()
            .background(.bar)
        }
    }

    var confirmacao: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 90))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: ok)
            Text("Doação confirmada!").font(.title.bold())
            Text("Você doou \(valor, format: brl) para \"\(c.titulo)\". Obrigado por transformar vidas 💚")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Spacer()
            ShareLink(item: URL(string: "https://nexo.app/campanha/\(c.id)")!,
                      message: Text("Acabei de apoiar \"\(c.titulo)\" no NEXO. Ajude também!")) {
                Label("Compartilhar campanha", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).controlSize(.large)
            Button { dismiss() } label: { Text("Concluir").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding()
    }
}

struct TextoSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let titulo: String
    let placeholder: String
    let icone: String
    var anexo = false
    let enviar: (String, String) async throws -> Void
    @State private var texto = ""
    @State private var url = ""

    init(titulo: String, placeholder: String, icone: String, anexo: Bool = false,
         enviar: @escaping (String, String) async throws -> Void) {
        self.titulo = titulo; self.placeholder = placeholder; self.icone = icone; self.anexo = anexo; self.enviar = enviar
    }

    init(titulo: String, placeholder: String, icone: String, enviar: @escaping (String) async throws -> Void) {
        self.init(titulo: titulo, placeholder: placeholder, icone: icone) { t, _ in try await enviar(t) }
    }

    var body: some View {
        Form {
            Section {
                TextField(placeholder, text: $texto, axis: .vertical).lineLimit(4...10)
            } header: {
                Label(titulo, systemImage: icone)
            }
            if anexo {
                Section("Anexo (opcional)") {
                    TextField("Link da foto ou nota fiscal", text: $url)
                        .keyboardType(.URL).textInputAutocapitalization(.never)
                }
            }
        }
        .navigationTitle(titulo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enviar") {
                    Task { if await vm.tentar({ try await enviar(texto, url) }) != nil { dismiss() } }
                }
                .disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

#Preview {
    let vm = AppViewModel.preview(logado: "ana@nexo.com")
    return NavigationStack {
        CampanhaDetalhe(c: Campanha(id: 1, criadorId: 1, titulo: "Cirurgia do Seu João", descricao: "Seu João precisa de uma cirurgia.",
                                    cidade: "Chapecó - SC", status: "ativa", categoria: "Saúde", criador: "Ana Souza",
                                    meta: 15_000, arrecadado: 4_250, doadores: 2, criadorVerificado: false))
    }
    .environmentObject(vm).tint(.green)
}
