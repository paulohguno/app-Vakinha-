# NEXO - Plataforma iOS de Arrecadação Social (Clone Vakinha)

Este projeto implementa o aplicativo nativo iOS **NEXO**, seguindo rigorosamente a arquitetura e os padrões da Apple (SwiftUI, MVVM, async/await, URLSession) e todos os requisitos e CRUDs detalhados no documento de especificação (`Nexo_documentacao (2) (1).pdf`).

---

## Arquitetura do Projeto

O projeto segue as diretrizes de engenharia de software da Apple e o padrão MVVM com sincronização direta via `PBXFileSystemSynchronizedRootGroup`:

```
projetomoretoapoiase/
├── Models/
│   └── NexoModels.swift        # Entidades Codable/Identifiable para os 10 CRUDs
├── Services/
│   └── APIService.swift        # Serviço REST com URLSession e tratamento de erros
├── ViewModels/
│   └── NexoViewModel.swift     # ObservableObject (@MainActor) que centraliza estados e operações
├── Views/
│   ├── Components/
│   │   └── NexoComponents.swift # Banners de feedback, cards reutilizáveis
│   ├── CampaignsFeedView.swift  # Feed principal, filtros de categorias e criação
│   ├── CampaignDetailView.swift # Detalhes, doação (Pix/Cartão), mural, prestação de contas, denúncias e saques
│   ├── DonorHistoryView.swift   # Histórico de doações e favoritos
│   ├── CreatorDashboardView.swift # Gestão das campanhas criadas e saques
│   ├── AdminONGView.swift       # Moderação de denúncias, verificação de ONG e aprovação de saques
│   └── ProfileView.swift        # Perfil do usuário, simulador de papéis e notificações
├── ContentView.swift            # TabView com as 5 seções do aplicativo
└── projetomoretoapoiaseApp.swift # Ponto de entrada @main do SwiftUI
```

---

## Backend & Banco de Dados PostgreSQL Local

O backend foi construído em Node.js com conexão direta ao seu PostgreSQL local (`nexo_db`).

### Entidades e CRUDs Cobertos (Seção 5 da Documentação):
1. **Campanha**: Create, Read, Update, Delete.
2. **Doação**: Create (via Pix / Cartão / Boleto com recálculo atômico da meta), Read.
3. **Atualização da Campanha (Mural de Novidades)**: Create, Read, Update, Delete.
4. **Mensagens do Mural**: Create, Read, Delete.
5. **Denúncias**: Create, Read, Update (resolvida/em análise), Delete.
6. **Verificação de ONG**: Create, Read, Update (aprovação/rejeição), Delete.
7. **Categorias**: Create, Read, Update, Delete.
8. **Favoritos**: Create, Read, Delete.
9. **Solicitação de Saque**: Create, Read, Update (aprovação/recusa), Delete.
10. **Notificações**: Create (automático no PostgreSQL após doações), Read, Update (marcar lida), Delete.

---

## Como Executar

### 1. Iniciar a API com PostgreSQL
```bash
cd backend
npm install
npm start        # ou: npm run dev (reinicia automaticamente com nodemon)
```
Para verificar a conexão com o banco: `curl http://localhost:3000/api/health`.

Usuários de teste (senha `123456`): `paulo@vakinha.com` (Criador), `mariana@vakinha.com` (Doador), `admin@vakinha.com` (Admin).

### 2. Rodar o App no Xcode
1. Abra o arquivo `projetomoretoapoiase.xcodeproj` no Xcode.
2. Selecione qualquer simulador iPhone (ex: iPhone 16 Pro).
3. Pressione `Cmd + R` para compilar e executar.

