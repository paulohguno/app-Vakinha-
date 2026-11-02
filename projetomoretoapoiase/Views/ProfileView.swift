import SwiftUI

// MARK: - Perfil de Usuário, Autenticação e Notificações (CRUD 10)
struct ProfileView: View {
    @ObservedObject var vm: NexoViewModel
    @State private var showingAuthSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // Sessão Ativa
                Section("Sessão Atual") {
                    if let user = vm.currentUser {
                        HStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 52, height: 52)
                                .foregroundColor(.vakinhaBlue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                    .foregroundColor(.vakinhaBlack)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.vakinhaBlackMuted)
                                
                                HStack {
                                    Text(user.role)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
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
                            Label("Encerrar Sessão", systemImage: "arrow.right.square")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Você não está conectado.")
                                .font(.subheadline)
                                .foregroundColor(.vakinhaBlackMuted)
                            Button("Fazer Login ou Criar Conta") {
                                showingAuthSheet = true
                            }
                            .buttonStyle(VakinhaSecondaryButtonStyle())
                        }
                    }
                }
                
                // Alternância Rápida de Usuários (Mock no PostgreSQL para Avaliação)
                Section("Alternar Usuário Cadastrado no PostgreSQL") {
                    ForEach(vm.availableUsers) { u in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(u.name)
                                    .fontWeight(u.id == vm.currentUser?.id ? .bold : .regular)
                                    .foregroundColor(.vakinhaBlack)
                                Text("\(u.role) • \(u.email)")
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
                
                // Permissões do Dispositivo
                Section("Permissões de Recursos Nativos da Apple") {
                    HStack {
                        Label("Geolocalização (CoreLocation)", systemImage: "location.fill")
                            .foregroundColor(.vakinhaBlack)
                        Spacer()
                        Text(vm.locationManager.authorizationStatus == .authorizedWhenInUse || vm.locationManager.authorizationStatus == .authorizedAlways ? "Permitido" : "Não Autorizado")
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
                    
                    HStack {
                        Label("Câmera / Galeria", systemImage: "camera.fill")
                            .foregroundColor(.vakinhaBlack)
                        Spacer()
                        Text("Integrado")
                            .font(.caption)
                            .foregroundColor(.vakinhaBlue)
                    }
                }
                
                // CRUD 10: Notificações do PostgreSQL
                Section("Notificações no PostgreSQL (\(vm.notifications.count))") {
                    if vm.notifications.isEmpty {
                        Text("Nenhuma notificação.")
                            .font(.caption)
                            .foregroundColor(.vakinhaBlackMuted)
                    } else {
                        ForEach(vm.notifications) { notif in
                            HStack {
                                Image(systemName: notif.isRead ? "bell" : "bell.badge.fill")
                                    .foregroundColor(notif.isRead ? .secondary : .vakinhaBlue)
                                VStack(alignment: .leading, spacing: 2) {
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
            .sheet(isPresented: $showingAuthSheet) {
                AuthView(vm: vm)
            }
        }
    }
}
