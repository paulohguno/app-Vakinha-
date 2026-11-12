import SwiftUI

// MARK: - Tela de Autenticação Segura (Login, Cadastro com Seleção de Papel e Acesso Rápido)
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
                    // Cabeçalho Institucional NEXO Vakinha
                    VStack(spacing: 8) {
                        Image(systemName: "heart.text.square.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .foregroundColor(.vakinhaBlue)
                        
                        Text(isRegisterMode ? "Criar Conta no NEXO" : "Acesse sua Conta")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.vakinhaBlack)
                        
                        Text("Autenticação criptografada (scrypt + JWT no Keychain)")
                            .font(.caption)
                            .foregroundColor(.vakinhaBlackMuted)
                    }
                    .padding(.top, 16)
                    
                    if let err = vm.errorMessage {
                        StatusBannerView(message: err, isError: true) {
                            vm.errorMessage = nil
                        }
                    }
                    
                    // Formulário Principal
                    VStack(spacing: 16) {
                        if isRegisterMode {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Nome Completo ou Razão Social")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.vakinhaBlack)
                                TextField("Seu nome completo", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Perfil de Acesso (RBAC)")
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
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Senha")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.vakinhaBlack)
                            SecureField("Mínimo 6 caracteres", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(20)
                    .background(Color.vakinhaCardBg)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                    
                    // Botão de Submissão (Login ou Cadastro)
                    Button {
                        Task {
                            if isRegisterMode {
                                let ok = await vm.register(
                                    name: name,
                                    email: email,
                                    password: password,
                                    role: selectedRole
                                )
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
                                Text(isRegisterMode ? "Criar Conta e Entrar" : "Entrar com Segurança")
                            }
                        }
                    }
                    .buttonStyle(VakinhaPrimaryButtonStyle())
                    .disabled(email.isEmpty || password.isEmpty || (isRegisterMode && name.isEmpty) || vm.isLoading)
                    
                    // Alternar entre Login e Cadastro
                    Button {
                        withAnimation {
                            isRegisterMode.toggle()
                            vm.errorMessage = nil
                        }
                    } label: {
                        Text(isRegisterMode ? "Já possui uma conta? Faça Login" : "Ainda não tem conta? Cadastre-se agora")
                            .font(.footnote)
                            .foregroundColor(.vakinhaBlue)
                            .fontWeight(.semibold)
                    }
                    
                    // Credenciais Rápidas do Seed Inicial para Demonstração de RBAC
                    if !isRegisterMode {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Acesso Rápido (Perfis do Seed PostgreSQL):")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.vakinhaBlackMuted)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                quickFillButton(label: "Criador (Paulo)", mail: "paulo@vakinha.com")
                                quickFillButton(label: "Doador (Mariana)", mail: "mariana@vakinha.com")
                                quickFillButton(label: "ONG (Patas do Bem)", mail: "ong@patasdobem.org")
                                quickFillButton(label: "Admin (Moderação)", mail: "admin@vakinha.com")
                            }
                        }
                        .padding(14)
                        .background(Color.vakinhaCardBg)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
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
    
    private func quickFillButton(label: String, mail: String) -> some View {
        Button {
            self.email = mail
            self.password = "123456"
        } label: {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.vakinhaBlueLight)
                .foregroundColor(.vakinhaBlue)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
