import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        RootView()
            .environmentObject(vm)
            .tint(.green)
            .alert("Erro", isPresented: Binding(get: { vm.erro != nil }, set: { if !$0 { vm.erro = nil } })) {
                Button("OK") {}
            } message: { Text(vm.erro ?? "") }
    }
}

#Preview("Visitante") {
    ContentView(vm: .preview())
}

#Preview("Criadora") {
    ContentView(vm: .preview(logado: "ana@nexo.com"))
}

#Preview("Doador") {
    ContentView(vm: .preview(logado: "bruno@nexo.com"))
}

#Preview("Admin") {
    ContentView(vm: .preview(logado: "admin@nexo.com"))
}
