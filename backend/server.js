const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const { pool, initDB } = require('./db');

const app = express();
const port = parseInt(process.env.PORT || '3000', 10);
const JWT_SECRET = process.env.JWT_SECRET || 'nexo-vakinha-super-secret-jwt-key-2026-production';
const JWT_EXPIRES_IN_SECONDS = 60 * 60 * 24 * 7; // 7 dias

// Diretório estático para imagens enviadas (substituindo payloads base64 pesados no banco)
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

app.use(cors());
app.use(express.json({ limit: '15mb' }));
app.use('/uploads', express.static(uploadsDir));

// ============================================================================
// UTILITÁRIOS DE CRIPTOGRAFIA (scrypt com salt + JWT HS256 Nativo)
// ============================================================================

function genId(prefix) {
  return `${prefix}-${Date.now().toString(36)}-${crypto.randomBytes(3).toString('hex')}`;
}

// Hash de senha seguro usando scrypt + salt aleatório de 16 bytes + timingSafeEqual
function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return `scrypt$${salt}$${hash}`;
}

function md5Legacy(password) {
  return crypto.createHash('md5').update(password).digest('hex');
}

function verifyPassword(password, stored) {
  if (!stored || typeof password !== 'string') return false;
  if (stored.startsWith('scrypt$')) {
    const parts = stored.split('$');
    if (parts.length !== 3) return false;
    const [, salt, hash] = parts;
    const expected = Buffer.from(hash, 'hex');
    const actual = crypto.scryptSync(password, salt, expected.length);
    if (expected.length !== actual.length) return false;
    return crypto.timingSafeEqual(expected, actual);
  }
  return stored === md5Legacy(password);
}

// Implementação RFC 7519 de JWT (HMAC-SHA256) sem dependências vulneráveis externas
function base64UrlEncode(input) {
  const buf = Buffer.isBuffer(input) ? input : Buffer.from(String(input), 'utf8');
  return buf.toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function base64UrlDecodeToString(input) {
  let base64 = input.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4 !== 0) {
    base64 += '=';
  }
  return Buffer.from(base64, 'base64').toString('utf8');
}

function signJWT(user) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = {
    sub: user.id,
    email: user.email,
    name: user.name,
    role: user.role || 'Doador',
    iat: now,
    exp: now + JWT_EXPIRES_IN_SECONDS,
  };
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signature = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(signingInput)
    .digest();
  const encodedSignature = base64UrlEncode(signature);
  return `${signingInput}.${encodedSignature}`;
}

function verifyJWT(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const expectedSig = base64UrlEncode(
    crypto.createHmac('sha256', JWT_SECRET).update(signingInput).digest()
  );
  const sigBuf = Buffer.from(encodedSignature);
  const expBuf = Buffer.from(expectedSig);
  if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) {
    return null;
  }
  try {
    const payload = JSON.parse(base64UrlDecodeToString(encodedPayload));
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

// ============================================================================
// MIDDLEWARES DE AUTENTICAÇÃO E CONTROLE DE ACESSO (RBAC)
// ============================================================================

function extractToken(req) {
  const authHeader = req.headers.authorization || req.headers.Authorization;
  if (authHeader && typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
    return authHeader.slice(7).trim();
  }
  return null;
}

function authenticateJWT(req, res, next) {
  const token = extractToken(req);
  if (!token) {
    return res.status(401).json({ error: 'Acesso negado. Token JWT ausente no cabeçalho Authorization.' });
  }
  const decoded = verifyJWT(token);
  if (!decoded) {
    return res.status(401).json({ error: 'Sessão inválida ou expirada. Faça login novamente.' });
  }
  req.user = decoded;
  next();
}

function requireRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Usuário não autenticado.' });
    }
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        error: `Permissão insuficiente. Seu perfil (${req.user.role}) não possui acesso a este recurso. Perfis aceitos: ${allowedRoles.join(', ')}.`,
      });
    }
    next();
  };
}

