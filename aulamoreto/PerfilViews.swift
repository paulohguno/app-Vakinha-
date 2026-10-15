import SwiftUI

struct PerfilView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var editar = false
    @State private var ong = false
    @State private var sair = false

    var body: some View {
        if let u = vm.usuario {
            List {
                Section {
                    HStack(spacing: 16) {
                        Avatar(nome: u.nome, tamanho: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(u.nome).font(.title3.bold())
                                if u.verificado {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                                        .accessibilityLabel("Verificado")
                                }
                            }
                            Text(u.email).font(.subheadline).foregroundStyle(.secondary)
                            Text(rotulo(u.perfil)).font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.green.opacity(0.15), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 6)
                    Button("Editar perfil", systemImage: "pencil") { editar = true }
                }

                Section("Atividade") {
                    NavigationLink { HistoricoView() } label: {
                        item("Minhas doações", "heart.text.square.fill", .pink)
                    }
                    NavigationLink { FavoritosView() } label: {
                        item("Favoritos", "bookmark.fill", .orange)
                    }
                    NavigationLink { NotificacoesView() } label: {
                        item("Notificações", "bell.badge.fill", .red).badge(vm.naoLidas)
                    }
                }

                if !u.verificado {
                    Section {
                        Button { ong = true } label: { item("Solicitar selo de ONG", "checkmark.seal.fill", .green) }
                            .foregroundStyle(.primary)
                    } footer: {
                        Text("ONGs verificadas recebem um selo de confiança nas campanhas.")
                    }
                }

                Section("Privacidade") {
                    Label("Seus dados são tratados conforme a LGPD.", systemImage: "hand.raised.fill")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section {
                    Button("Sair da conta", role: .destructive) { sair = true }
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Perfil")
            .sheet(isPresented: $editar) { NavigationStack { EditarPerfilView() }.presentationDetents([.medium]) }
            .sheet(isPresented: $ong) {
                NavigationStack {
                    TextoSheet(titulo: "Verificação de ONG", placeholder: "Link do CNPJ ou estatuto da ONG", icone: "checkmark.seal") {
                        try await vm.solicitarVerificacao(documento: $0)
                    }
                }
                .presentationDetents([.medium])
            }
            .confirmationDialog("Deseja sair?", isPresented: $sair, titleVisibility: .visible) {
                Button("Sair", role: .destructive) { withAnimation { vm.usuario = nil } }
            }
        } else {
            LoginView()
        }
    }

    func item(_ titulo: String, _ icone: String, _ cor: Color) -> some View {
        Label {
            Text(titulo)
        } icon: {
            Image(systemName: icone)
                .font(.footnote).foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(cor.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

struct EditarPerfilView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var nome = ""

    var body: some View {
        Form {
            Section {
                HStack { Spacer(); Avatar(nome: nome.isEmpty ? "?" : nome, tamanho: 80); Spacer() }
                    .listRowBackground(Color.clear)
            }
            Section("Nome") { TextField("Seu nome", text: $nome).textContentType(.name) }
            Section("E-mail") { Text(vm.usuario?.email ?? "").foregroundStyle(.secondary) }
        }
        .navigationTitle("Editar perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    Task { if await vm.tentar({ try await vm.atualizarPerfil(nome: nome) }) != nil { dismiss() } }
                }
                .disabled(nome.isEmpty)
            }
        }
        .onAppear { nome = vm.usuario?.nome ?? "" }
    }
}

struct LoginView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var nome = ""
    @State private var email = ""
    @State private var senha = ""
    @State private var cadastro = false
    @FocusState private var foco: Campo?

    enum Campo { case nome, email, senha }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.white, .green)
                        .symbolEffect(.bounce, value: cadastro)
                    Text("NEXO").font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    Text("Pequenas doações, grandes transformações.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                VStack(spacing: 12) {
                    if cadastro {
                        campo("Nome completo", "person", text: $nome).focused($foco, equals: .nome).textContentType(.name)
                    }
                    campo("E-mail", "envelope", text: $email)
                        .focused($foco, equals: .email)
                        .keyboardType(.emailAddress).textContentType(.emailAddress).textInputAutocapitalization(.never)
                    HStack {
                        Image(systemName: "lock").foregroundStyle(.secondary).frame(width: 24)
                        SecureField("Senha", text: $senha).focused($foco, equals: .senha).textContentType(cadastro ? .newPassword : .password)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(action: entrar) {
                    Text(cadastro ? "Criar conta" : "Entrar").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(email.isEmpty || senha.isEmpty || (cadastro && nome.isEmpty))

                HStack {
                    VStack { Divider() }
                    Text("ou").font(.caption).foregroundStyle(.secondary)
                    VStack { Divider() }
                }

                VStack(spacing: 10) {
                    Button { demo("bruno@nexo.com") } label: {
                        Label("Continuar com a Apple", systemImage: "apple.logo").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.primary).controlSize(.large)
                    Button { demo("ana@nexo.com") } label: {
                        Label("Continuar com o Google", systemImage: "globe").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(.primary).controlSize(.large)
                }

                Button(cadastro ? "Já tenho conta" : "Não tem conta? Cadastre-se") {
                    withAnimation(.snappy) { cadastro.toggle() }
                }
                .font(.subheadline.weight(.semibold))

                if !cadastro {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach([("ana@nexo.com", "Criadora"), ("bruno@nexo.com", "Doador"),
                                     ("ong@nexo.com", "ONG"), ("admin@nexo.com", "Admin")], id: \.0) { e, perfil in
                                Button { demo(e) } label: {
                                    HStack {
                                        Text(perfil).font(.subheadline.bold())
                                        Spacer()
                                        Text(e).font(.caption).foregroundStyle(.secondary)
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } label: {
                        Label("Contas de teste (senha 123)", systemImage: "testtube.2").font(.caption)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .onSubmit { foco = foco == .nome ? .email : foco == .email ? .senha : nil }
        .onChange(of: vm.usuario) { _, novo in if novo != nil { dismiss() } }
        .sensoryFeedback(.success, trigger: vm.usuario)
    }

    func campo(_ titulo: String, _ icone: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icone).foregroundStyle(.secondary).frame(width: 24)
            TextField(titulo, text: text)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    func entrar() {
        Task {
            let ok = await vm.tentar {
                cadastro ? try await vm.cadastrar(nome: nome, email: email, senha: senha)
                         : try await vm.login(email: email, senha: senha)
            }
            if ok == false { vm.erro = "E-mail ou senha inválidos." }
        }
    }

    func demo(_ email: String) {
        Task { await vm.tentar { try await vm.login(email: email, senha: "123") } }
    }
}

struct HistoricoView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var doacoes: [Doacao] = []

    var body: some View {
        List {
            if !doacoes.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total doado").font(.subheadline).foregroundStyle(.secondary)
                        Text(doacoes.reduce(0) { $0 + $1.valor }, format: brl).font(.system(.largeTitle, design: .rounded).bold())
                        Text("em \(doacoes.count) doações").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            Section {
                ForEach(doacoes) { d in
                    HStack(spacing: 12) {
                        Image(systemName: d.metodo == "pix" ? "qrcode" : "creditcard.fill")
                            .foregroundStyle(.green)
                            .frame(width: 36, height: 36)
                            .background(Color.green.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.campanha).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(d.data.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(d.valor, format: brl).font(.subheadline.bold())
                    }
                }
            }
        }
        .overlay {
            if doacoes.isEmpty {
                ContentUnavailableView("Nenhuma doação", systemImage: "heart.slash",
                                       description: Text("Suas contribuições aparecerão aqui."))
            }
        }
        .navigationTitle("Minhas doações")
        .task { doacoes = await vm.tentar { try await vm.historico() } ?? [] }
    }
}

struct FavoritosView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var campanhas: [Campanha] = []

    var body: some View {
        List(campanhas) { c in NavigationLink(value: c) { CampanhaRow(c: c) } }
            .overlay {
                if campanhas.isEmpty {
                    ContentUnavailableView("Sem favoritos", systemImage: "bookmark",
                                           description: Text("Toque no coração de uma campanha para salvá-la aqui."))
                }
            }
            .navigationTitle("Favoritos")
            .navigationDestination(for: Campanha.self) { CampanhaDetalhe(c: $0) }
            .task { campanhas = await vm.tentar { try await vm.favoritos() } ?? [] }
    }
}

struct NotificacoesView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var itens: [Item] = []

    var body: some View {
        List(itens) { n in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icone(n.titulo))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.green.gradient, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(n.titulo).font(.subheadline).fontWeight(n.status == "nova" ? .semibold : .regular)
                    Text(n.detalhe).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if n.status == "nova" { Circle().fill(.blue).frame(width: 10, height: 10).accessibilityLabel("Não lida") }
            }
            .padding(.vertical, 4)
        }
        .overlay {
            if itens.isEmpty {
                ContentUnavailableView("Tudo em dia", systemImage: "bell.slash", description: Text("Você não tem notificações."))
            }
        }
        .navigationTitle("Notificações")
        .task { itens = await vm.tentar { try await vm.notificacoes() } ?? [] }
        .onDisappear { Task { await vm.tentar { try await vm.marcarLidas() } } }
    }

    func icone(_ texto: String) -> String {
        if texto.contains("doação") { return "heart.fill" }
        if texto.contains("Saque") { return "banknote.fill" }
        if texto.contains("Verificação") { return "checkmark.seal.fill" }
        return "megaphone.fill"
    }
}

#Preview("Perfil") {
    NavigationStack { PerfilView() }.environmentObject(AppViewModel.preview(logado: "ana@nexo.com")).tint(.green)
}

#Preview("Login") {
    NavigationStack { LoginView() }.environmentObject(AppViewModel.preview()).tint(.green)
}
