import SwiftUI

let brl = FloatingPointFormatStyle<Double>.Currency(code: "BRL").locale(Locale(identifier: "pt_BR"))

struct RootView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        TabView {
            NavigationStack { FeedView() }
                .tabItem { Label("Explorar", systemImage: "sparkle.magnifyingglass") }
            if vm.usuario != nil {
                NavigationStack { MinhasCampanhasView() }
                    .tabItem { Label("Minhas", systemImage: "rectangle.stack.badge.plus") }
            }
            NavigationStack { PerfilView() }
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                .badge(vm.naoLidas)
            if vm.usuario?.perfil == "admin" {
                NavigationStack { AdminView() }
                    .tabItem { Label("Admin", systemImage: "checkmark.shield") }
            }
        }
    }
}

struct EstiloCategoria {
    let icone: String
    let cor: Color

    init(_ nome: String) {
        switch nome {
        case "Saúde": (icone, cor) = ("cross.case.fill", .pink)
        case "Educação": (icone, cor) = ("graduationcap.fill", .blue)
        case "Animais": (icone, cor) = ("pawprint.fill", .orange)
        case "Emergência": (icone, cor) = ("exclamationmark.triangle.fill", .red)
        case "Projetos sociais": (icone, cor) = ("person.3.fill", .purple)
        default: (icone, cor) = ("heart.fill", .green)
        }
    }
}

func rotulo(_ status: String) -> String {
    status.replacingOccurrences(of: "_", with: " ").capitalized(with: Locale(identifier: "pt_BR"))
}

struct CapaCampanha: View {
    let c: Campanha
    var altura: CGFloat = 140

    var body: some View {
        let e = EstiloCategoria(c.categoria)
        LinearGradient(colors: [e.cor, e.cor.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(height: altura)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: e.icone)
                    .font(.system(size: altura * 0.5))
                    .foregroundStyle(.white.opacity(0.35))
                    .offset(x: -16, y: -8)
            }
            .overlay(alignment: .topLeading) {
                if !c.categoria.isEmpty {
                    Label(c.categoria, systemImage: e.icone)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
                }
            }
            .accessibilityHidden(true)
    }
}

struct StatusBadge: View {
    let status: String

    var cor: Color {
        switch status {
        case "ativa", "aprovado", "resolvida": .green
        case "pausada", "em_analise", "pendente", "pendente_documento": .orange
        case "encerrada", "arquivada": .gray
        default: .red
        }
    }

    var body: some View {
        Text(rotulo(status))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(cor)
            .background(cor.opacity(0.15), in: Capsule())
    }
}

struct Avatar: View {
    let nome: String
    var tamanho: CGFloat = 40

    var iniciais: String {
        nome.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    var body: some View {
        Text(iniciais)
            .font(.system(size: tamanho * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: tamanho, height: tamanho)
            .background(Color.green.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

struct Progresso: View {
    let c: Campanha

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: c.progresso).tint(.green)
            HStack(alignment: .firstTextBaseline) {
                Text(c.arrecadado, format: brl).font(.subheadline.bold())
                Text("de \(c.meta, format: brl)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(c.progresso, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.bold()).foregroundStyle(.green)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CampanhaCard: View {
    let c: Campanha

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CapaCampanha(c: c)
            VStack(alignment: .leading, spacing: 10) {
                Text(c.titulo).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(c.cidade)
                    Text("·")
                    Text(c.criador)
                    if c.criadorVerificado { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Progresso(c: c)
                Label("\(c.doadores) \(c.doadores == 1 ? "apoiador" : "apoiadores")", systemImage: "person.2.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

struct CampanhaRow: View {
    let c: Campanha

    var body: some View {
        HStack(spacing: 12) {
            let e = EstiloCategoria(c.categoria)
            Image(systemName: e.icone)
                .font(.title3).foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(e.cor.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(c.titulo).font(.headline).lineLimit(1)
                    Spacer()
                    StatusBadge(status: c.status)
                }
                Progresso(c: c)
            }
        }
        .padding(.vertical, 4)
    }
}

struct Chip: View {
    let titulo: String
    let icone: String
    let selecionado: Bool
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Label(titulo, systemImage: icone)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(selecionado ? .white : .primary)
                .background(selecionado ? AnyShapeStyle(Color.green) : AnyShapeStyle(.thinMaterial), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selecionado ? .isSelected : [])
    }
}

struct Metrica: View {
    let titulo: String
    let valor: String
    let icone: String
    let cor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icone).font(.title3).foregroundStyle(cor)
            Text(valor).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.6)
            Text(titulo).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