// Converte eventual imagem enviada pela câmera (data URL ou base64) em arquivo estático e retorna URL HTTP limpa
function persistImageIfNeeded(rawImageInput, req) {
  if (!rawImageInput || typeof rawImageInput !== 'string') return null;
  const trimmed = rawImageInput.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  try {
    let base64Data = trimmed;
    let ext = 'jpg';
    if (trimmed.startsWith('data:image/')) {
      const match = trimmed.match(/^data:image\/([a-zA-Z0-9+]+);base64,(.+)$/);
      if (match) {
        ext = match[1] === 'png' ? 'png' : 'jpg';
        base64Data = match[2];
      }
    }
    const buffer = Buffer.from(base64Data, 'base64');
    if (buffer.length < 32) return null;
    const filename = `img-${Date.now()}-${crypto.randomBytes(4).toString('hex')}.${ext}`;
    const filePath = path.join(uploadsDir, filename);
    fs.writeFileSync(filePath, buffer);
    const protocol = req.protocol || 'http';
    const host = req.get('host') || `localhost:${port}`;
    return `${protocol}://${host}/uploads/${filename}`;
  } catch {
    return null;
  }
}

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// ============================================================================
// HEALTH CHECK & UPLOAD DE MÍDIA
// ============================================================================

app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({
      status: 'ok',
      service: 'NEXO Vakinha API',
      database: 'conectado',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    res.status(503).json({ status: 'erro', database: 'desconectado', error: err.message });
  }
});

