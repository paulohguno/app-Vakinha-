import SwiftUI

// MARK: - Tela de Autenticação Segura (Login & Cadastro)
struct AuthView: View {
    @ObservedObject var vm: NexoViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var isRegisterMode = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole = "Doador"
    
    let roles = ["Doador", "Criador", "ONG"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo & Cabeçalho 60/30/10
                    VStack(spacing: 8) {
                        Image(systemName: "heart.text.square.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .foregroundColor(.vakinhaBlue)
                        
                        Text(isRegisterMode ? "Criar Conta na Vakinha" : "Acesse sua Conta")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.vakinhaBlack)
                        
                        Text("Pequenas doações, grandes transformações.")
                            .font(.subheadline)
                            .foregroundColor(.vakinhaBlackMuted)
                    }
                    .padding(.top, 20)
                    
                    if let err = vm.errorMessage {
                        StatusBannerView(message: err, isError: true) {
                            vm.errorMessage = nil
                        }
                    }
                    
                    // Formulário
                    VStack(spacing: 16) {
                        if isRegisterMode {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Nome Completo")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.vakinhaBlack)
                                TextField("Seu nome", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Tipo de Perfil")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.vakinhaBlack)
                                Picker("Perfil", selection: $selectedRole) {
                                    ForEach(roles, id: \.self) { r in
                                        Text(r).tag(r)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.vakinhaBlack)
                            TextField("seu@email.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Senha")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.vakinhaBlack)
                            SecureField("Mínimo 6 dígitos", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(20)
                    .background(Color.vakinhaCardBg)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                    
                    // Botão Primário (30% Azul)
                    Button {
                        Task {
                            if isRegisterMode {
                                let ok = await vm.register(name: name, email: email, password: password, role: selectedRole)
                                if ok { dismiss() }
                            } else {
                                let ok = await vm.login(email: email, password: password)
                                if ok { dismiss() }
                            }
                        }
                    } label: {
                        HStack {
                            if vm.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isRegisterMode ? "Cadastrar" : "Entrar")
                            }
                        }
                    }
                    .buttonStyle(VakinhaPrimaryButtonStyle())
                    .disabled(email.isEmpty || password.isEmpty || (isRegisterMode && name.isEmpty) || vm.isLoading)
                    
                    // Alternar Modo Login / Cadastro
                    Button {
                        withAnimation {
                            isRegisterMode.toggle()
                        }
                    } label: {
                        Text(isRegisterMode ? "Já tem uma conta? Entrar" : "Ainda não tem conta? Cadastre-se")
                            .font(.footnote)
                            .foregroundColor(.vakinhaBlue)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 20)
            }
            .background(Color.vakinhaBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

