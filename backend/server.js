const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const { pool, initDB } = require('./db');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '15mb' }));

function genId(prefix) {
  return `${prefix}-${Date.now().toString(36)}-${crypto.randomBytes(3).toString('hex')}`;
}

// Senhas novas: scrypt com salt aleatório no formato "scrypt$<salt>$<hash>"
function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return `scrypt$${salt}$${hash}`;
}

function md5(password) {
  return crypto.createHash('md5').update(password).digest('hex');
}

// Aceita hashes scrypt e o formato MD5 legado dos dados semeados
function verifyPassword(password, stored) {
  if (!stored) return false;
  if (stored.startsWith('scrypt$')) {
    const [, salt, hash] = stored.split('$');
    const expected = Buffer.from(hash, 'hex');
    const actual = crypto.scryptSync(password, salt, expected.length);
    return crypto.timingSafeEqual(expected, actual);
  }
  return stored === md5(password);
}

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// --------------------------------------------------------------------------
// HEALTH CHECK
// --------------------------------------------------------------------------
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', database: 'conectado', timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(503).json({ status: 'erro', database: 'desconectado', error: err.message });
  }
});

// --------------------------------------------------------------------------
// 0. AUTENTICAÇÃO E PERFIL SEGURO (Persistência & Credenciais)
// --------------------------------------------------------------------------
app.post('/api/auth/register', async (req, res) => {
  try {
    const { name, email, password, role, latitude, longitude, city, state } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Nome, email e senha são obrigatórios' });
    }
    if (!EMAIL_REGEX.test(email)) {
      return res.status(400).json({ error: 'Email inválido' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'A senha deve ter no mínimo 6 caracteres' });
    }
    const check = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (check.rows.length > 0) {
      return res.status(409).json({ error: 'Email já cadastrado na plataforma' });
    }
    const id = genId('usr');
    const pwdHash = hashPassword(password);
    const result = await pool.query(
      `INSERT INTO users (id, name, email, password_hash, role, latitude, longitude, city, state)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, name, email, role, avatar_url, latitude, longitude, city, state, created_at`,
      [id, name, email, pwdHash, role || 'Doador', latitude || null, longitude || null, city || null, state || null]
    );
    const token = crypto.randomBytes(32).toString('hex');
    res.status(201).json({ user: result.rows[0], token });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email e senha são obrigatórios' });
    }
    const result = await pool.query(
      `SELECT id, name, email, role, avatar_url, latitude, longitude, city, state, created_at, password_hash
       FROM users WHERE email = $1`,
      [email]
    );
    const row = result.rows[0];
    if (!row || !verifyPassword(password, row.password_hash)) {
      return res.status(401).json({ error: 'Credenciais inválidas. Verifique seu email e senha.' });
    }
    // Migra hashes MD5 legados para scrypt no primeiro login bem-sucedido
    if (!row.password_hash.startsWith('scrypt$')) {
      await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [hashPassword(password), row.id]);
    }
    const { password_hash, ...user } = row;
    const token = crypto.randomBytes(32).toString('hex');
    res.json({ user, token });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/auth/profile/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, avatar_url, latitude, longitude, city, state } = req.body;
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
      [name, avatar_url, latitude, longitude, city, state, id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Usuário não encontrado' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --------------------------------------------------------------------------
// 1. CAMPANHAS (Campaigns) - CRUD
// --------------------------------------------------------------------------
app.get('/api/campaigns', async (req, res) => {
  try {
    const { category, search, creatorId } = req.query;
    let query = `
      SELECT c.*, cat.name as category_name, cat.icon_name as category_icon, u.name as creator_name,
        (SELECT COUNT(*) FROM donations d WHERE d.campaign_id = c.id) as donations_count
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
    const result = await pool.query(`
      SELECT c.*, cat.name as category_name, cat.icon_name as category_icon, u.name as creator_name,
        (SELECT COUNT(*) FROM donations d WHERE d.campaign_id = c.id) as donations_count
      FROM campaigns c
      LEFT JOIN categories cat ON c.category_id = cat.id
      LEFT JOIN users u ON c.creator_id = u.id
      WHERE c.id = $1
    `, [id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Campanha não encontrada' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/campaigns', async (req, res) => {
  try {
    const { title, description, goal_amount, category_id, creator_id, image_url, latitude, longitude, location_name } = req.body;
    const id = genId('cmp');
    const result = await pool.query(
      `INSERT INTO campaigns (id, title, description, goal_amount, current_amount, category_id, creator_id, status, image_url, latitude, longitude, location_name)
       VALUES ($1, $2, $3, $4, 0.0, $5, $6, 'ativa', $7, $8, $9, $10) RETURNING *`,
      [id, title, description, parseFloat(goal_amount) || 0, category_id, creator_id || 'usr-1', image_url || null, latitude || null, longitude || null, location_name || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/campaigns/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, goal_amount, category_id, status, image_url, location_name } = req.body;
    const result = await pool.query(
      `UPDATE campaigns 
       SET title = COALESCE($1, title),
           description = COALESCE($2, description),
           goal_amount = COALESCE($3, goal_amount),
           category_id = COALESCE($4, category_id),
           status = COALESCE($5, status),
           image_url = COALESCE($6, image_url),
           location_name = COALESCE($7, location_name)
       WHERE id = $8 RETURNING *`,
      [title, description, goal_amount ? parseFloat(goal_amount) : null, category_id, status, image_url, location_name, id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Campanha não encontrada' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/campaigns/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM campaigns WHERE id = $1', [id]);
    res.json({ success: true, message: 'Campanha removida com sucesso' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --------------------------------------------------------------------------
// 2. DOAÇÕES (Donations) - CRUD
// --------------------------------------------------------------------------
app.get('/api/donations', async (req, res) => {
  try {
    const { campaignId, userId } = req.query;
    let query = `
      SELECT d.*, u.name as user_name, c.title as campaign_title
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

app.post('/api/donations', async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { campaign_id, user_id, amount, payment_method, message } = req.body;
    const numAmount = parseFloat(amount);
    if (!campaign_id || !Number.isFinite(numAmount) || numAmount <= 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Informe uma campanha e um valor de doação maior que zero' });
    }
    const statusResult = await client.query('SELECT status FROM campaigns WHERE id = $1 FOR UPDATE', [campaign_id]);
    if (statusResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Campanha não encontrada' });
    }
    if (statusResult.rows[0].status !== 'ativa') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'Esta campanha não está mais recebendo doações' });
    }
    const id = genId('don');

    const donResult = await client.query(
      `INSERT INTO donations (id, campaign_id, user_id, amount, payment_method, message)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [id, campaign_id, user_id || 'usr-1', numAmount, payment_method || 'PIX', message || null]
    );

    await client.query(
      `UPDATE campaigns SET current_amount = current_amount + $1 WHERE id = $2`,
      [numAmount, campaign_id]
    );

    const cmpResult = await client.query('SELECT creator_id, title FROM campaigns WHERE id = $1', [campaign_id]);
    if (cmpResult.rows.length > 0) {
      const cmp = cmpResult.rows[0];
      await client.query(
        `INSERT INTO notifications (id, user_id, title, content)
         VALUES ($1, $2, $3, $4)`,
        [genId('not'), cmp.creator_id, 'Nova Doacao Recebida', `Sua vaquinha "${cmp.title}" recebeu R$ ${numAmount.toFixed(2)} via ${payment_method || 'PIX'}.`]
      );
    }

    await client.query('COMMIT');
    res.status(201).json(donResult.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// --------------------------------------------------------------------------
// 3. ATUALIZAÇÕES DA CAMPANHA (Novidades/Campaign Updates) - CRUD
// --------------------------------------------------------------------------
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

app.post('/api/updates', async (req, res) => {
  try {
    const { campaign_id, title, content, image_url } = req.body;
    const id = genId('upd');
    const result = await pool.query(
      `INSERT INTO campaign_updates (id, campaign_id, title, content, image_url)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [id, campaign_id, title, content, image_url || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/updates/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, content, image_url } = req.body;
    const result = await pool.query(
      `UPDATE campaign_updates SET title = COALESCE($1, title), content = COALESCE($2, content), image_url = COALESCE($3, image_url) WHERE id = $4 RETURNING *`,
      [title, content, image_url, id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/updates/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM campaign_updates WHERE id = $1', [id]);
    res.json({ success: true, message: 'Atualização excluída' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --------------------------------------------------------------------------
// 4. MENSAGENS DO MURAL (Wall Messages) - CRUD
// --------------------------------------------------------------------------
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

app.post('/api/messages', async (req, res) => {
  try {
    const { campaign_id, user_id, author_name, message } = req.body;
    const id = genId('msg');
    const result = await pool.query(
      `INSERT INTO wall_messages (id, campaign_id, user_id, author_name, message)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [id, campaign_id, user_id || 'usr-1', author_name || 'Apoiador Anônimo', message]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/messages/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM wall_messages WHERE id = $1', [id]);
    res.json({ success: true, message: 'Mensagem removida' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --------------------------------------------------------------------------
// 5. DENÚNCIAS (Reports) - CRUD
// --------------------------------------------------------------------------
app.get('/api/reports', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT r.*, c.title as campaign_title, u.name as reporter_name
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

app.post('/api/reports', async (req, res) => {
  try {
    const { campaign_id, reporter_id, reason } = req.body;
    const id = genId('rep');
    const result = await pool.query(
      `INSERT INTO reports (id, campaign_id, reporter_id, reason, status)
       VALUES ($1, $2, $3, $4, 'em_analise') RETURNING *`,
      [id, campaign_id, reporter_id || 'usr-1', reason]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/reports/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const result = await pool.query(
      'UPDATE reports SET status = $1 WHERE id = $2 RETURNING *',
      [status, id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/reports/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM reports WHERE id = $1', [id]);
    res.json({ success: true, message: 'Denúncia removida' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --------------------------------------------------------------------------
// 6. VERIFICAÇÃO DE ONG (NGO Verification) - CRUD
// --------------------------------------------------------------------------
app.get('/api/verifications', async (req, res) => {
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

app.post('/api/verifications', async (req, res) => {
  try {
    const { user_id, organization_name, document_number, documents_url } = req.body;
    const id = genId('vng');
    const result = await pool.query(
      `INSERT INTO ngo_verifications (id, user_id, organization_name, document_number, documents_url, status)
       VALUES ($1, $2, $3, $4, $5, 'pendente') RETURNING *`,
      [id, user_id || 'usr-3', organization_name, document_number, documents_url || '']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/verifications/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, notes } = req.body;
    const result = await pool.query(
      'UPDATE ngo_verifications SET status = COALESCE($1, status), notes = COALESCE($2, notes) WHERE id = $3 RETURNING *',
      [status, notes, id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/verifications/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM ngo_verifications WHERE id = $1', [id]);
    res.json({ success: true, message: 'Solicitação cancelada' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --------------------------------------------------------------------------
// 7. CATEGORIAS (Categories) - CRUD
// --------------------------------------------------------------------------
app.get('/api/categories', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM categories ORDER BY name ASC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/categories', async (req, res) => {
  try {
    const { name, icon_name } = req.body;
    const id = genId('cat');
    const result = await pool.query(
      'INSERT INTO categories (id, name, icon_name) VALUES ($1, $2, $3) RETURNING *',
      [id, name, icon_name || 'folder.fill']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/categories/:id', async (req, res) => {
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

app.delete('/api/categories/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM categories WHERE id = $1', [id]);
    res.json({ success: true, message: 'Categoria excluída' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --------------------------------------------------------------------------
// 8. FAVORITOS (Favorites) - CRUD
// --------------------------------------------------------------------------
app.get('/api/favorites', async (req, res) => {
  try {
    const { userId } = req.query;
    const result = await pool.query(`
      SELECT f.*, c.title, c.description, c.goal_amount, c.current_amount, c.location_name
      FROM favorites f
      JOIN campaigns c ON f.campaign_id = c.id
      WHERE f.user_id = $1
      ORDER BY f.created_at DESC
    `, [userId || 'usr-1']);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/favorites', async (req, res) => {
  try {
    const { user_id, campaign_id } = req.body;
    const id = genId('fav');
    const result = await pool.query(
      `INSERT INTO favorites (id, user_id, campaign_id)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, campaign_id) DO NOTHING
       RETURNING *`,
      [id, user_id || 'usr-1', campaign_id]
    );
    res.status(201).json(result.rows[0] || { message: 'Já é favorito' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/favorites', async (req, res) => {
  try {
    const { user_id, campaign_id } = req.query;
    await pool.query('DELETE FROM favorites WHERE user_id = $1 AND campaign_id = $2', [user_id || 'usr-1', campaign_id]);
    res.json({ success: true, message: 'Removido dos favoritos' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --------------------------------------------------------------------------
// 9. SOLICITAÇÕES DE SAQUE (Withdrawals) - CRUD
// --------------------------------------------------------------------------
app.get('/api/withdrawals', async (req, res) => {
  try {
    const { creatorId } = req.query;
    let query = `
      SELECT w.*, c.title as campaign_title
      FROM withdrawal_requests w
      JOIN campaigns c ON w.campaign_id = c.id
    `;
    const params = [];
    if (creatorId) {
      params.push(creatorId);
      query += ' WHERE w.creator_id = $1';
    }
    query += ' ORDER BY w.created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/withdrawals', async (req, res) => {
  try {
    const { campaign_id, creator_id, amount, pix_key } = req.body;
    const id = genId('wth');
    const result = await pool.query(
      `INSERT INTO withdrawal_requests (id, campaign_id, creator_id, amount, pix_key, status)
       VALUES ($1, $2, $3, $4, $5, 'em_analise') RETURNING *`,
      [id, campaign_id, creator_id || 'usr-1', parseFloat(amount) || 0, pix_key]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/withdrawals/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const result = await pool.query(
      'UPDATE withdrawal_requests SET status = $1 WHERE id = $2 RETURNING *',
      [status, id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/withdrawals/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM withdrawal_requests WHERE id = $1', [id]);
    res.json({ success: true, message: 'Solicitação cancelada' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --------------------------------------------------------------------------
// 10. NOTIFICAÇÕES (Notifications) - CRUD
// --------------------------------------------------------------------------
app.get('/api/notifications', async (req, res) => {
  try {
    const { userId } = req.query;
    const result = await pool.query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC',
      [userId || 'usr-1']
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/notifications/:id/read', async (req, res) => {
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

app.delete('/api/notifications/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM notifications WHERE id = $1', [id]);
    res.json({ success: true, message: 'Notificação excluída' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --------------------------------------------------------------------------
// USUÁRIOS
// --------------------------------------------------------------------------
app.get('/api/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT id, name, email, role, avatar_url, latitude, longitude, city, state, created_at FROM users ORDER BY created_at ASC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

initDB()
  .then(() => {
    app.listen(port, () => {
      console.log(`VAKINHA API Server rodando na porta ${port} conectado ao PostgreSQL (vakinhadb)!`);
    });
  })
  .catch((err) => {
    console.error('Erro ao conectar ao PostgreSQL vakinhadb:', err);
    process.exit(1);
  });
