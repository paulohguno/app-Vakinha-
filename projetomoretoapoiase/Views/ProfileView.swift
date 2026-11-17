import SwiftUI

// MARK: - Perfil do Usuário, Sessão JWT, Configuração Dinâmica da API e Central de Notificações (CRUD 10)
struct ProfileView: View {
    @ObservedObject var vm: NexoViewModel
    @State private var showingAuthSheet = false
    @State private var apiEndpointInput: String = AppConfig.shared.apiBaseURL
    
    var body: some View {
        NavigationStack {
            List {
                // 1. Sessão Ativa e Papel de Acesso (RBAC)
                Section("Sessão Atual e Controle de Acesso (RBAC)") {
                    if let user = vm.currentUser {
                        HStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 54, height: 54)
                                .foregroundColor(.vakinhaBlue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                    .foregroundColor(.vakinhaBlack)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.vakinhaBlackMuted)
                                
                                HStack(spacing: 6) {
                                    Label(user.role, systemImage: "shield.lefthalf.filled")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.vakinhaBlueLight)
                                        .foregroundColor(.vakinhaBlue)
                                        .cornerRadius(6)
                                    
                                    if let city = user.city {
                                        Text("• \(city)")
                                            .font(.caption2)
                                            .foregroundColor(.vakinhaBlackMuted)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Button(role: .destructive) {
                            vm.logout()
                        } label: {
                            Label("Encerrar Sessão (Limpar Keychain JWT)", systemImage: "arrow.right.square")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Você não está autenticado.")
                                .font(.subheadline)
                                .foregroundColor(.vakinhaBlackMuted)
                            Button("Fazer Login ou Criar Conta") {
                                showingAuthSheet = true
                            }
                            .buttonStyle(VakinhaSecondaryButtonStyle())
                        }
                    }
                }
                
                // 2. Alternância Rápida de Perfil para Testar Controle de Acesso nas Abas
                Section("Alternar Perfil Cadastrado no PostgreSQL") {
                    ForEach(vm.availableUsers) { u in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u.name)
                                    .fontWeight(u.id == vm.currentUser?.id ? .bold : .regular)
                                    .foregroundColor(.vakinhaBlack)
                                Text("Papel: \(u.role) • \(u.email)")
                                    .font(.caption)
                                    .foregroundColor(.vakinhaBlackMuted)
                            }
                            Spacer()
                            if u.id == vm.currentUser?.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.vakinhaBlue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.switchUser(user: u)
                        }
                    }
                }
                
                // 3. Configuração Dinâmica de Endpoint REST (Sem Travar em Localhost)
                Section("Servidor API Dinâmico (Simulador ou Rede Local)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("URL Base da API Node.js:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.vakinhaBlackMuted)
                        
                        TextField("Ex: http://192.168.0.15:3000/api", text: $apiEndpointInput)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            Button("Salvar e Reconectar") {
                                Task {
                                    await vm.updateAPIBaseURL(apiEndpointInput)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.vakinhaBlue)
                            .font(.caption)
                            
                            Button("Padrão (localhost)") {
                                AppConfig.shared.resetToDefault()
                                apiEndpointInput = AppConfig.shared.apiBaseURL
                                Task {
                                    await vm.updateAPIBaseURL(apiEndpointInput)
                                }
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 4. Status de Integrações Nativas do iOS
                Section("Recursos Nativos Apple & Segurança") {
                    HStack {
                        Label("Token JWT no Keychain", systemImage: "key.fill")
                            .foregroundColor(.vakinhaBlack)
                        Spacer()
                        Text(KeychainHelper.shared.currentJWTToken != nil ? "Armazenado" : "Ausente")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(KeychainHelper.shared.currentJWTToken != nil ? .vakinhaSuccess : .secondary)
                    }
                    
                    HStack {
                        Label("Geolocalização (CoreLocation)", systemImage: "location.fill")
                            .foregroundColor(.vakinhaBlack)
                        Spacer()
                        Text(
                            vm.locationManager.authorizationStatus == .authorizedWhenInUse ||
                            vm.locationManager.authorizationStatus == .authorizedAlways
                            ? "Permitido (\(vm.locationManager.cityName))"
                            : "Aguardando Permissão"
                        )
                        .font(.caption)
                        .foregroundColor(.vakinhaBlue)
                    }
                    
                    HStack {
                        Label("Notificações (UserNotifications)", systemImage: "bell.badge.fill")
                            .foregroundColor(.vakinhaBlack)
                        Spacer()
                        Text(vm.notificationManager.isAuthorized ? "Ativo" : "Desativado")
                            .font(.caption)
                            .foregroundColor(.vakinhaBlue)
                    }
                }
                
                // 5. CRUD 10: Notificações do PostgreSQL (Geradas pelas Triggers PL/pgSQL)
                Section("Central de Notificações (\(vm.notifications.count))") {
                    if vm.notifications.isEmpty {
                        Text("Nenhuma notificação para este perfil.")
                            .font(.caption)
                            .foregroundColor(.vakinhaBlackMuted)
                    } else {
                        ForEach(vm.notifications) { notif in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: notif.isRead ? "bell" : "bell.badge.fill")
                                    .foregroundColor(notif.isRead ? .secondary : .vakinhaBlue)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(notif.title)
                                        .font(.subheadline)
                                        .fontWeight(notif.isRead ? .regular : .bold)
                                        .foregroundColor(.vakinhaBlack)
                                    Text(notif.content)
                                        .font(.caption)
                                        .foregroundColor(.vakinhaBlackMuted)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task { await vm.markNotificationAsRead(id: notif.id) }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await vm.deleteNotification(id: notif.id) }
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Minha Conta")
            .refreshable {
                if let u = vm.currentUser {
                    await vm.fetchNotifications(userId: u.id)
                }
                await vm.fetchUsers()
            }
            .onAppear {
                apiEndpointInput = AppConfig.shared.apiBaseURL
            }
            .sheet(isPresented: $showingAuthSheet) {
                AuthView(vm: vm)
            }
        }
    }
}