app.post('/api/uploads', authenticateJWT, async (req, res) => {
  try {
    const { image_data } = req.body;
    const url = persistImageIfNeeded(image_data, req);
    if (!url) {
      return res.status(400).json({ error: 'Formato de imagem inválido.' });
    }
    res.status(201).json({ url });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 0. AUTENTICAÇÃO, SESSÃO JWT E PERFIL SEGURO
// ============================================================================

app.post('/api/auth/register', async (req, res) => {
  try {
    const { name, email, password, role, latitude, longitude, city, state } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Nome, email e senha são obrigatórios.' });
    }
    const normalizedEmail = String(email).trim().toLowerCase();
    if (!EMAIL_REGEX.test(normalizedEmail)) {
      return res.status(400).json({ error: 'Informe um endereço de email válido.' });
    }
    if (String(password).length < 6) {
      return res.status(400).json({ error: 'A senha deve ter no mínimo 6 caracteres.' });
    }

    const check = await pool.query('SELECT id FROM users WHERE LOWER(email) = $1', [normalizedEmail]);
    if (check.rows.length > 0) {
      return res.status(409).json({ error: 'Este email já está cadastrado na plataforma.' });
    }

    const validRoles = ['Doador', 'Criador', 'ONG', 'Admin'];
    const finalRole = validRoles.includes(role) ? role : 'Doador';
    const id = genId('usr');
    const pwdHash = hashPassword(password);

    const result = await pool.query(
      `INSERT INTO users (id, name, email, password_hash, role, latitude, longitude, city, state)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, name, email, role, avatar_url, latitude, longitude, city, state, created_at`,
      [
        id,
        name.trim(),
        normalizedEmail,
        pwdHash,
        finalRole,
        latitude ?? null,
        longitude ?? null,
        city || null,
        state || null,
      ]
    );

    const user = result.rows[0];
    const token = signJWT(user);
    res.status(201).json({ user, token });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email e senha são obrigatórios.' });
    }
    const normalizedEmail = String(email).trim().toLowerCase();
    const result = await pool.query(
      `SELECT id, name, email, role, avatar_url, latitude, longitude, city, state, created_at, password_hash
       FROM users WHERE LOWER(email) = $1`,
      [normalizedEmail]
    );
    const row = result.rows[0];
    if (!row || !verifyPassword(password, row.password_hash)) {
      return res.status(401).json({ error: 'Credenciais inválidas. Verifique seu email e senha.' });
    }

    // Upgrade transparente de hashes MD5 legados do seed para scrypt no primeiro login
    if (!row.password_hash.startsWith('scrypt$')) {
      await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [
        hashPassword(password),
        row.id,
      ]);
    }

    const { password_hash, ...user } = row;
    const token = signJWT(user);
    res.json({ user, token });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Troca rápida de perfil para avaliação/demonstração emitindo JWT legítimo para o usuário selecionado
app.post('/api/auth/switch-user', async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ error: 'userId é obrigatório.' });
    }
    const result = await pool.query(
      `SELECT id, name, email, role, avatar_url, latitude, longitude, city, state, created_at
       FROM users WHERE id = $1`,
      [userId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }
    const user = result.rows[0];
    const token = signJWT(user);
    res.json({ user, token });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/auth/me', authenticateJWT, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, email, role, avatar_url, latitude, longitude, city, state, created_at
       FROM users WHERE id = $1`,
      [req.user.sub]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/auth/profile/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    if (req.user.sub !== id && req.user.role !== 'Admin') {
      return res.status(403).json({ error: 'Você só pode editar o seu próprio perfil.' });
    }
    const { name, avatar_url, latitude, longitude, city, state } = req.body;
    const cleanAvatarUrl = avatar_url ? persistImageIfNeeded(avatar_url, req) : null;
    const result = await pool.query(
      `UPDATE users
       SET name = COALESCE($1, name),
           avatar_url = COALESCE($2, avatar_url),
           latitude = COALESCE($3, latitude),
           longitude = COALESCE($4, longitude),
           city = COALESCE($5, city),
           state = COALESCE($6, state)
       WHERE id = $7
       RETURNING id, name, email, role, avatar_url, latitude, longitude, city, state, created_at`,
      [name, cleanAvatarUrl, latitude, longitude, city, state, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 1. CAMPANHAS (Campaigns) - CRUD
// ============================================================================

app.get('/api/campaigns', async (req, res) => {
  try {
    const { category, search, creatorId } = req.query;
    let query = `
      SELECT c.*, cat.name AS category_name, cat.icon_name AS category_icon, u.name AS creator_name,
        (SELECT COUNT(*) FROM donations d WHERE d.campaign_id = c.id) AS donations_count
      FROM campaigns c
      LEFT JOIN categories cat ON c.category_id = cat.id
      LEFT JOIN users u ON c.creator_id = u.id
      WHERE 1=1
    `;
    const params = [];
    if (category) {
      params.push(category);
      query += ` AND c.category_id = $${params.length}`;
    }
    if (creatorId) {
      params.push(creatorId);
      query += ` AND c.creator_id = $${params.length}`;
    }
    if (search) {
      params.push(`%${search}%`);
      query += ` AND (c.title ILIKE $${params.length} OR c.description ILIKE $${params.length} OR c.location_name ILIKE $${params.length})`;
    }
    query += ` ORDER BY c.created_at DESC`;
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/campaigns/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `SELECT c.*, cat.name AS category_name, cat.icon_name AS category_icon, u.name AS creator_name,
        (SELECT COUNT(*) FROM donations d WHERE d.campaign_id = c.id) AS donations_count
       FROM campaigns c
       LEFT JOIN categories cat ON c.category_id = cat.id
       LEFT JOIN users u ON c.creator_id = u.id
       WHERE c.id = $1`,
      [id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Campanha não encontrada.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/campaigns', authenticateJWT, async (req, res) => {
  try {
    const { title, description, goal_amount, category_id, image_url, latitude, longitude, location_name } = req.body;
    const numericGoal = parseFloat(goal_amount);
    if (!title || !description || !Number.isFinite(numericGoal) || numericGoal <= 0) {
      return res.status(400).json({ error: 'Título, descrição e meta maior que zero são obrigatórios.' });
    }
    const id = genId('cmp');
    const creatorId = req.user.sub;
    const resolvedImageUrl = persistImageIfNeeded(image_url, req);

    const result = await pool.query(
      `INSERT INTO campaigns (id, title, description, goal_amount, current_amount, category_id, creator_id, status, image_url, latitude, longitude, location_name)
       VALUES ($1, $2, $3, $4, 0.0, $5, $6, 'ativa', $7, $8, $9, $10)
       RETURNING *`,
      [
        id,
        title.trim(),
        description.trim(),
        numericGoal,
        category_id || null,
        creatorId,
        resolvedImageUrl,
        latitude ?? null,
        longitude ?? null,
        location_name || null,
      ]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/campaigns/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    const ownerCheck = await pool.query('SELECT creator_id FROM campaigns WHERE id = $1', [id]);
    if (ownerCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Campanha não encontrada.' });
    }
    if (ownerCheck.rows[0].creator_id !== req.user.sub && req.user.role !== 'Admin') {
      return res.status(403).json({ error: 'Apenas o criador da campanha ou um Admin pode editá-la.' });
    }

    const { title, description, goal_amount, category_id, status, image_url, location_name } = req.body;
    const resolvedImageUrl = image_url ? persistImageIfNeeded(image_url, req) : null;

    const result = await pool.query(
      `UPDATE campaigns
       SET title = COALESCE($1, title),
           description = COALESCE($2, description),
           goal_amount = COALESCE($3, goal_amount),
           category_id = COALESCE($4, category_id),
           status = COALESCE($5, status),
           image_url = COALESCE($6, image_url),
           location_name = COALESCE($7, location_name)
       WHERE id = $8
       RETURNING *`,
      [
        title,
        description,
        goal_amount ? parseFloat(goal_amount) : null,
        category_id,
        status,
        resolvedImageUrl,
        location_name,
        id,
      ]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/campaigns/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    const ownerCheck = await pool.query('SELECT creator_id FROM campaigns WHERE id = $1', [id]);
    if (ownerCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Campanha não encontrada.' });
    }
    if (ownerCheck.rows[0].creator_id !== req.user.sub && req.user.role !== 'Admin') {
      return res.status(403).json({ error: 'Apenas o criador da campanha ou um Admin pode excluí-la.' });
    }
    await pool.query('DELETE FROM campaigns WHERE id = $1', [id]);
    res.json({ success: true, message: 'Campanha removida com sucesso.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 2. DOAÇÕES (Donations) - CRUD (Saldo atualizado pela Trigger PL/pgSQL)
// ============================================================================

app.get('/api/donations', async (req, res) => {
  try {
    const { campaignId, userId } = req.query;
    let query = `
      SELECT d.*, u.name AS user_name, c.title AS campaign_title
      FROM donations d
      LEFT JOIN users u ON d.user_id = u.id
      LEFT JOIN campaigns c ON d.campaign_id = c.id
      WHERE 1=1
    `;
    const params = [];
    if (campaignId) {
      params.push(campaignId);
      query += ` AND d.campaign_id = $${params.length}`;
    }
    if (userId) {
      params.push(userId);
      query += ` AND d.user_id = $${params.length}`;
    }
    query += ` ORDER BY d.created_at DESC`;
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/donations', authenticateJWT, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { campaign_id, amount, payment_method, message } = req.body;
    const numAmount = parseFloat(amount);
    if (!campaign_id || !Number.isFinite(numAmount) || numAmount <= 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Informe uma campanha válida e um valor de doação maior que zero.' });
    }

    const id = genId('don');
    const donorId = req.user.sub;

    // A trigger PL/pgSQL (trg_validate_donation_before_insert e trg_process_donation_balance_and_notify)
    // valida o status da campanha, soma o current_amount atomicamente e cria a notificação ao criador!
    const donResult = await client.query(
      `INSERT INTO donations (id, campaign_id, user_id, amount, payment_method, message)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [id, campaign_id, donorId, numAmount, payment_method || 'PIX', message || null]
    );

    await client.query('COMMIT');
    res.status(201).json(donResult.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(400).json({ error: err.message });
  } finally {
    client.release();
  }
});

