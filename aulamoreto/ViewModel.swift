import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    static let shared = AppViewModel()
    @Published var usuario: Usuario?
    @Published var erro: String?

    private struct UsuarioRow { var id: Int; var nome, email, senha, perfil: String; var verificado: Bool }
    private struct CampanhaRow { var id, criadorId: Int; var categoriaId: Int?; var titulo, descricao, cidade, status: String; var meta: Double; var criada: Date }
    private struct DoacaoRow { var id, campanhaId, doadorId: Int; var valor: Double; var metodo: String; var data: Date }
    private struct NovidadeRow { var id, campanhaId: Int; var texto, anexo: String; var data: Date }
    private struct MensagemRow { var id, campanhaId, autorId: Int; var texto: String; var data: Date }
    private struct FilaRow { var id, refId: Int; var detalhe, status: String; var data: Date }
    private struct NotificacaoRow { var id, usuarioId: Int; var texto: String; var lida: Bool; var data: Date }

    private var usuarios: [UsuarioRow] = []
    private var cats: [Categoria] = []
    private var camps: [CampanhaRow] = []
    private var doacoes: [DoacaoRow] = []
    private var novs: [NovidadeRow] = []
    private var msgs: [MensagemRow] = []
    private var favs: Set<[Int]> = []
    private var denuncias: [FilaRow] = []
    private var saques: [FilaRow] = []
    private var verificacoes: [FilaRow] = []
    @Published private var notifs: [NotificacaoRow] = []

    var naoLidas: Int { notifs.filter { $0.usuarioId == usuario?.id && !$0.lida }.count }
    private var seq = 100
    private func nextId() -> Int { seq += 1; return seq }

    private init() { seed() }

    static func preview(logado email: String? = nil) -> AppViewModel {
        let vm = AppViewModel()
        if let u = vm.usuarios.first(where: { $0.email == email }) {
            vm.usuario = Usuario(id: u.id, nome: u.nome, email: u.email, perfil: u.perfil, verificado: u.verificado)
        }
        return vm
    }

    @discardableResult
    func tentar<T>(_ acao: () async throws -> T) async -> T? {
        do { return try await acao() } catch {
            erro = error.localizedDescription; return nil
        }
    }

    func login(email: String, senha: String) async throws -> Bool {
        guard let u = usuarios.first(where: { $0.email.lowercased() == email.lowercased() && $0.senha == senha }) else { return false }
        usuario = Usuario(id: u.id, nome: u.nome, email: u.email, perfil: u.perfil, verificado: u.verificado)
        return true
    }

    func cadastrar(nome: String, email: String, senha: String) async throws -> Bool {
        if usuarios.contains(where: { $0.email.lowercased() == email.lowercased() }) { throw ErroApp(errorDescription: "E-mail já cadastrado.") }
        usuarios.append(UsuarioRow(id: nextId(), nome: nome, email: email, senha: senha, perfil: "usuario", verificado: false))
        return try await login(email: email, senha: senha)
    }

    func atualizarPerfil(nome: String) async throws {
        guard let u = usuario, let i = usuarios.firstIndex(where: { $0.id == u.id }) else { return }
        usuarios[i].nome = nome
        usuario = Usuario(id: u.id, nome: nome, email: u.email, perfil: u.perfil, verificado: u.verificado)
    }

    func categorias() async throws -> [Categoria] { cats.sorted { $0.nome < $1.nome } }

    private func campanha(_ r: CampanhaRow) -> Campanha {
        Campanha(id: r.id, criadorId: r.criadorId, titulo: r.titulo, descricao: r.descricao, cidade: r.cidade, status: r.status,
                 categoria: cats.first { $0.id == r.categoriaId }?.nome ?? "",
                 criador: usuarios.first { $0.id == r.criadorId }?.nome ?? "",
                 meta: r.meta, arrecadado: doacoes.filter { $0.campanhaId == r.id }.reduce(0) { $0 + $1.valor },
                 doadores: Set(doacoes.filter { $0.campanhaId == r.id }.map(\.doadorId)).count,
                 criadorVerificado: usuarios.first { $0.id == r.criadorId }?.verificado ?? false)
    }

    func metricas() async throws -> Metricas {
        Metricas(arrecadado: doacoes.reduce(0) { $0 + $1.valor },
                 campanhasAtivas: camps.filter { $0.status == "ativa" }.count,
                 doacoes: doacoes.count,
                 usuarios: usuarios.count,
                 denunciasPendentes: denuncias.filter { $0.status == "pendente" || $0.status == "em_analise" }.count,
                 saquesPendentes: saques.filter { $0.status == "em_analise" }.count)
    }

    func feed(busca: String, categoria: Int?) async throws -> [Campanha] {
        camps.filter { c in
            c.status == "ativa"
                && (busca.isEmpty || c.titulo.localizedCaseInsensitiveContains(busca) || c.cidade.localizedCaseInsensitiveContains(busca))
                && (categoria == nil || c.categoriaId == categoria)
        }
        .sorted { $0.criada > $1.criada }.map(campanha)
    }

    func minhasCampanhas() async throws -> [Campanha] {
        camps.filter { $0.criadorId == usuario?.id }.sorted { $0.criada > $1.criada }.map(campanha)
    }

    func favoritos() async throws -> [Campanha] {
        camps.filter { favs.contains([usuario?.id ?? 0, $0.id]) }.map(campanha)
    }

    func salvarCampanha(id: Int?, titulo: String, descricao: String, meta: Double, cidade: String, categoria: Int?) async throws {
        guard let u = usuario else { return }
        guard meta > 0 else { throw ErroApp(errorDescription: "A meta deve ser maior que zero.") }
        if let id, let i = camps.firstIndex(where: { $0.id == id && $0.criadorId == u.id }) {
            camps[i].titulo = titulo; camps[i].descricao = descricao; camps[i].meta = meta
            camps[i].cidade = cidade; camps[i].categoriaId = categoria
        } else {
            camps.append(CampanhaRow(id: nextId(), criadorId: u.id, categoriaId: categoria, titulo: titulo, descricao: descricao,
                                     cidade: cidade, status: "ativa", meta: meta, criada: .now))
        }
    }

    func mudarStatus(_ c: Campanha, _ status: String) async throws {
        if let i = camps.firstIndex(where: { $0.id == c.id }) { camps[i].status = status }
    }

    func excluir(_ c: Campanha) async throws {
        if doacoes.contains(where: { $0.campanhaId == c.id }) {
            throw ErroApp(errorDescription: "Campanha com doações não pode ser excluída. Encerre-a.")
        }
        camps.removeAll { $0.id == c.id }
    }

    func doar(_ c: Campanha, valor: Double, metodo: String) async throws {
        guard let u = usuario else { return }
        try await Task.sleep(for: .milliseconds(600))
        doacoes.append(DoacaoRow(id: nextId(), campanhaId: c.id, doadorId: u.id, valor: valor, metodo: metodo, data: .now))
        notificar(c.criadorId, "Nova doação de R$ \(String(format: "%.2f", valor)) em \"\(c.titulo)\"")
    }

    func historico() async throws -> [Doacao] {
        doacoes.filter { $0.doadorId == usuario?.id }.sorted { $0.data > $1.data }.map { d in
            Doacao(id: d.id, campanha: camps.first { $0.id == d.campanhaId }?.titulo ?? "", valor: d.valor, metodo: d.metodo, data: d.data)
        }
    }

    func mensagens(_ c: Campanha) async throws -> [Post] {
        msgs.filter { $0.campanhaId == c.id }.sorted { $0.data > $1.data }.map {
            Post(id: $0.id, autor: nome($0.autorId), texto: $0.texto, data: $0.data)
        }
    }

    func novidades(_ c: Campanha) async throws -> [Post] {
        novs.filter { $0.campanhaId == c.id }.sorted { $0.data > $1.data }.map {
            Post(id: $0.id, autor: $0.anexo, texto: $0.texto, data: $0.data)
        }
    }

    func enviarMensagem(_ c: Campanha, _ texto: String) async throws {
        msgs.append(MensagemRow(id: nextId(), campanhaId: c.id, autorId: usuario?.id ?? 0, texto: texto, data: .now))
    }

    func excluirMensagem(_ id: Int) async throws { msgs.removeAll { $0.id == id } }

    func publicarNovidade(_ c: Campanha, _ texto: String, anexo: String) async throws {
        novs.append(NovidadeRow(id: nextId(), campanhaId: c.id, texto: texto, anexo: anexo, data: .now))
        for f in favs where f[1] == c.id { notificar(f[0], "Novidade em \"\(c.titulo)\"") }
    }

    func excluirNovidade(_ id: Int) async throws { novs.removeAll { $0.id == id } }

    func isFavorito(_ c: Campanha) async throws -> Bool { favs.contains([usuario?.id ?? 0, c.id]) }

    func alternarFavorito(_ c: Campanha, _ fav: Bool) async throws {
        let k = [usuario?.id ?? 0, c.id]
        if fav { favs.insert(k) } else { favs.remove(k) }
    }

    func denunciar(_ c: Campanha, motivo: String) async throws {
        denuncias.append(FilaRow(id: nextId(), refId: c.id, detalhe: motivo, status: "pendente", data: .now))
    }

    func solicitarSaque(_ c: Campanha) async throws {
        saques.append(FilaRow(id: nextId(), refId: c.id, detalhe: "R$ \(String(format: "%.2f", c.arrecadado))", status: "em_analise", data: .now))
    }

    func solicitarVerificacao(documento: String) async throws {
        verificacoes.append(FilaRow(id: nextId(), refId: usuario?.id ?? 0, detalhe: documento, status: "pendente", data: .now))
    }

    func notificacoes() async throws -> [Item] {
        notifs.filter { $0.usuarioId == usuario?.id }.sorted { $0.data > $1.data }.map {
            Item(id: $0.id, titulo: $0.texto, detalhe: $0.data.formatted(date: .numeric, time: .shortened), status: $0.lida ? "lida" : "nova")
        }
    }

    func marcarLidas() async throws {
        for i in notifs.indices where notifs[i].usuarioId == usuario?.id { notifs[i].lida = true }
    }

    enum Fila: String, CaseIterable { case denuncias, saques, verificacoes_ong }

    func fila(_ f: Fila) async throws -> [Item] {
        switch f {
        case .denuncias: denuncias.reversed().map { Item(id: $0.id, titulo: titulo($0.refId), detalhe: $0.detalhe, status: $0.status) }
        case .saques: saques.reversed().map { Item(id: $0.id, titulo: titulo($0.refId), detalhe: $0.detalhe, status: $0.status) }
        case .verificacoes_ong: verificacoes.reversed().map { Item(id: $0.id, titulo: nome($0.refId), detalhe: $0.detalhe, status: $0.status) }
        }
    }

    func mudarStatus(_ f: Fila, id: Int, _ status: String) async throws {
        switch f {
        case .denuncias: if let i = denuncias.firstIndex(where: { $0.id == id }) { denuncias[i].status = status }
        case .saques:
            if let i = saques.firstIndex(where: { $0.id == id }) {
                saques[i].status = status
                if let c = camps.first(where: { $0.id == saques[i].refId }) { notificar(c.criadorId, "Saque de \"\(c.titulo)\": \(status)") }
            }
        case .verificacoes_ong:
            if let i = verificacoes.firstIndex(where: { $0.id == id }) {
                verificacoes[i].status = status
                let uid = verificacoes[i].refId
                if status == "aprovado", let u = usuarios.firstIndex(where: { $0.id == uid }) {
                    usuarios[u].perfil = "ong"; usuarios[u].verificado = true
                }
                notificar(uid, "Verificação de ONG: \(status)")
            }
        }
    }

    func excluir(_ f: Fila, id: Int) async throws {
        switch f {
        case .denuncias: denuncias.removeAll { $0.id == id }
        case .saques: saques.removeAll { $0.id == id }
        case .verificacoes_ong: verificacoes.removeAll { $0.id == id }
        }
    }

    private func nome(_ uid: Int) -> String { usuarios.first { $0.id == uid }?.nome ?? "" }
    private func titulo(_ cid: Int) -> String { camps.first { $0.id == cid }?.titulo ?? "(campanha removida)" }
    private func notificar(_ uid: Int, _ texto: String) {
        notifs.append(NotificacaoRow(id: nextId(), usuarioId: uid, texto: texto, lida: false, data: .now))
    }

    private func seed() {
        usuarios = [
            UsuarioRow(id: 1, nome: "Ana Souza", email: "ana@nexo.com", senha: "123", perfil: "usuario", verificado: false),
            UsuarioRow(id: 2, nome: "Bruno Lima", email: "bruno@nexo.com", senha: "123", perfil: "usuario", verificado: false),
            UsuarioRow(id: 3, nome: "Admin NEXO", email: "admin@nexo.com", senha: "123", perfil: "admin", verificado: true),
            UsuarioRow(id: 4, nome: "ONG Patinhas", email: "ong@nexo.com", senha: "123", perfil: "ong", verificado: true),
        ]
        cats = ["Saúde", "Educação", "Animais", "Emergência", "Projetos sociais"].enumerated().map { Categoria(id: $0 + 1, nome: $1) }
        let dia: TimeInterval = 86_400
        camps = [
            CampanhaRow(id: 1, criadorId: 1, categoriaId: 1, titulo: "Cirurgia do Seu João",
                        descricao: "Seu João precisa de uma cirurgia no joelho para voltar a andar. Toda ajuda conta!",
                        cidade: "Chapecó - SC", status: "ativa", meta: 15_000, criada: .now - 5 * dia),
            CampanhaRow(id: 2, criadorId: 4, categoriaId: 3, titulo: "Ração para o abrigo Patinhas",
                        descricao: "Mais de 80 cães e gatos resgatados precisam de ração e vacinas este mês.",
                        cidade: "Florianópolis - SC", status: "ativa", meta: 5_000, criada: .now - 3 * dia),
            CampanhaRow(id: 3, criadorId: 2, categoriaId: 2, titulo: "Notebook para estudar",
                        descricao: "Estudante de ADS precisa de um notebook para acompanhar as aulas.",
                        cidade: "Porto Alegre - RS", status: "ativa", meta: 3_500, criada: .now - 1 * dia),
            CampanhaRow(id: 4, criadorId: 1, categoriaId: 4, titulo: "Enchente no bairro",
                        descricao: "Famílias perderam móveis e roupas na enchente. Vamos ajudar a reconstruir.",
                        cidade: "Blumenau - SC", status: "ativa", meta: 20_000, criada: .now - 8 * dia),
        ]
        doacoes = [
            DoacaoRow(id: 11, campanhaId: 1, doadorId: 2, valor: 250, metodo: "pix", data: .now - 4 * dia),
            DoacaoRow(id: 12, campanhaId: 1, doadorId: 3, valor: 4_000, metodo: "cartao", data: .now - 2 * dia),
            DoacaoRow(id: 13, campanhaId: 2, doadorId: 2, valor: 1_800, metodo: "pix", data: .now - 1 * dia),
            DoacaoRow(id: 14, campanhaId: 4, doadorId: 2, valor: 12_300, metodo: "pix", data: .now - 6 * dia),
            DoacaoRow(id: 15, campanhaId: 3, doadorId: 1, valor: 900, metodo: "cartao", data: .now - 3600),
        ]
        novs = [NovidadeRow(id: 21, campanhaId: 1, texto: "Consulta pré-operatória feita! Obrigado a todos.", anexo: "", data: .now - 1 * dia)]
        msgs = [
            MensagemRow(id: 31, campanhaId: 1, autorId: 2, texto: "Força, Seu João! 💚", data: .now - 3 * dia),
            MensagemRow(id: 32, campanhaId: 2, autorId: 1, texto: "Que trabalho lindo!", data: .now - 2 * dia),
        ]
        favs = [[2, 1]]
        denuncias = [FilaRow(id: 41, refId: 3, detalhe: "Suspeita de informações falsas", status: "pendente", data: .now)]
        notifs = [NotificacaoRow(id: 51, usuarioId: 1, texto: "Nova doação de R$ 4000.00 em \"Cirurgia do Seu João\"", lida: false, data: .now - 2 * dia)]
    }
}
