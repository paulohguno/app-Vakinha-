import SwiftUI
import MapKit

// MARK: - Detalhes da Vaquinha (Com AsyncImage HTTP, Mini-Mapa MapKit, ShareSheet Nativo e Todos os CRUDs)
struct CampaignDetailView: View {
    @ObservedObject var vm: NexoViewModel
    @State var campaign: CampaignItem
    @Environment(\.dismiss) var dismiss
    
    // Sheets e Modais
    @State private var showingDonateSheet = false
    @State private var showingNewUpdateSheet = false
    @State private var showingReportSheet = false
    @State private var showingWithdrawSheet = false
    @State private var showingEditSheet = false
    @State private var showingAuthSheet = false
    @State private var showingShareSheet = false
    
    // Nova mensagem do mural
    @State private var newMessageText = ""
    
    private var shareSummaryText: String {
        """
        Apoie a campanha "\(campaign.title)" no NEXO Vakinha!
        Arrecadado: R$ \(String(format: "%.2f", campaign.currentAmount)) de R$ \(String(format: "%.2f", campaign.goalAmount)) (\(campaign.percentFormatted))
        Local: \(campaign.locationName ?? "Brasil")
        \(campaign.description)
        """
    }
    
    var body: some View {
        List {
            // 1. Capa com Carregamento Assíncrono Otimizado via URL (Sem Base64 no banco)
            Section {
                CategoryCardHeader(
                    categoryName: campaign.categoryName,
                    iconName: campaign.categoryIcon,
                    imageUrl: campaign.imageUrl
                )
                .listRowInsets(EdgeInsets())
            }
            
            // 2. Cabeçalho, Progresso e Botões de Ação + Compartilhamento
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if let cat = campaign.categoryName {
                            Text(cat)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.vakinhaBlue)
                        }
                        
                        Spacer()
                        
                        if let loc = campaign.locationName, !loc.isEmpty {
                            Label(loc, systemImage: "mappin.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.vakinhaBlackMuted)
                        }
                    }
                    
                    Text(campaign.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.vakinhaBlack)
                    
                    Text(campaign.description)
                        .font(.body)
                        .foregroundColor(.vakinhaBlackMuted)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: campaign.progress)
                            .tint(.vakinhaBlue)
                        
