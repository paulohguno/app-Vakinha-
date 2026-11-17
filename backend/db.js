const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.PGHOST || 'localhost',
  port: parseInt(process.env.PGPORT || '5432', 10),
  user: process.env.PGUSER || 'paulohenriquegarbo',
  password: process.env.PGPASSWORD || '',
  database: process.env.PGDATABASE || 'vakinhadb',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  console.error('[PostgreSQL Pool Error]:', err.message);
});

async function initDB() {
  const client = await pool.connect();
  try {
    const schemaPath = path.join(__dirname, 'schema.sql');
    if (fs.existsSync(schemaPath)) {
      const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
      await client.query(schemaSQL);
      console.log('[DB] Schema PL/pgSQL, Triggers e Seed Inicial sincronizados com sucesso em vakinhadb.');
    } else {
      throw new Error('Arquivo schema.sql não encontrado no diretório backend.');
    }
  } finally {
    client.release();
  }
}

module.exports = { pool, initDB };