// ============================================================================
// 3. ATUALIZAÇÕES DA CAMPANHA (Novidades / Prestação de Contas) - CRUD
// ============================================================================

app.get('/api/updates', async (req, res) => {
  try {
    const { campaignId } = req.query;
    const result = await pool.query(
      'SELECT * FROM campaign_updates WHERE campaign_id = $1 ORDER BY created_at DESC',
      [campaignId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/updates', authenticateJWT, async (req, res) => {
  try {
    const { campaign_id, title, content, image_url } = req.body;
    if (!campaign_id || !title || !content) {
      return res.status(400).json({ error: 'Campanha, título e conteúdo são obrigatórios.' });
    }
    const cmpCheck = await pool.query('SELECT creator_id FROM campaigns WHERE id = $1', [campaign_id]);
    if (cmpCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Campanha não encontrada.' });
    }
    if (cmpCheck.rows[0].creator_id !== req.user.sub && req.user.role !== 'Admin') {
      return res.status(403).json({ error: 'Apenas o criador da campanha pode publicar novidades.' });
    }

    const id = genId('upd');
    const resolvedImageUrl = persistImageIfNeeded(image_url, req);
    const result = await pool.query(
      `INSERT INTO campaign_updates (id, campaign_id, title, content, image_url)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [id, campaign_id, title.trim(), content.trim(), resolvedImageUrl]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/updates/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    const { title, content, image_url } = req.body;
    const resolvedImageUrl = image_url ? persistImageIfNeeded(image_url, req) : null;
    const result = await pool.query(
      `UPDATE campaign_updates
       SET title = COALESCE($1, title),
           content = COALESCE($2, content),
           image_url = COALESCE($3, image_url)
       WHERE id = $4
       RETURNING *`,
      [title, content, resolvedImageUrl, id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/updates/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM campaign_updates WHERE id = $1', [id]);
    res.json({ success: true, message: 'Atualização excluída.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 4. MENSAGENS DO MURAL (Wall Messages) - CRUD
// ============================================================================

app.get('/api/messages', async (req, res) => {
  try {
    const { campaignId } = req.query;
    const result = await pool.query(
      'SELECT * FROM wall_messages WHERE campaign_id = $1 ORDER BY created_at DESC',
      [campaignId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/messages', authenticateJWT, async (req, res) => {
  try {
    const { campaign_id, message } = req.body;
    if (!campaign_id || !message || !String(message).trim()) {
      return res.status(400).json({ error: 'Mensagem não pode ser vazia.' });
    }
    const id = genId('msg');
    const result = await pool.query(
      `INSERT INTO wall_messages (id, campaign_id, user_id, author_name, message)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [id, campaign_id, req.user.sub, req.user.name || 'Apoiador', message.trim()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/messages/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    const check = await pool.query('SELECT user_id FROM wall_messages WHERE id = $1', [id]);
    if (check.rows.length === 0) {
      return res.status(404).json({ error: 'Mensagem não encontrada.' });
    }
    if (check.rows[0].user_id !== req.user.sub && req.user.role !== 'Admin') {
      return res.status(403).json({ error: 'Você só pode apagar suas próprias mensagens.' });
    }
    await pool.query('DELETE FROM wall_messages WHERE id = $1', [id]);
    res.json({ success: true, message: 'Mensagem removida.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 5. DENÚNCIAS E MODERAÇÃO (Reports) - CRUD
// ============================================================================

app.get('/api/reports', authenticateJWT, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT r.*, c.title AS campaign_title, u.name AS reporter_name
      FROM reports r
      LEFT JOIN campaigns c ON r.campaign_id = c.id
      LEFT JOIN users u ON r.reporter_id = u.id
      ORDER BY r.created_at DESC
    `);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/reports', authenticateJWT, async (req, res) => {
  try {
    const { campaign_id, reason } = req.body;
    if (!campaign_id || !reason) {
      return res.status(400).json({ error: 'Campanha e motivo da denúncia são obrigatórios.' });
    }
    const id = genId('rep');
    const result = await pool.query(
      `INSERT INTO reports (id, campaign_id, reporter_id, reason, status)
       VALUES ($1, $2, $3, $4, 'em_analise')
       RETURNING *`,
      [id, campaign_id, req.user.sub, reason.trim()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/reports/:id', authenticateJWT, requireRoles('Admin'), async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const result = await pool.query(
      'UPDATE reports SET status = $1 WHERE id = $2 RETURNING *',
      [status, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Denúncia não encontrada.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/reports/:id', authenticateJWT, requireRoles('Admin'), async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM reports WHERE id = $1', [id]);
    res.json({ success: true, message: 'Denúncia removida.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 6. VERIFICAÇÃO DE ONG (NGO Verification) - CRUD
// ============================================================================

app.get('/api/verifications', authenticateJWT, async (req, res) => {
  try {
    const { userId } = req.query;
    let query = 'SELECT * FROM ngo_verifications';
    const params = [];
    if (userId) {
      params.push(userId);
      query += ' WHERE user_id = $1';
    }
    query += ' ORDER BY created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/verifications', authenticateJWT, async (req, res) => {
  try {
    const { organization_name, document_number, documents_url } = req.body;
    if (!organization_name || !document_number) {
      return res.status(400).json({ error: 'Razão social e CNPJ são obrigatórios.' });
    }
    const id = genId('vng');
    const result = await pool.query(
      `INSERT INTO ngo_verifications (id, user_id, organization_name, document_number, documents_url, status)
       VALUES ($1, $2, $3, $4, $5, 'pendente')
       RETURNING *`,
      [id, req.user.sub, organization_name.trim(), document_number.trim(), documents_url || '']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/verifications/:id', authenticateJWT, requireRoles('Admin'), async (req, res) => {
  try {
    const { id } = req.params;
    const { status, notes } = req.body;
    // A trigger PL/pgSQL trg_ngo_verification_after_update promove o usuário para ONG e envia notificação!
    const result = await pool.query(
      'UPDATE ngo_verifications SET status = COALESCE($1, status), notes = COALESCE($2, notes) WHERE id = $3 RETURNING *',
      [status, notes, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitação de verificação não encontrada.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/verifications/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM ngo_verifications WHERE id = $1', [id]);
    res.json({ success: true, message: 'Solicitação cancelada.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 7. CATEGORIAS (Categories) - CRUD
// ============================================================================

app.get('/api/categories', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM categories ORDER BY name ASC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/categories', authenticateJWT, async (req, res) => {
  try {
    const { name, icon_name } = req.body;
    if (!name) {
      return res.status(400).json({ error: 'O nome da categoria é obrigatório.' });
    }
    const id = genId('cat');
    const result = await pool.query(
      'INSERT INTO categories (id, name, icon_name) VALUES ($1, $2, $3) RETURNING *',
      [id, name.trim(), icon_name || 'folder.fill']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/categories/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, icon_name } = req.body;
    const result = await pool.query(
      'UPDATE categories SET name = COALESCE($1, name), icon_name = COALESCE($2, icon_name) WHERE id = $3 RETURNING *',
      [name, icon_name, id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/categories/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM categories WHERE id = $1', [id]);
    res.json({ success: true, message: 'Categoria excluída.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 8. FAVORITOS (Favorites) - CRUD
// ============================================================================

app.get('/api/favorites', authenticateJWT, async (req, res) => {
  try {
    const userId = req.query.userId || req.user.sub;
    const result = await pool.query(
      `SELECT f.*, c.title, c.description, c.goal_amount, c.current_amount, c.location_name
       FROM favorites f
       JOIN campaigns c ON f.campaign_id = c.id
       WHERE f.user_id = $1
       ORDER BY f.created_at DESC`,
      [userId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/favorites', authenticateJWT, async (req, res) => {
  try {
    const { campaign_id } = req.body;
    const userId = req.user.sub;
    const id = genId('fav');
    const result = await pool.query(
      `INSERT INTO favorites (id, user_id, campaign_id)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, campaign_id) DO NOTHING
       RETURNING *`,
      [id, userId, campaign_id]
    );
    res.status(201).json(result.rows[0] || { id, user_id: userId, campaign_id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/favorites', authenticateJWT, async (req, res) => {
  try {
    const userId = req.query.userId || req.query.user_id || req.user.sub;
    const campaignId = req.query.campaignId || req.query.campaign_id;
    await pool.query('DELETE FROM favorites WHERE user_id = $1 AND campaign_id = $2', [
      userId,
      campaignId,
    ]);
    res.json({ success: true, message: 'Removido dos favoritos.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 9. SOLICITAÇÕES DE SAQUE PIX (Withdrawals) - CRUD
// ============================================================================

app.get('/api/withdrawals', authenticateJWT, async (req, res) => {
  try {
    const { creatorId } = req.query;
    let query = `
      SELECT w.*, c.title AS campaign_title
      FROM withdrawal_requests w
      JOIN campaigns c ON w.campaign_id = c.id
    `;
    const params = [];
    if (creatorId) {
      params.push(creatorId);
      query += ' WHERE w.creator_id = $1';
    } else if (req.user.role !== 'Admin') {
      params.push(req.user.sub);
      query += ' WHERE w.creator_id = $1';
    }
    query += ' ORDER BY w.created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/withdrawals', authenticateJWT, requireRoles('Criador', 'ONG', 'Admin'), async (req, res) => {
  try {
    const { campaign_id, amount, pix_key } = req.body;
    const numAmount = parseFloat(amount);
    if (!campaign_id || !Number.isFinite(numAmount) || numAmount <= 0 || !pix_key) {
      return res.status(400).json({ error: 'Campanha, valor positivo e chave PIX são obrigatórios.' });
    }
    const id = genId('wth');
    // A trigger PL/pgSQL trg_withdrawal_before_insert valida se há saldo suficiente na campanha!
    const result = await pool.query(
      `INSERT INTO withdrawal_requests (id, campaign_id, creator_id, amount, pix_key, status)
       VALUES ($1, $2, $3, $4, $5, 'em_analise')
       RETURNING *`,
      [id, campaign_id, req.user.sub, numAmount, pix_key.trim()]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put('/api/withdrawals/:id', authenticateJWT, requireRoles('Admin'), async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    // A trigger PL/pgSQL trg_withdrawal_after_update envia a notificação de aprovação/rejeição ao criador!
    const result = await pool.query(
      'UPDATE withdrawal_requests SET status = $1 WHERE id = $2 RETURNING *',
      [status, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitação de saque não encontrada.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/withdrawals/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM withdrawal_requests WHERE id = $1', [id]);
    res.json({ success: true, message: 'Solicitação de saque cancelada.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// 10. NOTIFICAÇÕES (Notifications) - CRUD
// ============================================================================

app.get('/api/notifications', authenticateJWT, async (req, res) => {
  try {
    const userId = req.query.userId || req.user.sub;
    const result = await pool.query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/notifications/:id/read', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'UPDATE notifications SET is_read = true WHERE id = $1 RETURNING *',
      [id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/notifications/:id', authenticateJWT, async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM notifications WHERE id = $1', [id]);
    res.json({ success: true, message: 'Notificação excluída.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ============================================================================
// USUÁRIOS (Listagem de perfis para alternância e administração)
// ============================================================================

app.get('/api/users', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, email, role, avatar_url, latitude, longitude, city, state, created_at FROM users ORDER BY created_at ASC'
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

initDB()
  .then(() => {
    app.listen(port, '0.0.0.0', () => {
      console.log(`NEXO VAKINHA API rodando em http://0.0.0.0:${port}/api conectada ao PostgreSQL (vakinhadb)!`);
    });
  })
  .catch((err) => {
    console.error('Erro fatal ao inicializar o PostgreSQL vakinhadb:', err);
    process.exit(1);
  });