                        HStack {
                            Text("Arrecadado: R$ \(String(format: "%.2f", campaign.currentAmount))")
                                .fontWeight(.bold)
                                .foregroundColor(.vakinhaBlue)
                            Spacer()
                            Text("Meta: R$ \(String(format: "%.2f", campaign.goalAmount))")
                                .font(.caption)
                                .foregroundColor(.vakinhaBlackMuted)
                        }
                    }
                    .padding(.top, 4)
                    
                    // Botão Principal de Doação
                    Button {
                        if vm.isAuthenticated {
                            showingDonateSheet = true
                        } else {
                            showingAuthSheet = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Apoiar Esta Vaquinha", systemImage: "heart.fill")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .buttonStyle(VakinhaPrimaryButtonStyle())
                    
                    // Botão de Compartilhamento Nativo (ShareSheet / UIActivityViewController)
                    Button {
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Compartilhar Campanha", systemImage: "square.and.arrow.up")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(VakinhaSecondaryButtonStyle())
                }
                .padding(.vertical, 4)
            }
            
            // 3. Mapa Interativo Nativo (MapKit) caso a campanha possua Coordenadas GPS
            if let lat = campaign.latitude, let lon = campaign.longitude {
                Section("Localização da Causa no Mapa (GPS)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Map(
                            initialPosition: .region(
                                MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                )
                            )
                        ) {
                            Marker(campaign.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                .tint(.vakinhaBlue)
                        }
                        .frame(height: 170)
                        .cornerRadius(12)
                        
                        HStack {
                            Label(campaign.locationName ?? "Coordenadas Verificadas", systemImage: "location.fill")
                                .font(.caption)
                                .foregroundColor(.vakinhaBlackMuted)
                            Spacer()
                            let dist = vm.locationManager.distance(to: lat, lon: lon)
                            if !dist.isEmpty {
                                Text(dist)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.vakinhaBlue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 4. Ações Restritas ao Criador da Campanha ou Admin
            if campaign.creatorId == vm.currentUser?.id || vm.currentUser?.role == "Admin" {
                Section("Gerenciamento do Criador") {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Editar Informações da Vaquinha", systemImage: "pencil")
                            .foregroundColor(.vakinhaBlue)
                    }
                    
                    Button {
                        showingNewUpdateSheet = true
                    } label: {
                        Label("Publicar Novidade / Prestação de Contas", systemImage: "megaphone.fill")
                            .foregroundColor(.vakinhaBlue)
                    }
                    
                    Button {
                        showingWithdrawSheet = true
                    } label: {
                        Label("Solicitar Saque PIX (R$ \(String(format: "%.2f", campaign.currentAmount)))", systemImage: "banknote.fill")
                            .foregroundColor(.vakinhaBlue)
                    }
                    
                    Button(role: .destructive) {
                        Task {
                            await vm.deleteCampaign(id: campaign.id)
                            dismiss()
                        }
                    } label: {
                        Label("Excluir Vaquinha", systemImage: "trash")
                    }
                }
            }
            
            // 5. CRUD 3: Mural de Novidades e Prestação de Contas (Com AsyncImage se houver foto anexada)
            Section("Mural de Novidades (Prestação de Contas)") {
                if vm.updates.isEmpty {
                    Text("Nenhuma atualização publicada ainda.")
                        .font(.caption)
                        .foregroundColor(.vakinhaBlackMuted)
                } else {
                    ForEach(vm.updates) { upd in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(upd.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.vakinhaBlack)
                            Text(upd.content)
                                .font(.caption)
                                .foregroundColor(.vakinhaBlackMuted)
                            
                            if let updImgURL = AppConfig.shared.resolveImageURL(upd.imageUrl) {
                                AsyncImage(url: updImgURL) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 150)
                                            .clipped()
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions {
                            if campaign.creatorId == vm.currentUser?.id || vm.currentUser?.role == "Admin" {
                                Button(role: .destructive) {
                                    Task { await vm.deleteUpdate(id: upd.id, campaignId: campaign.id) }
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            
            // 6. CRUD 2: Histórico de Doações da Campanha
            Section("Doações Recebidas (\(vm.donations.count))") {
                if vm.donations.isEmpty {
                    Text("Seja o primeiro a apoiar esta vaquinha!")
                        .font(.caption)
                        .foregroundColor(.vakinhaBlackMuted)
                } else {
                    ForEach(vm.donations) { don in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                                .foregroundColor(.vakinhaBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(don.userName ?? "Doador Solidário")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.vakinhaBlack)
                                if let msg = don.message, !msg.isEmpty {
                                    Text("\"\(msg)\"")
                                        .font(.caption2)
                                        .italic()
                                        .foregroundColor(.vakinhaBlackMuted)
                                }
                            }
                            Spacer()
                            Text("+ R$ \(String(format: "%.2f", don.amount))")
                                .font(.footnote)
                                .fontWeight(.bold)
                                .foregroundColor(.vakinhaBlue)
                        }
                    }
                }
            }
            
            // 7. CRUD 4: Mural de Mensagens de Apoio
            Section("Mensagens de Apoio (Mural)") {
                HStack {
                    TextField("Deixe uma mensagem de carinho...", text: $newMessageText)
                    Button("Enviar") {
                        guard !newMessageText.isEmpty else { return }
                        let text = newMessageText
                        newMessageText = ""
                        Task {
                            _ = await vm.postMessage(campaignId: campaign.id, message: text)
                        }
                    }
                    .foregroundColor(.vakinhaBlue)
                    .disabled(newMessageText.isEmpty)
                }
                
                ForEach(vm.messages) { msg in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(msg.authorName ?? "Apoiador")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.vakinhaBlack)
                            Spacer()
                        }
                        Text(msg.message)
                            .font(.footnote)
                            .foregroundColor(.vakinhaBlackMuted)
                    }
                    .swipeActions {
                        if msg.userId == vm.currentUser?.id || vm.currentUser?.role == "Admin" {
                            Button(role: .destructive) {
                                Task { await vm.deleteMessage(id: msg.id, campaignId: campaign.id) }
                            } label: {
                                Label("Excluir", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            
            // 8. CRUD 5: Denunciar Campanha
            Section {
                Button(role: .destructive) {
                    showingReportSheet = true
                } label: {
                    Label("Denunciar Campanha à Moderação", systemImage: "flag.fill")
                }
            }
        }
        .navigationTitle("Detalhes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.vakinhaBlue)
                }
                
                Button {
                    Task { await vm.toggleFavorite(campaignId: campaign.id) }
                } label: {
                    Image(systemName: vm.isFavorite(campaignId: campaign.id) ? "heart.fill" : "heart")
                        .foregroundColor(vm.isFavorite(campaignId: campaign.id) ? .red : .vakinhaBlue)
                }
            }
        }
        .task {
            await vm.fetchDonations(for: campaign.id)
            await vm.fetchUpdates(for: campaign.id)
            await vm.fetchMessages(for: campaign.id)
        }
        .sheet(isPresented: $showingDonateSheet) {
            DonateSheet(vm: vm, campaign: campaign) {
                Task {
                    await vm.fetchCampaigns()
                    if let refreshed = vm.campaigns.first(where: { $0.id == campaign.id }) {
                        self.campaign = refreshed
                    }
                    await vm.fetchDonations(for: campaign.id)
                }
            }
        }
        .sheet(isPresented: $showingNewUpdateSheet) {
            NewCampaignUpdateSheet(vm: vm, campaignId: campaign.id)
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportCampaignSheet(vm: vm, campaignId: campaign.id)
        }
        .sheet(isPresented: $showingWithdrawSheet) {
            RequestWithdrawalSheet(vm: vm, campaign: campaign)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCampaignSheet(vm: vm, campaign: campaign) {
                Task {
                    await vm.fetchCampaigns()
                    if let refreshed = vm.campaigns.first(where: { $0.id == campaign.id }) {
                        self.campaign = refreshed
                    }
                }
            }
        }
        .sheet(isPresented: $showingAuthSheet) {
            AuthView(vm: vm)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareSummaryText])
        }
    }
}

// MARK: - Sheet de Doação (CRUD 2: Create — Aciona Trigger PL/pgSQL no PostgreSQL)
struct DonateSheet: View {
    @ObservedObject var vm: NexoViewModel
    let campaign: CampaignItem
    var onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var amountText: String = "50"
    @State private var paymentMethod: String = "PIX"
    @State private var messageText: String = "Torcendo muito por essa causa!"
    
    let presets = [20.0, 50.0, 100.0, 250.0, 500.0]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Valor da Doação") {
                    HStack {
                        Text("R$")
                            .font(.title2)
                            .foregroundColor(.vakinhaBlue)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(presets, id: \.self) { val in
                                Button("R$ \(Int(val))") {
                                    amountText = "\(Int(val))"
                                }
                                .buttonStyle(.bordered)
                                .tint(.vakinhaBlue)
                            }
                        }
                    }
                }
                
                Section("Forma de Pagamento") {
                    Picker("Método", selection: $paymentMethod) {
                        Text("PIX Instantâneo").tag("PIX")
                        Text("Cartão de Crédito").tag("Cartão de Crédito")
                        Text("Boleto Bancário").tag("Boleto")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Mensagem de Apoio (Opcional)") {
                    TextField("Deixe um recado...", text: $messageText)
                }
                
                Section {
                    Button {
                        guard let val = Double(amountText.replacingOccurrences(of: ",", with: ".")), val > 0 else { return }
                        Task {
                            let ok = await vm.makeDonation(
                                campaignId: campaign.id,
                                amount: val,
                                paymentMethod: paymentMethod,
                                message: messageText.isEmpty ? nil : messageText
                            )
                            if ok {
                                onComplete()
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Confirmar Doação via \(paymentMethod)")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .buttonStyle(VakinhaPrimaryButtonStyle())
                }
            }
            .navigationTitle("Contribuir")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sheet de Atualizações / Prestação de Contas (CRUD 3: Create)
struct NewCampaignUpdateSheet: View {
    @ObservedObject var vm: NexoViewModel
    let campaignId: String
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var content = ""
    @State private var imageUrl = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dados da Atualização") {
                    TextField("Título (ex: Exames realizados)", text: $title)
                    TextField("Conteúdo da prestação de contas...", text: $content, axis: .vertical)
                        .lineLimit(4...8)
                    TextField("URL de Foto Comprovante (Opcional)", text: $imageUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                
                Section {
                    Button("Publicar Novidade") {
                        guard !title.isEmpty && !content.isEmpty else { return }
                        Task {
                            let ok = await vm.createUpdate(
                                campaignId: campaignId,
                                title: title,
                                content: content,
                                imageUrl: imageUrl.isEmpty ? nil : imageUrl
                            )
                            if ok { dismiss() }
                        }
                    }
                    .buttonStyle(VakinhaPrimaryButtonStyle())
                    .disabled(title.isEmpty || content.isEmpty)
                }
            }
            .navigationTitle("Nova Prestação de Contas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sheet de Edição de Campanha (CRUD 1: Update)
struct EditCampaignSheet: View {
    @ObservedObject var vm: NexoViewModel
    let campaign: CampaignItem
    var onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var goal: String
    @State private var status: String
    @State private var imageUrl: String
    @State private var locationName: String
    
    init(vm: NexoViewModel, campaign: CampaignItem, onComplete: @escaping () -> Void) {
        self.vm = vm
        self.campaign = campaign
        self.onComplete = onComplete
        _title = State(initialValue: campaign.title)
        _description = State(initialValue: campaign.description)
        _goal = State(initialValue: "\(campaign.goalAmount)")
        _status = State(initialValue: campaign.status)
        _imageUrl = State(initialValue: campaign.imageUrl ?? "")
        _locationName = State(initialValue: campaign.locationName ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informações Principais") {
                    TextField("Título", text: $title)
                    TextField("Descrição", text: $description, axis: .vertical)
                        .lineLimit(4...6)
                    TextField("Meta (R$)", text: $goal)
                        .keyboardType(.decimalPad)
                    TextField("URL da Imagem de Capa", text: $imageUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Localização", text: $locationName)
                }
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Ativa").tag("ativa")
                        Text("Concluída").tag("concluida")
                        Text("Encerrada").tag("encerrada")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Button("Salvar Alterações") {
                        guard let g = Double(goal.replacingOccurrences(of: ",", with: ".")) else { return }
                        Task {
                            let ok = await vm.updateCampaign(
                                id: campaign.id,
                                title: title,
                                description: description,
                                goalAmount: g,
                                categoryId: campaign.categoryId,
                                status: status,
                                imageUrl: imageUrl.isEmpty ? nil : imageUrl,
                                locationName: locationName.isEmpty ? nil : locationName
                            )
                            if ok {
                                onComplete()
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(VakinhaPrimaryButtonStyle())
                }
            }
            .navigationTitle("Editar Vaquinha")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sheet de Denúncia (CRUD 5: Create)
struct ReportCampaignSheet: View {
    @ObservedObject var vm: NexoViewModel
    let campaignId: String
    @Environment(\.dismiss) var dismiss
    
    @State private var reason: String = "Suspeita de fraude ou informações falsas"
    
    let reasons = [
        "Suspeita de fraude ou informações falsas",
        "Uso indevido de imagem de terceiros",
        "Meta incompatível com a causa",
        "Falta de transparência e prestação de contas",
        "Conteúdo abusivo ou ofensivo"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Motivo da Denúncia") {
                    Picker("Selecione o motivo", selection: $reason) {
                        ForEach(reasons, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            let ok = await vm.createReport(campaignId: campaignId, reason: reason)
                            if ok { dismiss() }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Enviar Denúncia à Moderação")
                            Spacer()
                        }
                    }
                    .buttonStyle(VakinhaPrimaryButtonStyle(isDestructive: true))
                }
            }
            .navigationTitle("Denunciar Vaquinha")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sheet de Solicitação de Saque PIX (CRUD 9: Create)
struct RequestWithdrawalSheet: View {
    @ObservedObject var vm: NexoViewModel
    let campaign: CampaignItem
    @Environment(\.dismiss) var dismiss
    
    @State private var amountText: String = ""
    @State private var pixKey: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Saldo Disponível para Saque") {
                    Text("R$ \(String(format: "%.2f", campaign.currentAmount))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.vakinhaBlue)
                }
                
                Section("Dados para Transferência PIX") {
                    TextField("Valor do Saque (R$)", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Chave PIX (CPF/CNPJ/Email/Telefone)", text: $pixKey)
                }
                
                Section {
                    Button("Solicitar Saque") {
                        guard let val = Double(amountText.replacingOccurrences(of: ",", with: ".")), !pixKey.isEmpty else { return }
                        Task {
                            let ok = await vm.createWithdrawal(campaignId: campaign.id, amount: val, pixKey: pixKey)
                            if ok { dismiss() }
                        }
                    }
                    .buttonStyle(VakinhaPrimaryButtonStyle())
                    .disabled(amountText.isEmpty || pixKey.isEmpty)
                }
            }
            .navigationTitle("Solicitar Saque")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
