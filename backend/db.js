const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.PGHOST || 'localhost',
  port: process.env.PGPORT || 5432,
  user: process.env.PGUSER || 'paulohenriquegarbo',
  password: process.env.PGPASSWORD || '',
  database: process.env.PGDATABASE || 'vakinhadb',
});

async function initDB() {
  const client = await pool.connect();
  try {
    await client.query(`
      -- Categorias (CRUD 7)
      CREATE TABLE IF NOT EXISTS categories (
        id VARCHAR(64) PRIMARY KEY,
        name VARCHAR(120) NOT NULL,
        icon_name VARCHAR(64) NOT NULL
      );

      -- Usuários & Autenticação (CRUD 0)
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(64) PRIMARY KEY,
        name VARCHAR(120) NOT NULL,
        email VARCHAR(180) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        avatar_url TEXT,
        role VARCHAR(32) DEFAULT 'Doador',
        latitude NUMERIC(10, 6),
        longitude NUMERIC(10, 6),
        city VARCHAR(100),
        state VARCHAR(50),
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Campanhas (CRUD 1)
      CREATE TABLE IF NOT EXISTS campaigns (
        id VARCHAR(64) PRIMARY KEY,
        creator_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        category_id VARCHAR(64) REFERENCES categories(id) ON DELETE SET NULL,
        title VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        goal_amount NUMERIC(14, 2) NOT NULL,
        current_amount NUMERIC(14, 2) DEFAULT 0.0,
        status VARCHAR(32) DEFAULT 'ativa',
        image_url TEXT,
        latitude NUMERIC(10, 6),
        longitude NUMERIC(10, 6),
        location_name VARCHAR(150),
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Doações (CRUD 2)
      CREATE TABLE IF NOT EXISTS donations (
        id VARCHAR(64) PRIMARY KEY,
        campaign_id VARCHAR(64) NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
        user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
        amount NUMERIC(14, 2) NOT NULL,
        payment_method VARCHAR(64) DEFAULT 'PIX',
        message TEXT,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Atualizações / Novidades da Campanha (CRUD 3)
      CREATE TABLE IF NOT EXISTS campaign_updates (
        id VARCHAR(64) PRIMARY KEY,
        campaign_id VARCHAR(64) NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        content TEXT NOT NULL,
        image_url TEXT,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Mensagens do Mural (CRUD 4)
      CREATE TABLE IF NOT EXISTS wall_messages (
        id VARCHAR(64) PRIMARY KEY,
        campaign_id VARCHAR(64) NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
        user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
        author_name VARCHAR(120),
        message TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Denúncias (CRUD 5)
      CREATE TABLE IF NOT EXISTS reports (
        id VARCHAR(64) PRIMARY KEY,
        campaign_id VARCHAR(64) NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
        reporter_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
        reason TEXT NOT NULL,
        status VARCHAR(32) DEFAULT 'em_analise',
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Verificação de ONG (CRUD 6)
      CREATE TABLE IF NOT EXISTS ngo_verifications (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        organization_name VARCHAR(180) NOT NULL,
        document_number VARCHAR(64) NOT NULL,
        documents_url TEXT,
        status VARCHAR(32) DEFAULT 'pendente',
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Favoritos (CRUD 8)
      CREATE TABLE IF NOT EXISTS favorites (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        campaign_id VARCHAR(64) NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, campaign_id)
      );

      -- Solicitações de Saque (CRUD 9)
      CREATE TABLE IF NOT EXISTS withdrawal_requests (
        id VARCHAR(64) PRIMARY KEY,
        campaign_id VARCHAR(64) NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
        creator_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        amount NUMERIC(14, 2) NOT NULL,
        pix_key VARCHAR(120) NOT NULL,
        status VARCHAR(32) DEFAULT 'em_analise',
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );

      -- Notificações (CRUD 10)
      CREATE TABLE IF NOT EXISTS notifications (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(180) NOT NULL,
        content TEXT NOT NULL,
        is_read BOOLEAN DEFAULT false,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Inserção rica de dados mock no PostgreSQL vakinhadb
    const catCheck = await client.query('SELECT count(*) FROM categories');
    if (parseInt(catCheck.rows[0].count) === 0) {
      console.log('Populando dados completos no PostgreSQL (vakinhadb)...');
      
      await client.query(`
        -- 1. Categorias
        INSERT INTO categories (id, name, icon_name) VALUES
        ('cat-saude', 'Saúde & Tratamentos', 'cross.case.fill'),
        ('cat-animais', 'Causas Animais', 'pawprint.fill'),
        ('cat-educacao', 'Educação & Projetos', 'book.fill'),
        ('cat-comunidade', 'Ajuda Comunitária', 'person.3.fill'),
        ('cat-emergencia', 'Emergências Naturais', 'flame.fill'),
        ('cat-cultura', 'Cultura & Arte', 'paintpalette.fill');

        -- 2. Usuários (Senha padrão mock: 123456 -> hash sha256 simples)
        INSERT INTO users (id, name, email, password_hash, role, latitude, longitude, city, state) VALUES
        ('usr-1', 'Paulo Garbo', 'paulo@vakinha.com', 'e10adc3949ba59abbe56e057f20f883e', 'Criador', -27.1004, -52.6152, 'Chapecó', 'SC'),
        ('usr-2', 'Mariana Santos', 'mariana@vakinha.com', 'e10adc3949ba59abbe56e057f20f883e', 'Doador', -27.0980, -52.6120, 'Chapecó', 'SC'),
        ('usr-3', 'ONG Patas do Bem', 'ong@patasdobem.org', 'e10adc3949ba59abbe56e057f20f883e', 'ONG', -27.1050, -52.6180, 'Chapecó', 'SC'),
        ('usr-4', 'Admin Vakinha', 'admin@vakinha.com', 'e10adc3949ba59abbe56e057f20f883e', 'Admin', -27.1000, -52.6150, 'Chapecó', 'SC'),
        ('usr-5', 'Lucas Oliveira', 'lucas@vakinha.com', 'e10adc3949ba59abbe56e057f20f883e', 'Doador', -27.1120, -52.6200, 'Chapecó', 'SC');

        -- 3. Campanhas (com coordenadas geográficas para mapa nativo)
        INSERT INTO campaigns (id, creator_id, category_id, title, description, goal_amount, current_amount, status, latitude, longitude, location_name) VALUES
        ('cmp-1', 'usr-1', 'cat-saude', 'Cirurgia de Emergência do Theo', 'O Theo foi diagnosticado com luxação congênita e precisa realizar a cirurgia em até 30 dias para não perder os movimentos. Contamos com sua generosidade e orações!', 15000.00, 7850.00, 'ativa', -27.1004, -52.6152, 'Hospital Regional - Chapecó/SC'),
        ('cmp-2', 'usr-3', 'cat-animais', 'Ração e Aquecedores para 120 Cães do Abrigo', 'Com a frente fria histórica se aproximando, nosso abrigo precisa urgentemente de 1.500 kg de ração, mantas térmicas e medicamentos veterinários.', 9500.00, 6200.00, 'ativa', -27.1050, -52.6180, 'Abrigo Patas do Bem - Chapecó/SC'),
        ('cmp-3', 'usr-1', 'cat-educacao', 'Laboratório Maker de Robótica Comunitária', 'Queremos equipar uma sala com impressora 3D, kits de Arduino e computadores para atender 60 jovens da periferia aos sábados.', 22000.00, 14300.00, 'ativa', -27.0980, -52.6120, 'Centro Comunitário Efapi - SC'),
        ('cmp-4', 'usr-3', 'cat-comunidade', 'Reconstrução da Cozinha Comunitária', 'Após as fortes enchentes, nossa cozinha que serve 200 refeições diárias perdeu geladeiras, fogões industriais e alimentos.', 18000.00, 4100.00, 'ativa', -27.1120, -52.6200, 'Bairro São Pedro - Chapecó/SC'),
        ('cmp-5', 'usr-1', 'cat-emergencia', 'Fundo de Apoio a Famílias Desabrigadas pelas Chuvas', 'Mobilização rápida para compra de cestas básicas, colchões e kits de higiene para famílias atingidas pelo temporal na região.', 12000.00, 8900.00, 'ativa', -27.1020, -52.6140, 'Chapecó e Região Oeste/SC');

        -- 4. Doações
        INSERT INTO donations (id, campaign_id, user_id, amount, payment_method, message) VALUES
        ('don-1', 'cmp-1', 'usr-2', 200.00, 'PIX', 'Força amigão, já deu tudo certo na cirurgia!'),
        ('don-2', 'cmp-1', 'usr-5', 150.00, 'Cartão de Crédito', 'Deus abençoe a família e a equipe médica.'),
        ('don-3', 'cmp-2', 'usr-2', 100.00, 'PIX', 'Pelos nossos anjinhos de quatro patas!'),
        ('don-4', 'cmp-2', 'usr-1', 250.00, 'PIX', 'Trabalho lindo que vocês fazem no abrigo.'),
        ('don-5', 'cmp-3', 'usr-5', 500.00, 'Boleto', 'Educação transforma tudo! Sucesso no projeto maker.'),
        ('don-6', 'cmp-4', 'usr-2', 80.00, 'PIX', 'Ninguém merece passar fome. Tamo junto!'),
        ('don-7', 'cmp-5', 'usr-5', 300.00, 'PIX', 'Solidariedade sempre.');

        -- 5. Atualizações / Novidades (Prestação de Contas)
        INSERT INTO campaign_updates (id, campaign_id, title, content) VALUES
        ('upd-1', 'cmp-1', 'Exames Pré-Operatórios Aprovados!', 'Hoje realizamos todos os exames de sangue e ressonância no Hospital Regional. Os médicos confirmaram que a cirurgia poderá ser agendada para semana que vem!'),
        ('upd-2', 'cmp-2', 'Primeira remessa de ração entregue', 'Com os primeiros valores recebidos via PIX, compramos 400kg de ração Special Dog e já começamos a distribuição nas baias. Gratidão eterna!'),
        ('upd-3', 'cmp-3', 'Orçamento das impressoras 3D fechado', 'Conseguimos 15% de desconto com o fornecedor local para os dois primeiros equipamentos!');

        -- 6. Mural de Mensagens
        INSERT INTO wall_messages (id, campaign_id, user_id, author_name, message) VALUES
        ('msg-1', 'cmp-1', 'usr-2', 'Mariana Santos', 'Theo, Chapecó inteira está torcendo por você!'),
        ('msg-2', 'cmp-1', 'usr-5', 'Lucas Oliveira', 'Toda oração e apoio para a recuperação rápida.'),
        ('msg-3', 'cmp-2', 'usr-2', 'Mariana Santos', 'Obrigada pelo amor com os animais resgatados.'),
        ('msg-4', 'cmp-3', 'usr-5', 'Lucas Oliveira', 'Quando inaugurar quero ir conhecer a sala de robótica!');

        -- 7. Denúncias (Moderação Admin)
        INSERT INTO reports (id, campaign_id, reporter_id, reason, status) VALUES
        ('rep-1', 'cmp-4', 'usr-5', 'Gostaria de ver as fotos das notas fiscais dos eletrodomésticos adquiridos.', 'em_analise'),
        ('rep-2', 'cmp-5', 'usr-2', 'Campanha duplicada na comunidade de apoio.', 'resolvida');

        -- 8. Verificações de ONG (Homologação de Selo)
        INSERT INTO ngo_verifications (id, user_id, organization_name, document_number, documents_url, status, notes) VALUES
        ('vng-1', 'usr-3', 'Associação Protetora Patas do Bem', '12.345.678/0001-90', 'https://patasdobem.org/estatuto_cnpj.pdf', 'aprovado', 'Estatuto registrado em cartório e CNPJ ativo.'),
        ('vng-2', 'usr-1', 'Instituto Juventude e Futuro', '98.765.432/0001-11', 'https://juventude.org/documentos.zip', 'pendente', 'Aguardando certidão negativa de débitos estaduais.');

        -- 9. Favoritos
        INSERT INTO favorites (id, user_id, campaign_id) VALUES
        ('fav-1', 'usr-1', 'cmp-2'),
        ('fav-2', 'usr-1', 'cmp-3'),
        ('fav-3', 'usr-2', 'cmp-1');

        -- 10. Solicitações de Saque
        INSERT INTO withdrawal_requests (id, campaign_id, creator_id, amount, pix_key, status) VALUES
        ('wth-1', 'cmp-1', 'usr-1', 5000.00, 'paulo@vakinha.com', 'aprovado'),
        ('wth-2', 'cmp-2', 'usr-3', 3000.00, '12.345.678/0001-90', 'em_analise');

        -- 11. Notificações
        INSERT INTO notifications (id, user_id, title, content, is_read) VALUES
        ('not-1', 'usr-1', 'Nova Doação Recebida!', 'Lucas Oliveira doou R$ 150,00 na campanha do Theo via Cartão de Crédito.', false),
        ('not-2', 'usr-1', 'Saque Aprovado!', 'Sua solicitação de saque de R$ 5.000,00 foi autorizada e creditada via PIX.', true),
        ('not-3', 'usr-3', 'Selo de ONG Homologado!', 'Parabéns! Sua organização agora tem o selo de verificação oficial da Vakinha.', false);
      `);
    }
  } finally {
    client.release();
  }
}

module.exports = { pool, initDB };
