-- ============================================================================
-- PROJETO NEXO (app-Vakinha) — SCHEMA COMPLETO E MOTOR PL/pgSQL (PostgreSQL)
-- ============================================================================
-- Executar em: vakinhadb
-- Contém:
--   1. Criação das 11 tabelas relacionais com Constraints e FKs (ON DELETE CASCADE)
--   2. Índices de performance para filtros geográficos, buscas e chaves estrangeiras
--   3. Funções e Triggers PL/pgSQL para integridade transacional automática
--   4. Carga de Seed Inicial Completa (19 campanhas, 14 usuários, 6 categorias, etc.)
-- ============================================================================

BEGIN;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- ============================================================================
-- 1. ESTRUTURA DE TABELAS (11 ENTIDADES DO DOMÍNIO NEXO)
-- ============================================================================

-- 1.1 Categorias de Campanhas
CREATE TABLE IF NOT EXISTS public.categories (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    icon_name VARCHAR(64) NOT NULL
);

-- 1.2 Usuários & Controle de Acesso (RBAC: Doador, Criador, ONG, Admin)
CREATE TABLE IF NOT EXISTS public.users (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(180) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    avatar_url TEXT,
    role VARCHAR(32) NOT NULL DEFAULT 'Doador' CHECK (role IN ('Doador', 'Criador', 'ONG', 'Admin')),
    latitude NUMERIC(10, 6),
    longitude NUMERIC(10, 6),
    city VARCHAR(100),
    state VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 1.3 Campanhas Solidárias (Vaquinhas)
CREATE TABLE IF NOT EXISTS public.campaigns (
    id VARCHAR(64) PRIMARY KEY,
    creator_id VARCHAR(64) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    category_id VARCHAR(64) REFERENCES public.categories(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    goal_amount NUMERIC(14, 2) NOT NULL CHECK (goal_amount > 0),
    current_amount NUMERIC(14, 2) NOT NULL DEFAULT 0.00 CHECK (current_amount >= 0),
    status VARCHAR(32) NOT NULL DEFAULT 'ativa' CHECK (status IN ('ativa', 'concluida', 'encerrada', 'suspensa')),
    image_url TEXT,
    latitude NUMERIC(10, 6),
    longitude NUMERIC(10, 6),
    location_name VARCHAR(150),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 1.4 Doações Financeiras
CREATE TABLE IF NOT EXISTS public.donations (
    id VARCHAR(64) PRIMARY KEY,
    campaign_id VARCHAR(64) NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    user_id VARCHAR(64) REFERENCES public.users(id) ON DELETE SET NULL,
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    payment_method VARCHAR(64) NOT NULL DEFAULT 'PIX',
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 1.5 Atualizações / Prestação de Contas da Campanha (Novidades)
CREATE TABLE IF NOT EXISTS public.campaign_updates (
    id VARCHAR(64) PRIMARY KEY,
    campaign_id VARCHAR(64) NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 1.6 Mural de Mensagens de Apoio
CREATE TABLE IF NOT EXISTS public.wall_messages (
    id VARCHAR(64) PRIMARY KEY,
    campaign_id VARCHAR(64) NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    user_id VARCHAR(64) REFERENCES public.users(id) ON DELETE CASCADE,
    author_name VARCHAR(120),
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 1.7 Denúncias e Moderação (Reports)
CREATE TABLE IF NOT EXISTS public.reports (
    id VARCHAR(64) PRIMARY KEY,
    campaign_id VARCHAR(64) NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    reporter_id VARCHAR(64) REFERENCES public.users(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'em_analise' CHECK (status IN ('em_analise', 'resolvida', 'arquivada', 'rejeitada')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 1.8 Verificações e Homologação de ONGs (Selo Verificado)
CREATE TABLE IF NOT EXISTS public.ngo_verifications (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    organization_name VARCHAR(180) NOT NULL,
    document_number VARCHAR(64) NOT NULL,
    documents_url TEXT,
    status VARCHAR(32) NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'aprovado', 'rejeitado')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 1.9 Campanhas Favoritas dos Usuários
CREATE TABLE IF NOT EXISTS public.favorites (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    campaign_id VARCHAR(64) NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT favorites_user_id_campaign_id_key UNIQUE (user_id, campaign_id)
);

-- 1.10 Solicitações de Saque via PIX (Withdrawals)
CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
    id VARCHAR(64) PRIMARY KEY,
    campaign_id VARCHAR(64) NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
    creator_id VARCHAR(64) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    pix_key VARCHAR(120) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'em_analise' CHECK (status IN ('em_analise', 'aprovado', 'rejeitado')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 1.11 Central de Notificações do Usuário
CREATE TABLE IF NOT EXISTS public.notifications (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title VARCHAR(180) NOT NULL,
    content TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 2. ÍNDICES DE OTIMIZAÇÃO DE CONSULTAS
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_campaigns_creator_id ON public.campaigns(creator_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_category_id ON public.campaigns(category_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON public.campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_geo ON public.campaigns(latitude, longitude) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_donations_campaign_id ON public.donations(campaign_id);
CREATE INDEX IF NOT EXISTS idx_donations_user_id ON public.donations(user_id);
CREATE INDEX IF NOT EXISTS idx_campaign_updates_campaign_id ON public.campaign_updates(campaign_id);
CREATE INDEX IF NOT EXISTS idx_wall_messages_campaign_id ON public.wall_messages(campaign_id);
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON public.favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_withdrawals_creator_id ON public.withdrawal_requests(creator_id);

-- ============================================================================
-- 3. FUNÇÕES E TRIGGERS PL/pgSQL (CONTROLE TRANSACIONAL NO BANCO)
-- ============================================================================

-- 3.1 Validação Pré-Doação: garante que apenas campanhas ativas recebam doações
CREATE OR REPLACE FUNCTION public.fn_validate_donation_before_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(32);
BEGIN
    SELECT status INTO v_status
    FROM public.campaigns
    WHERE id = NEW.campaign_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Campanha (%) não encontrada.', NEW.campaign_id;
    END IF;

    IF v_status <> 'ativa' THEN
        RAISE EXCEPTION 'Esta campanha não está mais recebendo doações (status atual: %).', v_status;
    END IF;

    IF NEW.amount <= 0 THEN
        RAISE EXCEPTION 'O valor da doação deve ser maior que zero.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_donation_before_insert ON public.donations;
CREATE TRIGGER trg_validate_donation_before_insert
BEFORE INSERT ON public.donations
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_donation_before_insert();

-- 3.2 Pós-Doação / Estorno: atualiza saldo arrecadado da campanha e dispara notificação ao criador
CREATE OR REPLACE FUNCTION public.fn_process_donation_balance_and_notify()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_creator_id VARCHAR(64);
    v_campaign_title VARCHAR(255);
    v_notif_id VARCHAR(64);
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Incrementa o saldo arrecadado da campanha atomicamente
        UPDATE public.campaigns
        SET current_amount = current_amount + NEW.amount
        WHERE id = NEW.campaign_id
        RETURNING creator_id, title INTO v_creator_id, v_campaign_title;

        -- Cria notificação automática para o criador da campanha
        IF v_creator_id IS NOT NULL THEN
            v_notif_id := 'not-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(md5(random()::text), 1, 6);
            INSERT INTO public.notifications (id, user_id, title, content, is_read, created_at)
            VALUES (
                v_notif_id,
                v_creator_id,
                'Nova Doação Recebida!',
                format('Sua vaquinha "%s" recebeu R$ %s via %s.', v_campaign_title, to_char(NEW.amount, 'FM999G999G990D00'), COALESCE(NEW.payment_method, 'PIX')),
                FALSE,
                CURRENT_TIMESTAMP
            );
        END IF;
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        -- Em caso de estorno/remoção de doação, subtrai do saldo sem ficar negativo
        UPDATE public.campaigns
        SET current_amount = GREATEST(0.00, current_amount - OLD.amount)
        WHERE id = OLD.campaign_id;
        RETURN OLD;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Ajusta diferença se o valor da doação for alterado
        IF NEW.amount <> OLD.amount THEN
            UPDATE public.campaigns
            SET current_amount = GREATEST(0.00, current_amount + (NEW.amount - OLD.amount))
            WHERE id = NEW.campaign_id;
        END IF;
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_process_donation_balance_and_notify ON public.donations;
CREATE TRIGGER trg_process_donation_balance_and_notify
AFTER INSERT OR UPDATE OR DELETE ON public.donations
FOR EACH ROW
EXECUTE FUNCTION public.fn_process_donation_balance_and_notify();

-- 3.3 Validação e Notificação de Saques (Withdrawal Requests)
CREATE OR REPLACE FUNCTION public.fn_handle_withdrawal_events()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_amount NUMERIC(14, 2);
    v_campaign_title VARCHAR(255);
    v_notif_id VARCHAR(64);
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT current_amount, title INTO v_current_amount, v_campaign_title
        FROM public.campaigns
        WHERE id = NEW.campaign_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Campanha informada para saque não existe.';
        END IF;

        IF NEW.amount > v_current_amount THEN
            RAISE EXCEPTION 'Saldo insuficiente na campanha (Disponível: R$ %, Solicitado: R$ %).', v_current_amount, NEW.amount;
        END IF;

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Quando o status do saque muda (ex: aprovado ou rejeitado pelo Admin), notifica o criador
        IF NEW.status IS DISTINCT FROM OLD.status THEN
            SELECT title INTO v_campaign_title FROM public.campaigns WHERE id = NEW.campaign_id;
            v_notif_id := 'not-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(md5(random()::text), 1, 6);

            IF NEW.status = 'aprovado' THEN
                INSERT INTO public.notifications (id, user_id, title, content, is_read)
                VALUES (
                    v_notif_id,
                    NEW.creator_id,
                    'Saque Aprovado!',
                    format('Sua solicitação de saque de R$ %s da campanha "%s" foi autorizada e creditada na chave PIX %s.',
                           to_char(NEW.amount, 'FM999G999G990D00'), COALESCE(v_campaign_title, ''), NEW.pix_key),
                    FALSE
                );
            ELSIF NEW.status = 'rejeitado' THEN
                INSERT INTO public.notifications (id, user_id, title, content, is_read)
                VALUES (
                    v_notif_id,
                    NEW.creator_id,
                    'Solicitação de Saque Recusada',
                    format('Sua solicitação de saque de R$ %s na campanha "%s" não pôde ser aprovada. Verifique seus dados bancários.',
                           to_char(NEW.amount, 'FM999G999G990D00'), COALESCE(v_campaign_title, '')),
                    FALSE
                );
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_withdrawal_before_insert ON public.withdrawal_requests;
CREATE TRIGGER trg_withdrawal_before_insert
BEFORE INSERT ON public.withdrawal_requests
FOR EACH ROW
EXECUTE FUNCTION public.fn_handle_withdrawal_events();

DROP TRIGGER IF EXISTS trg_withdrawal_after_update ON public.withdrawal_requests;
CREATE TRIGGER trg_withdrawal_after_update
AFTER UPDATE ON public.withdrawal_requests
FOR EACH ROW
EXECUTE FUNCTION public.fn_handle_withdrawal_events();

-- 3.4 Homologação Automática de ONG: promove papel do usuário e envia notificação oficial
CREATE OR REPLACE FUNCTION public.fn_handle_ngo_verification_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_notif_id VARCHAR(64);
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        v_notif_id := 'not-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || substr(md5(random()::text), 1, 6);

        IF NEW.status = 'aprovado' THEN
            -- Garante que o usuário receba o perfil ONG caso ainda não seja Admin
            UPDATE public.users
            SET role = CASE WHEN role = 'Admin' THEN 'Admin' ELSE 'ONG' END
            WHERE id = NEW.user_id;

            INSERT INTO public.notifications (id, user_id, title, content, is_read)
            VALUES (
                v_notif_id,
                NEW.user_id,
                'Selo de ONG Homologado!',
                format('Parabéns! A organização "%s" agora possui o selo de verificação oficial da NEXO Vakinha.', NEW.organization_name),
                FALSE
            );
        ELSIF NEW.status = 'rejeitado' THEN
            INSERT INTO public.notifications (id, user_id, title, content, is_read)
            VALUES (
                v_notif_id,
                NEW.user_id,
                'Verificação de ONG Pendente de Ajustes',
                format('A documentação de "%s" precisa de revisão. Observações: %s', NEW.organization_name, COALESCE(NEW.notes, 'Verifique os documentos enviados.')),
                FALSE
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ngo_verification_after_update ON public.ngo_verifications;
CREATE TRIGGER trg_ngo_verification_after_update
AFTER UPDATE ON public.ngo_verifications
FOR EACH ROW
EXECUTE FUNCTION public.fn_handle_ngo_verification_status();


-- ============================================================================
-- 4. CARGA DE DADOS INICIAL (SEED COMPLETO DE PRODUÇÃO/DEMONSTRAÇÃO)
-- ============================================================================
-- Desabilitamos temporariamente os triggers de doação/saque durante o seed
-- para preservar os saldos históricos consolidados e timestamps originais.
ALTER TABLE public.donations DISABLE TRIGGER trg_validate_donation_before_insert;
ALTER TABLE public.donations DISABLE TRIGGER trg_process_donation_balance_and_notify;
ALTER TABLE public.withdrawal_requests DISABLE TRIGGER trg_withdrawal_before_insert;
ALTER TABLE public.withdrawal_requests DISABLE TRIGGER trg_withdrawal_after_update;
ALTER TABLE public.ngo_verifications DISABLE TRIGGER trg_ngo_verification_after_update;

-- 4.1 Categorias (6 categorias oficiais com SF Symbols nativos do iOS)
INSERT INTO public.categories (id, name, icon_name) VALUES
    ('cat-saude', 'Saúde & Tratamentos', 'cross.case.fill'),
    ('cat-animais', 'Causas Animais', 'pawprint.fill'),
    ('cat-educacao', 'Educação & Projetos', 'book.fill'),
    ('cat-comunidade', 'Ajuda Comunitária', 'person.3.fill'),
    ('cat-emergencia', 'Emergências Naturais', 'flame.fill'),
    ('cat-cultura', 'Cultura & Arte', 'paintpalette.fill')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    icon_name = EXCLUDED.icon_name;

-- 4.2 Usuários (14 perfis cobrindo Criador, Doador, ONG e Admin; senha padrão: 123456)
INSERT INTO public.users (id, name, email, password_hash, avatar_url, role, latitude, longitude, city, state, created_at) VALUES
    ('usr-1', 'Paulo Garbo', 'paulo@vakinha.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Criador', -27.100400, -52.615200, 'Chapecó', 'SC', '2026-10-22 20:03:59.046428-03'),
    ('usr-2', 'Mariana Santos', 'mariana@vakinha.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Doador', -27.098000, -52.612000, 'Chapecó', 'SC', '2026-10-22 20:03:59.046428-03'),
    ('usr-3', 'ONG Patas do Bem', 'ong@patasdobem.org', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'ONG', -27.105000, -52.618000, 'Chapecó', 'SC', '2026-10-22 20:03:59.046428-03'),
    ('usr-4', 'Admin Vakinha', 'admin@vakinha.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Admin', -27.100000, -52.615000, 'Chapecó', 'SC', '2026-10-22 20:03:59.046428-03'),
    ('usr-5', 'Lucas Oliveira', 'lucas@vakinha.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Doador', -27.112000, -52.620000, 'Chapecó', 'SC', '2026-10-22 20:03:59.046428-03'),
    ('usr-6', 'Instituto Reabilitar', 'contato@reabilitar.org', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'ONG', -27.095000, -52.620000, 'Chapeco', 'SC', '2026-10-22 20:36:59.692625-03'),
    ('usr-7', 'Camila Rodrigues', 'camila.rodrigues@email.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Criador', -27.102000, -52.610000, 'Chapeco', 'SC', '2026-10-22 20:36:59.692625-03'),
    ('usr-8', 'Projeto Sementes do Futuro', 'sementes@futuro.org', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'ONG', -27.108000, -52.605000, 'Chapeco', 'SC', '2026-10-22 20:36:59.692625-03'),
    ('usr-9', 'Rodrigo Mendes', 'rodrigo.mendes@email.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Criador', -27.115000, -52.625000, 'Chapeco', 'SC', '2026-10-22 20:36:59.692625-03'),
    ('usr-10', 'Juliana Lima', 'juliana.lima@email.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Doador', -27.100000, -52.615000, 'Chapeco', 'SC', '2026-10-22 20:36:59.692625-03'),
    ('usr-bruno', 'Bruno Lima', 'bruno@email.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Criador', NULL, NULL, 'Porto Alegre', 'RS', '2026-10-22 20:48:59.794983-03'),
    ('usr-carla', 'Carla Souza', 'carla@email.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Criador', NULL, NULL, 'Chapeco', 'SC', '2026-10-22 20:48:59.794983-03'),
    ('usr-felipe', 'Felipe Santos', 'felipe@email.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Criador', NULL, NULL, 'Florianopolis', 'SC', '2026-10-22 20:48:59.794983-03'),
    ('usr-amanda', 'Amanda Ribeiro', 'amanda@email.com', 'e10adc3949ba59abbe56e057f20f883e', NULL, 'Criador', NULL, NULL, 'Curitiba', 'PR', '2026-10-22 20:48:59.794983-03')
ON CONFLICT (id) DO NOTHING;

-- 4.3 Campanhas (19 campanhas com URLs de imagem CDN rápidas e geolocalização)
INSERT INTO public.campaigns (id, creator_id, category_id, title, description, goal_amount, current_amount, status, image_url, latitude, longitude, location_name, created_at) VALUES
    ('cmp-1', 'usr-1', 'cat-saude', 'Cirurgia de Emergência do Theo', 'O Theo foi diagnosticado com luxação congênita e precisa realizar a cirurgia em até 30 dias para não perder os movimentos. Contamos com sua generosidade e orações!', 15000.00, 7850.00, 'ativa', 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=1200&q=80', -27.100400, -52.615200, 'Hospital Regional - Chapecó/SC', '2026-10-22 20:03:59.046428-03'),
    ('cmp-2', 'usr-3', 'cat-animais', 'Ração e Aquecedores para 120 Cães do Abrigo', 'Com a frente fria histórica se aproximando, nosso abrigo precisa urgentemente de 1.500 kg de ração, mantas térmicas e medicamentos veterinários.', 9500.00, 6200.00, 'ativa', 'https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=1200&q=80', -27.105000, -52.618000, 'Abrigo Patas do Bem - Chapecó/SC', '2026-10-22 20:03:59.046428-03'),
    ('cmp-3', 'usr-1', 'cat-educacao', 'Laboratório Maker de Robótica Comunitária', 'Queremos equipar uma sala com impressora 3D, kits de Arduino e computadores para atender 60 jovens da periferia aos sábados.', 22000.00, 14300.00, 'ativa', 'https://images.unsplash.com/photo-1581092918056-0c4c3acd3789?auto=format&fit=crop&w=1200&q=80', -27.098000, -52.612000, 'Centro Comunitário Efapi - SC', '2026-10-22 20:03:59.046428-03'),
    ('cmp-4', 'usr-3', 'cat-comunidade', 'Reconstrução da Cozinha Comunitária', 'Após as fortes enchentes, nossa cozinha que serve 200 refeições diárias perdeu geladeiras, fogões industriais e alimentos.', 18000.00, 4100.00, 'ativa', 'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?auto=format&fit=crop&w=1200&q=80', -27.112000, -52.620000, 'Bairro São Pedro - Chapecó/SC', '2026-10-22 20:03:59.046428-03'),
    ('cmp-5', 'usr-1', 'cat-emergencia', 'Fundo de Apoio a Famílias Desabrigadas pelas Chuvas', 'Mobilização rápida para compra de cestas básicas, colchões e kits de higiene para famílias atingidas pelo temporal na região.', 12000.00, 8900.00, 'ativa', 'https://images.unsplash.com/photo-1532629345422-7515f3d16bb9?auto=format&fit=crop&w=1200&q=80', -27.102000, -52.614000, 'Chapecó e Região Oeste/SC', '2026-10-22 20:03:59.046428-03'),
    ('cmp-6', 'usr-6', 'cat-saude', 'Cadeira de Rodas Motorizada para o Davi', 'O Davi tem 9 anos e nasceu com paralisia cerebral severa. Uma cadeira motorizada permitira que ele frequente a escola regular com autonomia e dignidade.', 18500.00, 11200.00, 'ativa', 'https://images.unsplash.com/photo-1576765608535-5f04d1e3f289?auto=format&fit=crop&w=1200&q=80', -27.095000, -52.620000, 'Centro de Reabilitacao - Chapeco/SC', '2026-10-22 20:36:59.692625-03'),
    ('cmp-7', 'usr-7', 'cat-animais', 'Tratamento de 15 Gatinhos Resgatados de Acumulacao', 'Resgatamos 15 filhotes em situacao de maus-tratos extremos. Precisamos de soro, antibacterianos, vacinas polivalentes e racao umida medicamentosa.', 6200.00, 4850.00, 'ativa', 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=1200&q=80', -27.102000, -52.610000, 'Clinica Veterinaria Popular - Chapeco/SC', '2026-10-22 20:36:59.692625-03'),
    ('cmp-8', 'usr-8', 'cat-educacao', 'Reforma da Biblioteca Comunitaria Bairro Efapi', 'Queremos trocar o telhado que possui vazamentos e comprar 350 livros infanto-juvenis para incentivar a leitura das criancas da comunidade.', 14000.00, 9300.00, 'ativa', 'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?auto=format&fit=crop&w=1200&q=80', -27.108000, -52.605000, 'Bairro Efapi - Chapeco/SC', '2026-10-22 20:36:59.692625-03'),
    ('cmp-9', 'usr-9', 'cat-comunidade', 'Poco Artesiano para Comunidade Rural', 'Mais de 30 familias do interior sofrem com a estiagem historica. A perfuracao do poco garantira agua potavel nas residencias e hortas familiares.', 32000.00, 21400.00, 'ativa', 'https://images.unsplash.com/photo-1541888946425-d0fbb186c5f7?auto=format&fit=crop&w=1200&q=80', -27.115000, -52.625000, 'Linha Tomazelli - Interior Chapeco/SC', '2026-10-22 20:36:59.692625-03'),
    ('cmp-10', 'usr-7', 'cat-cultura', 'Instrumentos Musicais para Orquestra Jovem', 'Inclusao social atraves da musica classica. Precisamos comprar violinos, violoncelos e flautas para 45 criancas da rede publica.', 26000.00, 15800.00, 'ativa', 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?auto=format&fit=crop&w=1200&q=80', -27.100400, -52.615200, 'Teatro Municipal - Chapeco/SC', '2026-10-22 20:36:59.692625-03'),
    ('cmp-11', 'usr-3', 'cat-animais', 'Castracao Solidaria para 200 Animais de Rua', 'O controle populacional etico previne o abandono e doencas. A campanha cobrira os custos cirurgicos de veterinarios parceiros para caes e gatos errantes.', 16000.00, 12900.00, 'ativa', 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=1200&q=80', -27.105000, -52.618000, 'Centro de Castracao Municipal - Chapeco/SC', '2026-10-22 20:36:59.692625-03'),
    ('cmp-12', 'usr-1', 'cat-saude', 'Protese Transtibial para o Professor Roberto', 'Apos complicacoes do diabetes o professor Roberto precisou amputar a perna. Uma protese de carbono moderna permitira que ele volte a lecionar em pe.', 28000.00, 19600.00, 'ativa', 'https://images.unsplash.com/photo-1584432810601-6c7f27d2362b?auto=format&fit=crop&w=1200&q=80', -27.098000, -52.612000, 'Clinica Ortopedica Chapeco/SC', '2026-10-22 20:36:59.692625-03'),
    ('cmp-13', 'usr-8', 'cat-comunidade', 'Paineis Solares para Casa Lar de Idosos', 'A conta de energia consome 40 por cento do orcamento da instituicao. A instalacao solar gerara economia imediata que sera revertida em medicamentos e fisioterapia.', 38000.00, 24500.00, 'ativa', 'https://images.unsplash.com/photo-1509391365360-2e959784a276?auto=format&fit=crop&w=1200&q=80', -27.103000, -52.617000, 'Lar dos Velhinhos - Chapeco/SC', '2026-10-22 20:36:59.692625-03'),
    ('cmp-note', 'usr-bruno', 'cat-educacao', 'Notebook para estudar', 'Preciso de um notebook para acompanhar as aulas da faculdade de computacao e fazer meus projetos de programacao.', 3500.00, 900.00, 'ativa', 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=1200&q=80', NULL, NULL, 'Porto Alegre - RS', '2026-10-22 20:48:59.794983-03'),
    ('cmp-animais-resgate', 'usr-carla', 'cat-animais', 'Ajuda para resgate de animais', 'Fundo de apoio para socorrer e medicar animais abandonados em situacao de vulnerabilidade.', 4200.00, 1600.00, 'ativa', 'https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=1200&q=80', NULL, NULL, 'Chapeco - SC', '2026-10-22 20:48:59.794983-03'),
    ('cmp-medicamentos', 'usr-felipe', 'cat-saude', 'Medicamentos para tratamento continuo', 'Tratamento de doenca autoimune rara. O SUS nao fornece a medicacao importada de uso diario.', 8500.00, 4800.00, 'ativa', 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=1200&q=80', NULL, NULL, 'Florianopolis - SC', '2026-10-22 20:48:59.794983-03'),
    ('cmp-horta', 'usr-amanda', 'cat-comunidade', 'Horta comunitaria do bairro', 'Criacao de horta agroecologica para distribuir alimentos frescos e saudaveis para familias carentes.', 5000.00, 3100.00, 'ativa', 'https://images.unsplash.com/photo-1592417817098-8f3d6eb22509?auto=format&fit=crop&w=1200&q=80', NULL, NULL, 'Curitiba - PR', '2026-10-22 20:48:59.794983-03'),
    ('cmp-bazar', 'usr-bruno', 'cat-cultura', 'Espaco cultural e oficina de arte', 'Reforma do salao comunitario para oficinas semanais gratuitas de pintura e escultura para criancas.', 6000.00, 2200.00, 'ativa', 'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=1200&q=80', NULL, NULL, 'Porto Alegre - RS', '2026-10-22 20:48:59.794983-03'),
    ('cmp-agasalho', 'usr-carla', 'cat-emergencia', 'Campanha do agasalho e cobertores', 'Arrecadacao urgente para compra de 200 cobertores e agasalhos pesados para moradores em situacao de rua.', 4500.00, 3900.00, 'ativa', 'https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?auto=format&fit=crop&w=1200&q=80', NULL, NULL, 'Chapeco - SC', '2026-10-22 20:48:59.794983-03')
ON CONFLICT (id) DO NOTHING;

-- 4.4 Doações (15 doações iniciais)
INSERT INTO public.donations (id, campaign_id, user_id, amount, payment_method, message, created_at) VALUES
    ('don-1', 'cmp-1', 'usr-2', 200.00, 'PIX', 'Força amigão, já deu tudo certo na cirurgia!', '2026-10-22 20:03:59.046428-03'),
    ('don-2', 'cmp-1', 'usr-5', 150.00, 'Cartão de Crédito', 'Deus abençoe a família e a equipe médica.', '2026-10-22 20:03:59.046428-03'),
    ('don-3', 'cmp-2', 'usr-2', 100.00, 'PIX', 'Pelos nossos anjinhos de quatro patas!', '2026-10-22 20:03:59.046428-03'),
    ('don-4', 'cmp-2', 'usr-1', 250.00, 'PIX', 'Trabalho lindo que vocês fazem no abrigo.', '2026-10-22 20:03:59.046428-03'),
    ('don-5', 'cmp-3', 'usr-5', 500.00, 'Boleto', 'Educação transforma tudo! Sucesso no projeto maker.', '2026-10-22 20:03:59.046428-03'),
    ('don-6', 'cmp-4', 'usr-2', 80.00, 'PIX', 'Ninguém merece passar fome. Tamo junto!', '2026-10-22 20:03:59.046428-03'),
    ('don-7', 'cmp-5', 'usr-5', 300.00, 'PIX', 'Solidariedade sempre.', '2026-10-22 20:03:59.046428-03'),
    ('don-8', 'cmp-6', 'usr-2', 150.00, 'PIX', 'O Davi merece ser muito feliz na escola!', '2026-10-22 20:36:59.692625-03'),
    ('don-9', 'cmp-6', 'usr-10', 300.00, 'Cartao de Credito', 'Contem sempre conosco.', '2026-10-22 20:36:59.692625-03'),
    ('don-10', 'cmp-7', 'usr-5', 80.00, 'PIX', 'Melhoras para os gatinhos.', '2026-10-22 20:36:59.692625-03'),
    ('don-11', 'cmp-8', 'usr-2', 200.00, 'PIX', 'Livros abrem portas para o mundo.', '2026-10-22 20:36:59.692625-03'),
    ('don-12', 'cmp-9', 'usr-10', 500.00, 'Boleto', 'Agua e vida. Parabens pelo projeto.', '2026-10-22 20:36:59.692625-03'),
    ('don-13', 'cmp-10', 'usr-5', 100.00, 'PIX', 'A musica transforma criancas em cidadaos.', '2026-10-22 20:36:59.692625-03'),
    ('don-14', 'cmp-11', 'usr-10', 250.00, 'Cartao de Credito', 'Castracao e o unico caminho contra o abandono.', '2026-10-22 20:36:59.692625-03'),
    ('don-15', 'cmp-12', 'usr-2', 400.00, 'PIX', 'Professor Roberto foi meu mestre. Forca guerreiro!', '2026-10-22 20:36:59.692625-03')
ON CONFLICT (id) DO NOTHING;

-- 4.5 Atualizações / Novidades da Campanha (6 registros de prestação de contas)
INSERT INTO public.campaign_updates (id, campaign_id, title, content, image_url, created_at) VALUES
    ('upd-1', 'cmp-1', 'Exames Pré-Operatórios Aprovados!', 'Hoje realizamos todos os exames de sangue e ressonância no Hospital Regional. Os médicos confirmaram que a cirurgia poderá ser agendada para semana que vem!', NULL, '2026-10-22 20:03:59.046428-03'),
    ('upd-2', 'cmp-2', 'Primeira remessa de ração entregue', 'Com os primeiros valores recebidos via PIX, compramos 400kg de ração Special Dog e já começamos a distribuição nas baias. Gratidão eterna!', NULL, '2026-10-22 20:03:59.046428-03'),
    ('upd-3', 'cmp-3', 'Orçamento das impressoras 3D fechado', 'Conseguimos 15% de desconto com o fornecedor local para os dois primeiros equipamentos!', NULL, '2026-10-22 20:03:59.046428-03'),
    ('upd-4', 'cmp-6', 'Medicoes da cadeira realizadas com sucesso', 'A equipe de fisioterapia e ortopedia tirou todas as medidas posturais do Davi para enviar ao fabricante.', NULL, '2026-10-22 20:36:59.692625-03'),
    ('upd-5', 'cmp-7', 'Todos os 15 gatinhos estao fora de risco', 'Gracas as doacoes imediatas compramos o soro e os medicamentos antivirais. Todos estao comendo racao umida sozinhos!', NULL, '2026-10-22 20:36:59.692625-03'),
    ('upd-6', 'cmp-11', 'Primeiro mutirao de castracao agendado', 'No proximo sabado realizaremos as primeiras 50 castracoes com a equipe veterinaria voluntaria.', NULL, '2026-10-22 20:36:59.692625-03')
ON CONFLICT (id) DO NOTHING;

-- 4.6 Mensagens do Mural (8 recados de apoiadores)
INSERT INTO public.wall_messages (id, campaign_id, user_id, author_name, message, created_at) VALUES
    ('msg-1', 'cmp-1', 'usr-2', 'Mariana Santos', 'Theo, Chapecó inteira está torcendo por você!', '2026-10-22 20:03:59.046428-03'),
    ('msg-2', 'cmp-1', 'usr-5', 'Lucas Oliveira', 'Toda oração e apoio para a recuperação rápida.', '2026-10-22 20:03:59.046428-03'),
    ('msg-3', 'cmp-2', 'usr-2', 'Mariana Santos', 'Obrigada pelo amor com os animais resgatados.', '2026-10-22 20:03:59.046428-03'),
    ('msg-4', 'cmp-3', 'usr-5', 'Lucas Oliveira', 'Quando inaugurar quero ir conhecer a sala de robótica!', '2026-10-22 20:03:59.046428-03'),
    ('msg-5', 'cmp-6', 'usr-10', 'Juliana Lima', 'Davi, estamos orando pela sua recuperacao e vitoria!', '2026-10-22 20:36:59.692625-03'),
    ('msg-6', 'cmp-7', 'usr-2', 'Mariana Santos', 'Obrigada por nunca desistirem dos animais mais vulneraveis.', '2026-10-22 20:36:59.692625-03'),
    ('msg-7', 'cmp-8', 'usr-5', 'Lucas Oliveira', 'Tenho caixas de livros infantis para doar tambem!', '2026-10-22 20:36:59.692625-03'),
    ('msg-8', 'cmp-9', 'usr-10', 'Juliana Lima', 'Comunidade unida jamais sera vencida.', '2026-10-22 20:36:59.692625-03')
ON CONFLICT (id) DO NOTHING;

-- 4.7 Denúncias (2 registros para o painel de moderação Admin)
INSERT INTO public.reports (id, campaign_id, reporter_id, reason, status, created_at) VALUES
    ('rep-1', 'cmp-4', 'usr-5', 'Gostaria de ver as fotos das notas fiscais dos eletrodomésticos adquiridos.', 'em_analise', '2026-10-22 20:03:59.046428-03'),
    ('rep-2', 'cmp-5', 'usr-2', 'Campanha duplicada na comunidade de apoio.', 'resolvida', '2026-10-22 20:03:59.046428-03')
ON CONFLICT (id) DO NOTHING;

-- 4.8 Verificações de ONG (2 processos de homologação documental)
INSERT INTO public.ngo_verifications (id, user_id, organization_name, document_number, documents_url, status, notes, created_at) VALUES
    ('vng-1', 'usr-3', 'Associação Protetora Patas do Bem', '12.345.678/0001-90', 'https://patasdobem.org/estatuto_cnpj.pdf', 'aprovado', 'Estatuto registrado em cartório e CNPJ ativo.', '2026-10-22 20:03:59.046428-03'),
    ('vng-2', 'usr-1', 'Instituto Juventude e Futuro', '98.765.432/0001-11', 'https://juventude.org/documentos.zip', 'pendente', 'Aguardando certidão negativa de débitos estaduais.', '2026-10-22 20:03:59.046428-03')
ON CONFLICT (id) DO NOTHING;

-- 4.9 Favoritos (3 vínculos iniciais)
INSERT INTO public.favorites (id, user_id, campaign_id, created_at) VALUES
    ('fav-1', 'usr-1', 'cmp-2', '2026-10-22 20:03:59.046428-03'),
    ('fav-2', 'usr-1', 'cmp-3', '2026-10-22 20:03:59.046428-03'),
    ('fav-3', 'usr-2', 'cmp-1', '2026-10-22 20:03:59.046428-03')
ON CONFLICT (id) DO NOTHING;

-- 4.10 Solicitações de Saque PIX (2 pedidos)
INSERT INTO public.withdrawal_requests (id, campaign_id, creator_id, amount, pix_key, status, created_at) VALUES
    ('wth-1', 'cmp-1', 'usr-1', 5000.00, 'paulo@vakinha.com', 'aprovado', '2026-10-22 20:03:59.046428-03'),
    ('wth-2', 'cmp-2', 'usr-3', 3000.00, '12.345.678/0001-90', 'em_analise', '2026-10-22 20:03:59.046428-03')
ON CONFLICT (id) DO NOTHING;

-- 4.11 Notificações (3 avisos iniciais)
INSERT INTO public.notifications (id, user_id, title, content, is_read, created_at) VALUES
    ('not-1', 'usr-1', 'Nova Doação Recebida!', 'Lucas Oliveira doou R$ 150,00 na campanha do Theo via Cartão de Crédito.', FALSE, '2026-10-22 20:03:59.046428-03'),
    ('not-2', 'usr-1', 'Saque Aprovado!', 'Sua solicitação de saque de R$ 5.000,00 foi autorizada e creditada via PIX.', TRUE, '2026-10-22 20:03:59.046428-03'),
    ('not-3', 'usr-3', 'Selo de ONG Homologado!', 'Parabéns! Sua organização agora tem o selo de verificação oficial da Vakinha.', FALSE, '2026-10-22 20:03:59.046428-03')
ON CONFLICT (id) DO NOTHING;

-- Reabilita todos os triggers transacionais para operação em tempo real
ALTER TABLE public.donations ENABLE TRIGGER trg_validate_donation_before_insert;
ALTER TABLE public.donations ENABLE TRIGGER trg_process_donation_balance_and_notify;
ALTER TABLE public.withdrawal_requests ENABLE TRIGGER trg_withdrawal_before_insert;
ALTER TABLE public.withdrawal_requests ENABLE TRIGGER trg_withdrawal_after_update;
ALTER TABLE public.ngo_verifications ENABLE TRIGGER trg_ngo_verification_after_update;

COMMIT;
