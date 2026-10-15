import Foundation

struct Usuario: Identifiable, Hashable { let id: Int; let nome, email, perfil: String; let verificado: Bool }
struct Categoria: Identifiable, Hashable { let id: Int; let nome: String }
struct Campanha: Identifiable, Hashable {
    let id, criadorId: Int
    let titulo, descricao, cidade, status, categoria, criador: String
    let meta, arrecadado: Double
    let doadores: Int
    let criadorVerificado: Bool
    var progresso: Double { min(arrecadado / meta, 1) }
}
struct Metricas { let arrecadado: Double; let campanhasAtivas, doacoes, usuarios, denunciasPendentes, saquesPendentes: Int }
struct Doacao: Identifiable { let id: Int; let campanha: String; let valor: Double; let metodo: String; let data: Date }
struct Post: Identifiable { let id: Int; let autor, texto: String; let data: Date }
struct Item: Identifiable { let id: Int; let titulo, detalhe, status: String }

struct ErroApp: LocalizedError { let errorDescription: String? }
