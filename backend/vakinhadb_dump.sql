--
-- PostgreSQL database dump
--

\restrict 5Y2xjsK8ypPXWlsazbqA11wcjvhq6viVuWenkiMN53taUsobe2RBYnNa7hsIGeC

-- Dumped from database version 18.6 (Homebrew)
-- Dumped by pg_dump version 18.6 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: campaign_updates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaign_updates (
    id character varying(64) NOT NULL,
    campaign_id character varying(64) NOT NULL,
    title character varying(255) NOT NULL,
    content text NOT NULL,
    image_url text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaigns (
    id character varying(64) NOT NULL,
    creator_id character varying(64) NOT NULL,
    category_id character varying(64),
    title character varying(255) NOT NULL,
    description text NOT NULL,
    goal_amount numeric(14,2) NOT NULL,
    current_amount numeric(14,2) DEFAULT 0.0,
    status character varying(32) DEFAULT 'ativa'::character varying,
    image_url text,
    latitude numeric(10,6),
    longitude numeric(10,6),
    location_name character varying(150),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id character varying(64) NOT NULL,
    name character varying(120) NOT NULL,
    icon_name character varying(64) NOT NULL
);


--
-- Name: donations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.donations (
    id character varying(64) NOT NULL,
    campaign_id character varying(64) NOT NULL,
    user_id character varying(64),
    amount numeric(14,2) NOT NULL,
    payment_method character varying(64) DEFAULT 'PIX'::character varying,
    message text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: favorites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.favorites (
    id character varying(64) NOT NULL,
    user_id character varying(64) NOT NULL,
    campaign_id character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: ngo_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ngo_verifications (
    id character varying(64) NOT NULL,
    user_id character varying(64) NOT NULL,
    organization_name character varying(180) NOT NULL,
    document_number character varying(64) NOT NULL,
    documents_url text,
    status character varying(32) DEFAULT 'pendente'::character varying,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id character varying(64) NOT NULL,
    user_id character varying(64) NOT NULL,
    title character varying(180) NOT NULL,
    content text NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id character varying(64) NOT NULL,
    campaign_id character varying(64) NOT NULL,
    reporter_id character varying(64),
    reason text NOT NULL,
    status character varying(32) DEFAULT 'em_analise'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id character varying(64) NOT NULL,
    name character varying(120) NOT NULL,
    email character varying(180) NOT NULL,
    password_hash character varying(255) NOT NULL,
    avatar_url text,
    role character varying(32) DEFAULT 'Doador'::character varying,
    latitude numeric(10,6),
    longitude numeric(10,6),
    city character varying(100),
    state character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: wall_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wall_messages (
    id character varying(64) NOT NULL,
    campaign_id character varying(64) NOT NULL,
    user_id character varying(64),
    author_name character varying(120),
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: withdrawal_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.withdrawal_requests (
    id character varying(64) NOT NULL,
    campaign_id character varying(64) NOT NULL,
    creator_id character varying(64) NOT NULL,
    amount numeric(14,2) NOT NULL,
    pix_key character varying(120) NOT NULL,
    status character varying(32) DEFAULT 'em_analise'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Data for Name: campaign_updates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.campaign_updates (id, campaign_id, title, content, image_url, created_at) FROM stdin;
upd-1	cmp-1	Exames Pré-Operatórios Aprovados!	Hoje realizamos todos os exames de sangue e ressonância no Hospital Regional. Os médicos confirmaram que a cirurgia poderá ser agendada para semana que vem!	\N	2026-10-22 20:03:59.046428-03
upd-2	cmp-2	Primeira remessa de ração entregue	Com os primeiros valores recebidos via PIX, compramos 400kg de ração Special Dog e já começamos a distribuição nas baias. Gratidão eterna!	\N	2026-10-22 20:03:59.046428-03
upd-3	cmp-3	Orçamento das impressoras 3D fechado	Conseguimos 15% de desconto com o fornecedor local para os dois primeiros equipamentos!	\N	2026-10-22 20:03:59.046428-03
upd-4	cmp-6	Medicoes da cadeira realizadas com sucesso	A equipe de fisioterapia e ortopedia tirou todas as medidas posturais do Davi para enviar ao fabricante.	\N	2026-10-22 20:36:59.692625-03
upd-5	cmp-7	Todos os 15 gatinhos estao fora de risco	Gracas as doacoes imediatas compramos o soro e os medicamentos antivirais. Todos estao comendo racao umida sozinhos!	\N	2026-10-22 20:36:59.692625-03
upd-6	cmp-11	Primeiro mutirao de castracao agendado	No proximo sabado realizaremos as primeiras 50 castracoes com a equipe veterinaria voluntaria.	\N	2026-10-22 20:36:59.692625-03
\.


--
-- Data for Name: campaigns; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.campaigns (id, creator_id, category_id, title, description, goal_amount, current_amount, status, image_url, latitude, longitude, location_name, created_at) FROM stdin;
cmp-1	usr-1	cat-saude	Cirurgia de Emergência do Theo	O Theo foi diagnosticado com luxação congênita e precisa realizar a cirurgia em até 30 dias para não perder os movimentos. Contamos com sua generosidade e orações!	15000.00	7850.00	ativa	https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=1200&q=80	-27.100400	-52.615200	Hospital Regional - Chapecó/SC	2026-10-22 20:03:59.046428-03
cmp-2	usr-3	cat-animais	Ração e Aquecedores para 120 Cães do Abrigo	Com a frente fria histórica se aproximando, nosso abrigo precisa urgentemente de 1.500 kg de ração, mantas térmicas e medicamentos veterinários.	9500.00	6200.00	ativa	https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=1200&q=80	-27.105000	-52.618000	Abrigo Patas do Bem - Chapecó/SC	2026-10-22 20:03:59.046428-03
cmp-3	usr-1	cat-educacao	Laboratório Maker de Robótica Comunitária	Queremos equipar uma sala com impressora 3D, kits de Arduino e computadores para atender 60 jovens da periferia aos sábados.	22000.00	14300.00	ativa	https://images.unsplash.com/photo-1581092918056-0c4c3acd3789?auto=format&fit=crop&w=1200&q=80	-27.098000	-52.612000	Centro Comunitário Efapi - SC	2026-10-22 20:03:59.046428-03
cmp-4	usr-3	cat-comunidade	Reconstrução da Cozinha Comunitária	Após as fortes enchentes, nossa cozinha que serve 200 refeições diárias perdeu geladeiras, fogões industriais e alimentos.	18000.00	4100.00	ativa	https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?auto=format&fit=crop&w=1200&q=80	-27.112000	-52.620000	Bairro São Pedro - Chapecó/SC	2026-10-22 20:03:59.046428-03
cmp-5	usr-1	cat-emergencia	Fundo de Apoio a Famílias Desabrigadas pelas Chuvas	Mobilização rápida para compra de cestas básicas, colchões e kits de higiene para famílias atingidas pelo temporal na região.	12000.00	8900.00	ativa	https://images.unsplash.com/photo-1532629345422-7515f3d16bb9?auto=format&fit=crop&w=1200&q=80	-27.102000	-52.614000	Chapecó e Região Oeste/SC	2026-10-22 20:03:59.046428-03
cmp-6	usr-6	cat-saude	Cadeira de Rodas Motorizada para o Davi	O Davi tem 9 anos e nasceu com paralisia cerebral severa. Uma cadeira motorizada permitira que ele frequente a escola regular com autonomia e dignidade.	18500.00	11200.00	ativa	https://images.unsplash.com/photo-1576765608535-5f04d1e3f289?auto=format&fit=crop&w=1200&q=80	-27.095000	-52.620000	Centro de Reabilitacao - Chapeco/SC	2026-10-22 20:36:59.692625-03
cmp-7	usr-7	cat-animais	Tratamento de 15 Gatinhos Resgatados de Acumulacao	Resgatamos 15 filhotes em situacao de maus-tratos extremos. Precisamos de soro, antibacterianos, vacinas polivalentes e racao umida medicamentosa.	6200.00	4850.00	ativa	https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=1200&q=80	-27.102000	-52.610000	Clinica Veterinaria Popular - Chapeco/SC	2026-10-22 20:36:59.692625-03
cmp-8	usr-8	cat-educacao	Reforma da Biblioteca Comunitaria Bairro Efapi	Queremos trocar o telhado que possui vazamentos e comprar 350 livros infanto-juvenis para incentivar a leitura das criancas da comunidade.	14000.00	9300.00	ativa	https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?auto=format&fit=crop&w=1200&q=80	-27.108000	-52.605000	Bairro Efapi - Chapeco/SC	2026-10-22 20:36:59.692625-03
cmp-9	usr-9	cat-comunidade	Poco Artesiano para Comunidade Rural	Mais de 30 familias do interior sofrem com a estiagem historica. A perfuracao do poco garantira agua potavel nas residencias e hortas familiares.	32000.00	21400.00	ativa	https://images.unsplash.com/photo-1541888946425-d0fbb186c5f7?auto=format&fit=crop&w=1200&q=80	-27.115000	-52.625000	Linha Tomazelli - Interior Chapeco/SC	2026-10-22 20:36:59.692625-03
cmp-10	usr-7	cat-cultura	Instrumentos Musicais para Orquestra Jovem	Inclusao social atraves da musica classica. Precisamos comprar violinos, violoncelos e flautas para 45 criancas da rede publica.	26000.00	15800.00	ativa	https://images.unsplash.com/photo-1511192336575-5a79af67a629?auto=format&fit=crop&w=1200&q=80	-27.100400	-52.615200	Teatro Municipal - Chapeco/SC	2026-10-22 20:36:59.692625-03
cmp-11	usr-3	cat-animais	Castracao Solidaria para 200 Animais de Rua	O controle populacional etico previne o abandono e doencas. A campanha cobrira os custos cirurgicos de veterinarios parceiros para caes e gatos errantes.	16000.00	12900.00	ativa	https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?auto=format&fit=crop&w=1200&q=80	-27.105000	-52.618000	Centro de Castracao Municipal - Chapeco/SC	2026-10-22 20:36:59.692625-03
cmp-12	usr-1	cat-saude	Protese Transtibial para o Professor Roberto	Apos complicacoes do diabetes o professor Roberto precisou amputar a perna. Uma protese de carbono moderna permitira que ele volte a lecionar em pe.	28000.00	19600.00	ativa	https://images.unsplash.com/photo-1584432810601-6c7f27d2362b?auto=format&fit=crop&w=1200&q=80	-27.098000	-52.612000	Clinica Ortopedica Chapeco/SC	2026-10-22 20:36:59.692625-03
cmp-13	usr-8	cat-comunidade	Paineis Solares para Casa Lar de Idosos	A conta de energia consome 40 por cento do orcamento da instituicao. A instalacao solar gerara economia imediata que sera revertida em medicamentos e fisioterapia.	38000.00	24500.00	ativa	https://images.unsplash.com/photo-1509391365360-2e959784a276?auto=format&fit=crop&w=1200&q=80	-27.103000	-52.617000	Lar dos Velhinhos - Chapeco/SC	2026-10-22 20:36:59.692625-03
cmp-note	usr-bruno	cat-educacao	Notebook para estudar	Preciso de um notebook para acompanhar as aulas da faculdade de computacao e fazer meus projetos de programacao.	3500.00	900.00	ativa	https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=1200&q=80	\N	\N	Porto Alegre - RS	2026-10-22 20:48:59.794983-03
cmp-animais-resgate	usr-carla	cat-animais	Ajuda para resgate de animais	Fundo de apoio para socorrer e medicar animais abandonados em situacao de vulnerabilidade.	4200.00	1600.00	ativa	https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=1200&q=80	\N	\N	Chapeco - SC	2026-10-22 20:48:59.794983-03
cmp-medicamentos	usr-felipe	cat-saude	Medicamentos para tratamento continuo	Tratamento de doenca autoimune rara. O SUS nao fornece a medicacao importada de uso diario.	8500.00	4800.00	ativa	https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=1200&q=80	\N	\N	Florianopolis - SC	2026-10-22 20:48:59.794983-03
cmp-horta	usr-amanda	cat-comunidade	Horta comunitaria do bairro	Criacao de horta agroecologica para distribuir alimentos frescos e saudaveis para familias carentes.	5000.00	3100.00	ativa	https://images.unsplash.com/photo-1592417817098-8f3d6eb22509?auto=format&fit=crop&w=1200&q=80	\N	\N	Curitiba - PR	2026-10-22 20:48:59.794983-03
cmp-bazar	usr-bruno	cat-cultura	Espaco cultural e oficina de arte	Reforma do salao comunitario para oficinas semanais gratuitas de pintura e escultura para criancas.	6000.00	2200.00	ativa	https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=1200&q=80	\N	\N	Porto Alegre - RS	2026-10-22 20:48:59.794983-03
cmp-agasalho	usr-carla	cat-emergencia	Campanha do agasalho e cobertores	Arrecadacao urgente para compra de 200 cobertores e agasalhos pesados para moradores em situacao de rua.	4500.00	3900.00	ativa	https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?auto=format&fit=crop&w=1200&q=80	\N	\N	Chapeco - SC	2026-10-22 20:48:59.794983-03
\.


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.categories (id, name, icon_name) FROM stdin;
cat-saude	Saúde & Tratamentos	cross.case.fill
cat-animais	Causas Animais	pawprint.fill
cat-educacao	Educação & Projetos	book.fill
cat-comunidade	Ajuda Comunitária	person.3.fill
cat-emergencia	Emergências Naturais	flame.fill
cat-cultura	Cultura & Arte	paintpalette.fill
\.


--
-- Data for Name: donations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.donations (id, campaign_id, user_id, amount, payment_method, message, created_at) FROM stdin;
don-1	cmp-1	usr-2	200.00	PIX	Força amigão, já deu tudo certo na cirurgia!	2026-10-22 20:03:59.046428-03
don-2	cmp-1	usr-5	150.00	Cartão de Crédito	Deus abençoe a família e a equipe médica.	2026-10-22 20:03:59.046428-03
don-3	cmp-2	usr-2	100.00	PIX	Pelos nossos anjinhos de quatro patas!	2026-10-22 20:03:59.046428-03
don-4	cmp-2	usr-1	250.00	PIX	Trabalho lindo que vocês fazem no abrigo.	2026-10-22 20:03:59.046428-03
don-5	cmp-3	usr-5	500.00	Boleto	Educação transforma tudo! Sucesso no projeto maker.	2026-10-22 20:03:59.046428-03
don-6	cmp-4	usr-2	80.00	PIX	Ninguém merece passar fome. Tamo junto!	2026-10-22 20:03:59.046428-03
don-7	cmp-5	usr-5	300.00	PIX	Solidariedade sempre.	2026-10-22 20:03:59.046428-03
don-8	cmp-6	usr-2	150.00	PIX	O Davi merece ser muito feliz na escola!	2026-10-22 20:36:59.692625-03
don-9	cmp-6	usr-10	300.00	Cartao de Credito	Contem sempre conosco.	2026-10-22 20:36:59.692625-03
don-10	cmp-7	usr-5	80.00	PIX	Melhoras para os gatinhos.	2026-10-22 20:36:59.692625-03
don-11	cmp-8	usr-2	200.00	PIX	Livros abrem portas para o mundo.	2026-10-22 20:36:59.692625-03
don-12	cmp-9	usr-10	500.00	Boleto	Agua e vida. Parabens pelo projeto.	2026-10-22 20:36:59.692625-03
don-13	cmp-10	usr-5	100.00	PIX	A musica transforma criancas em cidadaos.	2026-10-22 20:36:59.692625-03
don-14	cmp-11	usr-10	250.00	Cartao de Credito	Castracao e o unico caminho contra o abandono.	2026-10-22 20:36:59.692625-03
don-15	cmp-12	usr-2	400.00	PIX	Professor Roberto foi meu mestre. Forca guerreiro!	2026-10-22 20:36:59.692625-03
\.


--
-- Data for Name: favorites; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.favorites (id, user_id, campaign_id, created_at) FROM stdin;
fav-1	usr-1	cmp-2	2026-10-22 20:03:59.046428-03
fav-2	usr-1	cmp-3	2026-10-22 20:03:59.046428-03
fav-3	usr-2	cmp-1	2026-10-22 20:03:59.046428-03
\.


--
-- Data for Name: ngo_verifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ngo_verifications (id, user_id, organization_name, document_number, documents_url, status, notes, created_at) FROM stdin;
vng-1	usr-3	Associação Protetora Patas do Bem	12.345.678/0001-90	https://patasdobem.org/estatuto_cnpj.pdf	aprovado	Estatuto registrado em cartório e CNPJ ativo.	2026-10-22 20:03:59.046428-03
vng-2	usr-1	Instituto Juventude e Futuro	98.765.432/0001-11	https://juventude.org/documentos.zip	pendente	Aguardando certidão negativa de débitos estaduais.	2026-10-22 20:03:59.046428-03
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notifications (id, user_id, title, content, is_read, created_at) FROM stdin;
not-1	usr-1	Nova Doação Recebida!	Lucas Oliveira doou R$ 150,00 na campanha do Theo via Cartão de Crédito.	f	2026-10-22 20:03:59.046428-03
not-2	usr-1	Saque Aprovado!	Sua solicitação de saque de R$ 5.000,00 foi autorizada e creditada via PIX.	t	2026-10-22 20:03:59.046428-03
not-3	usr-3	Selo de ONG Homologado!	Parabéns! Sua organização agora tem o selo de verificação oficial da Vakinha.	f	2026-10-22 20:03:59.046428-03
\.


--
-- Data for Name: reports; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.reports (id, campaign_id, reporter_id, reason, status, created_at) FROM stdin;
rep-1	cmp-4	usr-5	Gostaria de ver as fotos das notas fiscais dos eletrodomésticos adquiridos.	em_analise	2026-10-22 20:03:59.046428-03
rep-2	cmp-5	usr-2	Campanha duplicada na comunidade de apoio.	resolvida	2026-10-22 20:03:59.046428-03
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, name, email, password_hash, avatar_url, role, latitude, longitude, city, state, created_at) FROM stdin;
usr-1	Paulo Garbo	paulo@vakinha.com	e10adc3949ba59abbe56e057f20f883e	\N	Criador	-27.100400	-52.615200	Chapecó	SC	2026-10-22 20:03:59.046428-03
usr-2	Mariana Santos	mariana@vakinha.com	e10adc3949ba59abbe56e057f20f883e	\N	Doador	-27.098000	-52.612000	Chapecó	SC	2026-10-22 20:03:59.046428-03
usr-3	ONG Patas do Bem	ong@patasdobem.org	e10adc3949ba59abbe56e057f20f883e	\N	ONG	-27.105000	-52.618000	Chapecó	SC	2026-10-22 20:03:59.046428-03
usr-4	Admin Vakinha	admin@vakinha.com	e10adc3949ba59abbe56e057f20f883e	\N	Admin	-27.100000	-52.615000	Chapecó	SC	2026-10-22 20:03:59.046428-03
usr-5	Lucas Oliveira	lucas@vakinha.com	e10adc3949ba59abbe56e057f20f883e	\N	Doador	-27.112000	-52.620000	Chapecó	SC	2026-10-22 20:03:59.046428-03
usr-6	Instituto Reabilitar	contato@reabilitar.org	e10adc3949ba59abbe56e057f20f883e	\N	ONG	-27.095000	-52.620000	Chapeco	SC	2026-10-22 20:36:59.692625-03
usr-7	Camila Rodrigues	camila.rodrigues@email.com	e10adc3949ba59abbe56e057f20f883e	\N	Criador	-27.102000	-52.610000	Chapeco	SC	2026-10-22 20:36:59.692625-03
usr-8	Projeto Sementes do Futuro	sementes@futuro.org	e10adc3949ba59abbe56e057f20f883e	\N	ONG	-27.108000	-52.605000	Chapeco	SC	2026-10-22 20:36:59.692625-03
usr-9	Rodrigo Mendes	rodrigo.mendes@email.com	e10adc3949ba59abbe56e057f20f883e	\N	Criador	-27.115000	-52.625000	Chapeco	SC	2026-10-22 20:36:59.692625-03
usr-10	Juliana Lima	juliana.lima@email.com	e10adc3949ba59abbe56e057f20f883e	\N	Doador	-27.100000	-52.615000	Chapeco	SC	2026-10-22 20:36:59.692625-03
usr-bruno	Bruno Lima	bruno@email.com	e10adc3949ba59abbe56e057f20f883e	\N	Criador	\N	\N	Porto Alegre	RS	2026-10-22 20:48:59.794983-03
usr-carla	Carla Souza	carla@email.com	e10adc3949ba59abbe56e057f20f883e	\N	Criador	\N	\N	Chapeco	SC	2026-10-22 20:48:59.794983-03
usr-felipe	Felipe Santos	felipe@email.com	e10adc3949ba59abbe56e057f20f883e	\N	Criador	\N	\N	Florianopolis	SC	2026-10-22 20:48:59.794983-03
usr-amanda	Amanda Ribeiro	amanda@email.com	e10adc3949ba59abbe56e057f20f883e	\N	Criador	\N	\N	Curitiba	PR	2026-10-22 20:48:59.794983-03
\.


--
-- Data for Name: wall_messages; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.wall_messages (id, campaign_id, user_id, author_name, message, created_at) FROM stdin;
msg-1	cmp-1	usr-2	Mariana Santos	Theo, Chapecó inteira está torcendo por você!	2026-10-22 20:03:59.046428-03
msg-2	cmp-1	usr-5	Lucas Oliveira	Toda oração e apoio para a recuperação rápida.	2026-10-22 20:03:59.046428-03
msg-3	cmp-2	usr-2	Mariana Santos	Obrigada pelo amor com os animais resgatados.	2026-10-22 20:03:59.046428-03
msg-4	cmp-3	usr-5	Lucas Oliveira	Quando inaugurar quero ir conhecer a sala de robótica!	2026-10-22 20:03:59.046428-03
msg-5	cmp-6	usr-10	Juliana Lima	Davi, estamos orando pela sua recuperacao e vitoria!	2026-10-22 20:36:59.692625-03
msg-6	cmp-7	usr-2	Mariana Santos	Obrigada por nunca desistirem dos animais mais vulneraveis.	2026-10-22 20:36:59.692625-03
msg-7	cmp-8	usr-5	Lucas Oliveira	Tenho caixas de livros infantis para doar tambem!	2026-10-22 20:36:59.692625-03
msg-8	cmp-9	usr-10	Juliana Lima	Comunidade unida jamais sera vencida.	2026-10-22 20:36:59.692625-03
\.


--
-- Data for Name: withdrawal_requests; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.withdrawal_requests (id, campaign_id, creator_id, amount, pix_key, status, created_at) FROM stdin;
wth-1	cmp-1	usr-1	5000.00	paulo@vakinha.com	aprovado	2026-10-22 20:03:59.046428-03
wth-2	cmp-2	usr-3	3000.00	12.345.678/0001-90	em_analise	2026-10-22 20:03:59.046428-03
\.


--
-- Name: campaign_updates campaign_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_updates
    ADD CONSTRAINT campaign_updates_pkey PRIMARY KEY (id);


--
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: donations donations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_pkey PRIMARY KEY (id);


--
-- Name: favorites favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: favorites favorites_user_id_campaign_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_user_id_campaign_id_key UNIQUE (user_id, campaign_id);


--
-- Name: ngo_verifications ngo_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ngo_verifications
    ADD CONSTRAINT ngo_verifications_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wall_messages wall_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wall_messages
    ADD CONSTRAINT wall_messages_pkey PRIMARY KEY (id);


--
-- Name: withdrawal_requests withdrawal_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.withdrawal_requests
    ADD CONSTRAINT withdrawal_requests_pkey PRIMARY KEY (id);


--
-- Name: campaign_updates campaign_updates_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign_updates
    ADD CONSTRAINT campaign_updates_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: campaigns campaigns_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: campaigns campaigns_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: donations donations_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: donations donations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: favorites favorites_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: favorites favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ngo_verifications ngo_verifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ngo_verifications
    ADD CONSTRAINT ngo_verifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reports reports_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: reports reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: wall_messages wall_messages_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wall_messages
    ADD CONSTRAINT wall_messages_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: wall_messages wall_messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wall_messages
    ADD CONSTRAINT wall_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: withdrawal_requests withdrawal_requests_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.withdrawal_requests
    ADD CONSTRAINT withdrawal_requests_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaigns(id) ON DELETE CASCADE;


--
-- Name: withdrawal_requests withdrawal_requests_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.withdrawal_requests
    ADD CONSTRAINT withdrawal_requests_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 5Y2xjsK8ypPXWlsazbqA11wcjvhq6viVuWenkiMN53taUsobe2RBYnNa7hsIGeC

