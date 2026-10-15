-- NEXO — schema PostgreSQL (banco padrão: postgres / usuário postgres / senha postgres / porta 5432)
-- Executar: psql -h localhost -U postgres -d postgres -f schema.sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS usuarios (
  id          BIGSERIAL PRIMARY KEY,
  nome        TEXT NOT NULL,
  email       TEXT NOT NULL UNIQUE,
  senha_hash  TEXT NOT NULL,
  perfil      TEXT NOT NULL DEFAULT 'usuario' CHECK (perfil IN ('usuario','ong','admin')),
  verificado  BOOLEAN NOT NULL DEFAULT FALSE,
  criado_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS categorias (
  id   BIGSERIAL PRIMARY KEY,
  nome TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS campanhas (
  id           BIGSERIAL PRIMARY KEY,
  criador_id   BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  categoria_id BIGINT REFERENCES categorias(id) ON DELETE SET NULL,
  titulo       TEXT NOT NULL,
  descricao    TEXT NOT NULL,
  meta         NUMERIC(12,2) NOT NULL CHECK (meta > 0),
  cidade       TEXT NOT NULL DEFAULT '',
  foto_url     TEXT,
  status       TEXT NOT NULL DEFAULT 'ativa' CHECK (status IN ('ativa','pausada','encerrada')),
  criada_em    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Doações não podem ser alteradas nem excluídas (apenas estorno via suporte)
CREATE TABLE IF NOT EXISTS doacoes (
  id          BIGSERIAL PRIMARY KEY,
  campanha_id BIGINT NOT NULL REFERENCES campanhas(id) ON DELETE RESTRICT,
  doador_id   BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
  valor       NUMERIC(12,2) NOT NULL CHECK (valor > 0),
  metodo      TEXT NOT NULL CHECK (metodo IN ('pix','cartao')),
  criada_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS novidades (
  id          BIGSERIAL PRIMARY KEY,
  campanha_id BIGINT NOT NULL REFERENCES campanhas(id) ON DELETE CASCADE,
  texto       TEXT NOT NULL,
  anexo_url   TEXT,
  criada_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mensagens (
  id          BIGSERIAL PRIMARY KEY,
  campanha_id BIGINT NOT NULL REFERENCES campanhas(id) ON DELETE CASCADE,
  autor_id    BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  texto       TEXT NOT NULL,
  criada_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS denuncias (
  id          BIGSERIAL PRIMARY KEY,
  campanha_id BIGINT NOT NULL REFERENCES campanhas(id) ON DELETE CASCADE,
  autor_id    BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  motivo      TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente','em_analise','resolvida','arquivada')),
  criada_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS verificacoes_ong (
  id            BIGSERIAL PRIMARY KEY,
  usuario_id    BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  documento_url TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente','aprovado','reprovado','pendente_documento')),
  criada_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS favoritos (
  usuario_id  BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  campanha_id BIGINT NOT NULL REFERENCES campanhas(id) ON DELETE CASCADE,
  PRIMARY KEY (usuario_id, campanha_id)
);

CREATE TABLE IF NOT EXISTS saques (
  id          BIGSERIAL PRIMARY KEY,
  campanha_id BIGINT NOT NULL REFERENCES campanhas(id) ON DELETE CASCADE,
  valor       NUMERIC(12,2) NOT NULL CHECK (valor > 0),
  status      TEXT NOT NULL DEFAULT 'em_analise' CHECK (status IN ('em_analise','aprovado','rejeitado')),
  criada_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notificacoes (
  id          BIGSERIAL PRIMARY KEY,
  usuario_id  BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  texto       TEXT NOT NULL,
  lida        BOOLEAN NOT NULL DEFAULT FALSE,
  criada_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Notificação automática ao criador a cada nova doação (RF12)
CREATE OR REPLACE FUNCTION notifica_doacao() RETURNS trigger AS $$
BEGIN
  INSERT INTO notificacoes (usuario_id, texto)
  SELECT c.criador_id, 'Nova doação de R$ ' || NEW.valor || ' em "' || c.titulo || '"'
  FROM campanhas c WHERE c.id = NEW.campanha_id;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notifica_doacao ON doacoes;
CREATE TRIGGER trg_notifica_doacao AFTER INSERT ON doacoes
  FOR EACH ROW EXECUTE FUNCTION notifica_doacao();

-- Dados iniciais
INSERT INTO categorias (nome) VALUES ('Saúde'),('Educação'),('Animais'),('Emergência'),('Social')
  ON CONFLICT DO NOTHING;
INSERT INTO usuarios (nome, email, senha_hash, perfil, verificado)
  VALUES ('Admin', 'admin@nexo.com', crypt('admin123', gen_salt('bf')), 'admin', TRUE)
  ON CONFLICT DO NOTHING;
