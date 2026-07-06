require('dotenv').config();
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const Stripe = require('stripe');
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');
const path = require('path');
const fs   = require('fs');

// ── Stripe ────────────────────────────────────────────────────────────────────
const stripe = Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_REPLACE_WITH_YOUR_STRIPE_SECRET_KEY');

// ── Express + Socket.IO ───────────────────────────────────────────────────────
const app = express();
const server = http.createServer(app);
const io = socketIo(server, { cors: { origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'] } });

app.use(cors());
app.use(express.json());

// ── PostgreSQL Pool ───────────────────────────────────────────────────────────
const pool = new Pool(
  process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL }
    : {
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        database: process.env.DB_NAME || 'queuenova',
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || 'password',
      }
);

let dbAvailable = false;

// ── Default in-memory data (fallback when PostgreSQL is not running) ──────────
const inMemory = {
  staffUsers: [
    { id: 1, name: 'Admin User',       email: 'admin@queuenova.gov.lk',    password_hash: 'admin123',      role: 'Administrator',      status: 'Active', last_active: new Date().toISOString() },
    { id: 2, name: 'Queue Officer',    email: 'queue@queuenova.gov.lk',    password_hash: 'queue123',      role: 'Queue Manager',      status: 'Active', last_active: new Date().toISOString() },
    { id: 3, name: 'Service Officer',  email: 'service@queuenova.gov.lk',  password_hash: 'service123',    role: 'Service Officer',    status: 'Active', last_active: new Date().toISOString() },
    { id: 4, name: 'Reception Officer',email: 'reception@queuenova.gov.lk',password_hash: 'reception123',  role: 'Reception',          status: 'Offline', last_active: new Date(Date.now()-7200000).toISOString() },
    { id: 5, name: 'Dept. Manager',   email: 'manager@queuenova.gov.lk',  password_hash: 'manager123',    role: 'Department Manager', status: 'Active', last_active: new Date().toISOString() },
  ],
  queueEntries: [
    { id: 1, token: 'A-025', office_id: 'Divisional Secretariat - Colombo', citizen_name: 'K.N.T. Nikethani', service: 'Passport Renewal', status: 'waiting', counter: 1, is_priority: false, payment_status: 'paid',    fee: 5000, wait_time: '25 min', created_at: new Date().toISOString() },
    { id: 2, token: 'A-026', office_id: 'Divisional Secretariat - Colombo', citizen_name: 'Saman Perera',     service: 'NIC Card',          status: 'waiting', counter: 1, is_priority: false, payment_status: 'paid',    fee: 500,  wait_time: '30 min', created_at: new Date().toISOString() },
    { id: 3, token: 'A-027', office_id: 'Divisional Secretariat - Colombo', citizen_name: 'Mala Kumari',      service: 'Driving License',   status: 'waiting', counter: 2, is_priority: true,  payment_status: 'pending', fee: 3000, wait_time: '35 min', created_at: new Date().toISOString() },
    { id: 4, token: 'A-028', office_id: 'Divisional Secretariat - Colombo', citizen_name: 'Ruwan Jaya',       service: 'Birth Certificate', status: 'waiting', counter: 1, is_priority: false, payment_status: 'paid',    fee: 200,  wait_time: '40 min', created_at: new Date().toISOString() },
    { id: 5, token: 'A-029', office_id: 'Divisional Secretariat - Colombo', citizen_name: 'Deepani Fernando', service: 'NIC Card',          status: 'waiting', counter: 1, is_priority: false, payment_status: 'pending', fee: 500,  wait_time: '45 min', created_at: new Date().toISOString() },
  ],
  emergencyQueue: [
    { id: 1, token: 'E-001', office_id: 'Divisional Secretariat - Colombo', citizen_name: 'Senior Citizen',  reason: 'Medical Emergency',  payment_status: 'paid',    status: 'priority', created_at: new Date().toISOString() },
    { id: 2, token: 'E-002', office_id: 'Divisional Secretariat - Colombo', citizen_name: 'Pregnant Woman',  reason: 'Document Urgent',    payment_status: 'pending', status: 'priority', created_at: new Date().toISOString() },
  ],
  documents: [
    { id: 1, citizen_name: 'K.N.T. Nikethani', document_name: 'NIC Copy.pdf',     document_type: 'ID',       status: 'pending',  uploaded_at: new Date().toISOString() },
    { id: 2, citizen_name: 'Saman Perera',      document_name: 'Birth Cert.pdf',   document_type: 'Personal', status: 'approved', uploaded_at: new Date(Date.now()-3600000).toISOString() },
    { id: 3, citizen_name: 'Mala Kumari',       document_name: 'License Copy.pdf', document_type: 'License',  status: 'pending',  uploaded_at: new Date(Date.now()-1800000).toISOString() },
  ],
  appointments: [],
  auditLogs: [],
  officeSettings: [
    { id: 1, office_id: 'Divisional Secretariat - Colombo',  open_time: '08:00', close_time: '17:00', max_queue: 100, is_active: true },
    { id: 2, office_id: 'RMV - Werahera',                    open_time: '09:00', close_time: '16:00', max_queue: 80,  is_active: true },
    { id: 3, office_id: 'Passport Office - Battaramulla',    open_time: '08:30', close_time: '16:30', max_queue: 120, is_active: true },
  ],
  nextId: 100,
};

// ── DB init: create tables + seed default users ───────────────────────────────
async function initDatabase() {
  try {
    await pool.query('SELECT 1');
    dbAvailable = true;
    console.log('✅ PostgreSQL connected');

    // Create tables
    await pool.query(`
      CREATE TABLE IF NOT EXISTS staff_users (
        id            SERIAL PRIMARY KEY,
        name          VARCHAR(255) NOT NULL,
        email         VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role          VARCHAR(100) NOT NULL,
        status        VARCHAR(50)  DEFAULT 'Active',
        last_active   TIMESTAMP    DEFAULT NOW(),
        created_at    TIMESTAMP    DEFAULT NOW()
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS queue_entries (
        id             SERIAL PRIMARY KEY,
        token          VARCHAR(20)   NOT NULL,
        office_id      VARCHAR(255)  NOT NULL,
        citizen_name   VARCHAR(255),
        citizen_nic    VARCHAR(20),
        service        VARCHAR(255)  NOT NULL,
        status         VARCHAR(50)   DEFAULT 'waiting',
        counter        INTEGER       DEFAULT 1,
        is_priority    BOOLEAN       DEFAULT FALSE,
        payment_status VARCHAR(50)   DEFAULT 'pending',
        fee            DECIMAL(10,2) DEFAULT 0,
        wait_time      VARCHAR(50),
        created_at     TIMESTAMP     DEFAULT NOW(),
        served_at      TIMESTAMP,
        completed_at   TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS emergency_queue (
        id             SERIAL PRIMARY KEY,
        token          VARCHAR(20)  NOT NULL,
        office_id      VARCHAR(255) NOT NULL,
        citizen_name   VARCHAR(255),
        reason         VARCHAR(255),
        payment_status VARCHAR(50)  DEFAULT 'paid',
        status         VARCHAR(50)  DEFAULT 'priority',
        created_at     TIMESTAMP    DEFAULT NOW()
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS documents (
        id             SERIAL PRIMARY KEY,
        appointment_id VARCHAR(255),
        citizen_name   VARCHAR(255),
        document_name  VARCHAR(255) NOT NULL,
        document_type  VARCHAR(100),
        file_path      VARCHAR(500),
        status         VARCHAR(50)  DEFAULT 'pending',
        uploaded_at    TIMESTAMP    DEFAULT NOW(),
        reviewed_at    TIMESTAMP,
        reviewed_by    INTEGER      REFERENCES staff_users(id)
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS appointments (
        id             VARCHAR(255) PRIMARY KEY,
        citizen_nic    VARCHAR(20),
        citizen_name   VARCHAR(255),
        service        VARCHAR(255),
        office         VARCHAR(255),
        date           DATE,
        time           VARCHAR(20),
        token          VARCHAR(20),
        status         VARCHAR(50)   DEFAULT 'scheduled',
        payment_status VARCHAR(50)   DEFAULT 'pending',
        fee_amount     DECIMAL(10,2) DEFAULT 0,
        payment_method VARCHAR(100),
        qr_data        TEXT,
        created_at     TIMESTAMP     DEFAULT NOW()
      )
    `);
    // Add qr_data to existing tables that were created before this column existed
    await pool.query(`ALTER TABLE appointments ADD COLUMN IF NOT EXISTS qr_data TEXT`).catch(() => {});

    await pool.query(`
      CREATE TABLE IF NOT EXISTS audit_logs (
        id         SERIAL PRIMARY KEY,
        action     VARCHAR(255) NOT NULL,
        user_id    INTEGER      REFERENCES staff_users(id),
        user_name  VARCHAR(255),
        details    TEXT,
        created_at TIMESTAMP    DEFAULT NOW()
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id         SERIAL PRIMARY KEY,
        title      VARCHAR(255) NOT NULL,
        message    TEXT         NOT NULL,
        type       VARCHAR(50)  DEFAULT 'system',
        is_read    BOOLEAN      DEFAULT FALSE,
        user_id    INTEGER      REFERENCES staff_users(id),
        metadata   JSONB,
        created_at TIMESTAMP    DEFAULT NOW()
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS office_settings (
        id         SERIAL PRIMARY KEY,
        office_id  VARCHAR(255) UNIQUE NOT NULL,
        open_time  VARCHAR(10)  DEFAULT '08:00',
        close_time VARCHAR(10)  DEFAULT '17:00',
        max_queue  INTEGER      DEFAULT 100,
        is_active  BOOLEAN      DEFAULT TRUE,
        updated_at TIMESTAMP    DEFAULT NOW()
      )
    `);

    // Seed default staff users if table is empty
    const { rowCount } = await pool.query('SELECT 1 FROM staff_users LIMIT 1');
    if (rowCount === 0) {
      const defaultUsers = [
        { name: 'Admin User',        email: 'admin@queuenova.gov.lk',    password: 'admin123',      role: 'Administrator' },
        { name: 'Queue Officer',     email: 'queue@queuenova.gov.lk',    password: 'queue123',      role: 'Queue Manager' },
        { name: 'Service Officer',   email: 'service@queuenova.gov.lk',  password: 'service123',    role: 'Service Officer' },
        { name: 'Reception Officer', email: 'reception@queuenova.gov.lk',password: 'reception123',  role: 'Reception' },
        { name: 'Dept. Manager',     email: 'manager@queuenova.gov.lk',  password: 'manager123',    role: 'Department Manager' },
      ];
      for (const u of defaultUsers) {
        const hash = await bcrypt.hash(u.password, 10);
        await pool.query(
          'INSERT INTO staff_users (name, email, password_hash, role) VALUES ($1, $2, $3, $4)',
          [u.name, u.email, hash, u.role]
        );
      }
      console.log('✅ Seeded default staff users');
    }

    // Seed queue entries if empty
    const { rowCount: qCount } = await pool.query('SELECT 1 FROM queue_entries LIMIT 1');
    if (qCount === 0) {
      for (const q of inMemory.queueEntries) {
        await pool.query(
          `INSERT INTO queue_entries (token, office_id, citizen_name, service, status, counter, is_priority, payment_status, fee, wait_time)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
          [q.token, q.office_id, q.citizen_name, q.service, q.status, q.counter, q.is_priority, q.payment_status, q.fee, q.wait_time]
        );
      }
    }

    // Seed emergency queue if empty
    const { rowCount: eCount } = await pool.query('SELECT 1 FROM emergency_queue LIMIT 1');
    if (eCount === 0) {
      for (const e of inMemory.emergencyQueue) {
        await pool.query(
          'INSERT INTO emergency_queue (token, office_id, citizen_name, reason, payment_status) VALUES ($1,$2,$3,$4,$5)',
          [e.token, e.office_id, e.citizen_name, e.reason, e.payment_status]
        );
      }
    }

    // Seed sample documents if empty
    const { rowCount: dCount } = await pool.query('SELECT 1 FROM documents LIMIT 1');
    if (dCount === 0) {
      for (const d of inMemory.documents) {
        await pool.query(
          'INSERT INTO documents (citizen_name, document_name, document_type, status) VALUES ($1,$2,$3,$4)',
          [d.citizen_name, d.document_name, d.document_type, d.status]
        );
      }
    }

    // Seed office settings if empty
    const { rowCount: osCount } = await pool.query('SELECT 1 FROM office_settings LIMIT 1');
    if (osCount === 0) {
      for (const o of inMemory.officeSettings) {
        await pool.query(
          'INSERT INTO office_settings (office_id, open_time, close_time, max_queue, is_active) VALUES ($1,$2,$3,$4,$5)',
          [o.office_id, o.open_time, o.close_time, o.max_queue, o.is_active]
        );
      }
    }

    console.log('✅ Database ready');
  } catch (err) {
    dbAvailable = false;
    console.warn('⚠️  PostgreSQL not available — running with in-memory data:', err.message);
  }
}

// Helper: log audit action to DB or in-memory
async function logAudit(action, userName, details) {
  try {
    if (dbAvailable) {
      await pool.query(
        'INSERT INTO audit_logs (action, user_name, details) VALUES ($1, $2, $3)',
        [action, userName || 'System', details || '']
      );
    } else {
      inMemory.auditLogs.unshift({ id: ++inMemory.nextId, action, user_name: userName, details, created_at: new Date().toISOString() });
    }
  } catch (_) {}
}

// ── WEB AUTH ──────────────────────────────────────────────────────────────────

app.post('/api/web/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        'SELECT * FROM staff_users WHERE email = $1 AND status != $2',
        [email, 'Deleted']
      );
      if (rows.length === 0) return res.status(401).json({ error: 'Invalid credentials' });

      const user = rows[0];
      const match = await bcrypt.compare(password, user.password_hash);
      if (!match) return res.status(401).json({ error: 'Invalid credentials' });

      // Update last_active
      await pool.query('UPDATE staff_users SET last_active = NOW() WHERE id = $1', [user.id]);
      await logAudit('login', user.name, `Login from web dashboard`);

      return res.json({ id: user.id, name: user.name, email: user.email, role: user.role });
    } else {
      // Fallback in-memory check (plaintext for demo)
      const user = inMemory.staffUsers.find(u => u.email === email && u.password_hash === password);
      if (!user) return res.status(401).json({ error: 'Invalid credentials' });
      return res.json({ id: user.id, name: user.name, email: user.email, role: user.role });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── DASHBOARD STATS ───────────────────────────────────────────────────────────

app.get('/api/web/dashboard/stats', async (req, res) => {
  try {
    if (dbAvailable) {
      const [queueCount, docPending, appointments, citizens, completed] = await Promise.all([
        pool.query("SELECT COUNT(*) FROM queue_entries WHERE status = 'waiting'"),
        pool.query("SELECT COUNT(*) FROM documents WHERE status = 'pending'"),
        pool.query("SELECT COUNT(*) FROM appointments WHERE date = CURRENT_DATE"),
        pool.query('SELECT COUNT(*) FROM appointments'),
        pool.query("SELECT COUNT(*) FROM appointments WHERE status = 'completed'"),
      ]);
      res.json({
        activeQueues: parseInt(queueCount.rows[0].count),
        pendingDocuments: parseInt(docPending.rows[0].count),
        todaysAppointments: parseInt(appointments.rows[0].count),
        totalCitizens: parseInt(citizens.rows[0].count),
        completedServices: parseInt(completed.rows[0].count),
      });
    } else {
      res.json({
        activeQueues: inMemory.queueEntries.filter(q => q.status === 'waiting').length,
        pendingDocuments: inMemory.documents.filter(d => d.status === 'pending').length,
        todaysAppointments: 47,
        totalCitizens: 2847,
        completedServices: 1234,
      });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/web/dashboard/activity', async (req, res) => {
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        'SELECT action, user_name, details, created_at FROM audit_logs ORDER BY created_at DESC LIMIT 20'
      );
      res.json(rows);
    } else {
      res.json(inMemory.auditLogs.slice(0, 20));
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── QUEUE MANAGEMENT ──────────────────────────────────────────────────────────

app.get('/api/web/queue/:officeId', async (req, res) => {
  const { officeId } = req.params;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        "SELECT * FROM queue_entries WHERE office_id = $1 AND status = 'waiting' ORDER BY created_at ASC",
        [officeId]
      );
      res.json(rows);
    } else {
      res.json(inMemory.queueEntries.filter(q => q.office_id === officeId && q.status === 'waiting'));
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/queue/call-next', async (req, res) => {
  const { officeId, officerName } = req.body;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        "SELECT * FROM queue_entries WHERE office_id = $1 AND status = 'waiting' ORDER BY is_priority DESC, created_at ASC LIMIT 1",
        [officeId]
      );
      if (rows.length === 0) return res.json({ success: false, message: 'Queue is empty' });

      const token = rows[0];
      await pool.query(
        "UPDATE queue_entries SET status = 'serving', served_at = NOW() WHERE id = $1",
        [token.id]
      );
      await logAudit('call_next', officerName, `Called token ${token.token} at ${officeId}`);
      io.emit('queue_update', { officeId, calledToken: token.token });
      res.json({ success: true, token });
    } else {
      const idx = inMemory.queueEntries.findIndex(q => q.office_id === officeId && q.status === 'waiting');
      if (idx === -1) return res.json({ success: false, message: 'Queue is empty' });
      const token = inMemory.queueEntries[idx];
      inMemory.queueEntries.splice(idx, 1);
      io.emit('queue_update', { officeId, calledToken: token.token });
      res.json({ success: true, token });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/queue/complete', async (req, res) => {
  const { token, officerName } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        "UPDATE queue_entries SET status = 'completed', completed_at = NOW() WHERE token = $1",
        [token]
      );
      await logAudit('complete_service', officerName, `Completed service for token ${token}`);
    } else {
      const idx = inMemory.queueEntries.findIndex(q => q.token === token);
      if (idx !== -1) inMemory.queueEntries.splice(idx, 1);
    }
    io.emit('service_completed', { token });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/queue/:token/counter', async (req, res) => {
  const { token } = req.params;
  const { counter, officerName } = req.body;
  try {
    if (dbAvailable) {
      await pool.query('UPDATE queue_entries SET counter = $1 WHERE token = $2', [counter, token]);
      await logAudit('reassign_counter', officerName, `Reassigned ${token} to counter ${counter}`);
    } else {
      const q = inMemory.queueEntries.find(q => q.token === token);
      if (q) q.counter = counter;
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/web/queue/emergency/:officeId', async (req, res) => {
  const { officeId } = req.params;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        "SELECT * FROM emergency_queue WHERE office_id = $1 AND status = 'priority' ORDER BY created_at ASC",
        [officeId]
      );
      res.json(rows);
    } else {
      res.json(inMemory.emergencyQueue.filter(e => e.office_id === officeId));
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/queue/emergency/process', async (req, res) => {
  const { token, officerName } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        "UPDATE emergency_queue SET status = 'processed' WHERE token = $1",
        [token]
      );
      await logAudit('process_emergency', officerName, `Processed emergency token ${token}`);
    } else {
      const idx = inMemory.emergencyQueue.findIndex(e => e.token === token);
      if (idx !== -1) inMemory.emergencyQueue.splice(idx, 1);
    }
    io.emit('queue_update', { emergencyProcessed: token });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── STAFF USERS ───────────────────────────────────────────────────────────────

app.get('/api/web/users', async (req, res) => {
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        'SELECT id, name, email, role, status, last_active FROM staff_users ORDER BY created_at ASC'
      );
      res.json(rows);
    } else {
      res.json(inMemory.staffUsers.map(u => ({ id: u.id, name: u.name, email: u.email, role: u.role, status: u.status, last_active: u.last_active })));
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/users', async (req, res) => {
  const { name, email, password, role, createdBy } = req.body;
  try {
    if (dbAvailable) {
      const hash = await bcrypt.hash(password || 'changeme123', 10);
      const { rows } = await pool.query(
        'INSERT INTO staff_users (name, email, password_hash, role) VALUES ($1, $2, $3, $4) RETURNING id, name, email, role, status',
        [name, email, hash, role]
      );
      await logAudit('create_user', createdBy, `Created user ${email} with role ${role}`);
      res.json({ success: true, user: rows[0] });
    } else {
      const id = ++inMemory.nextId;
      inMemory.staffUsers.push({ id, name, email, password_hash: password || 'changeme123', role, status: 'Active', last_active: new Date().toISOString() });
      res.json({ success: true, user: { id, name, email, role, status: 'Active' } });
    }
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Email already exists' });
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/users/:id', async (req, res) => {
  const { id } = req.params;
  const { name, email, role, updatedBy } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        'UPDATE staff_users SET name = $1, email = $2, role = $3 WHERE id = $4',
        [name, email, role, id]
      );
      await logAudit('update_user', updatedBy, `Updated user ${email}`);
    } else {
      const u = inMemory.staffUsers.find(u => u.id === parseInt(id));
      if (u) { u.name = name; u.email = email; u.role = role; }
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/web/users/:id', async (req, res) => {
  const { id } = req.params;
  const { deletedBy } = req.body;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query('SELECT email FROM staff_users WHERE id = $1', [id]);
      await pool.query("UPDATE staff_users SET status = 'Deleted' WHERE id = $1", [id]);
      if (rows.length) await logAudit('delete_user', deletedBy, `Deleted user ${rows[0].email}`);
    } else {
      const idx = inMemory.staffUsers.findIndex(u => u.id === parseInt(id));
      if (idx !== -1) inMemory.staffUsers.splice(idx, 1);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── DOCUMENTS ─────────────────────────────────────────────────────────────────

app.get('/api/web/documents', async (req, res) => {
  try {
    if (dbAvailable) {
      const { rows } = await pool.query('SELECT * FROM documents ORDER BY uploaded_at DESC');
      res.json(rows);
    } else {
      res.json(inMemory.documents);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.patch('/api/web/documents/:id/approve', async (req, res) => {
  const { id } = req.params;
  const { reviewedBy } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        "UPDATE documents SET status = 'approved', reviewed_at = NOW() WHERE id = $1",
        [id]
      );
      await logAudit('approve_document', reviewedBy, `Approved document #${id}`);
    } else {
      const d = inMemory.documents.find(d => d.id === parseInt(id));
      if (d) d.status = 'approved';
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.patch('/api/web/documents/:id/reject', async (req, res) => {
  const { id } = req.params;
  const { reviewedBy, reason } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        "UPDATE documents SET status = 'rejected', reviewed_at = NOW() WHERE id = $1",
        [id]
      );
      await logAudit('reject_document', reviewedBy, `Rejected document #${id}: ${reason || ''}`);
    } else {
      const d = inMemory.documents.find(d => d.id === parseInt(id));
      if (d) d.status = 'rejected';
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── APPOINTMENTS (mirror from Firestore) ──────────────────────────────────────

app.get('/api/web/appointments', async (req, res) => {
  try {
    if (dbAvailable) {
      const { rows } = await pool.query('SELECT * FROM appointments ORDER BY created_at DESC LIMIT 100');
      res.json(rows);
    } else {
      res.json(inMemory.appointments);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/appointments', async (req, res) => {
  const { id, citizen_nic, citizen_name, service, office, date, time, token, payment_status, fee_amount, payment_method, qr_data } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        `INSERT INTO appointments (id, citizen_nic, citizen_name, service, office, date, time, token, payment_status, fee_amount, payment_method, qr_data)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
         ON CONFLICT (id) DO UPDATE SET
           status         = EXCLUDED.status,
           payment_status = EXCLUDED.payment_status,
           qr_data        = COALESCE(EXCLUDED.qr_data, appointments.qr_data)`,
        [id, citizen_nic, citizen_name, service, office, date, time, token, payment_status, fee_amount, payment_method, qr_data || null]
      );
    } else {
      inMemory.appointments.push(req.body);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/appointments/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status, payment_status } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        'UPDATE appointments SET status = COALESCE($1, status), payment_status = COALESCE($2, payment_status) WHERE id = $3',
        [status, payment_status, id]
      );
    } else {
      const a = inMemory.appointments.find(a => a.id === id);
      if (a) { if (status) a.status = status; if (payment_status) a.payment_status = payment_status; }
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── NOTIFICATIONS ─────────────────────────────────────────────────────────────

app.get('/api/web/notifications/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        'SELECT * FROM notifications WHERE user_id = $1 OR user_id IS NULL ORDER BY created_at DESC LIMIT 50',
        [userId]
      );
      res.json(rows);
    } else {
      res.json([]);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/notifications/:id/read', async (req, res) => {
  const { id } = req.params;
  try {
    if (dbAvailable) {
      await pool.query('UPDATE notifications SET is_read = TRUE WHERE id = $1', [id]);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── SMS (Text.lk) ─────────────────────────────────────────────────────────────
// Requires TEXTLK_API_TOKEN and TEXTLK_SENDER_ID in .env (sign up at https://text.lk)

async function sendSms(phoneNumber, message) {
  const { sendSMS } = await import('textlk-node');
  return sendSMS({ phoneNumber, message });
}

app.post('/api/sms/send', async (req, res) => {
  const { phone, message } = req.body;
  if (!phone || !message) return res.status(400).json({ error: 'phone and message are required' });
  try {
    const result = await sendSms(phone, message);
    res.json({ success: true, result });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── AUDIT LOGS ────────────────────────────────────────────────────────────────

app.get('/api/web/audit-logs', async (req, res) => {
  const limit = parseInt(req.query.limit || '100');
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        'SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT $1',
        [limit]
      );
      res.json(rows);
    } else {
      res.json(inMemory.auditLogs.slice(0, limit));
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── SYSTEM HEALTH ─────────────────────────────────────────────────────────────

app.get('/api/web/system/health', async (req, res) => {
  const memUsage = process.memoryUsage();
  res.json({
    status: 'healthy',
    database: dbAvailable ? 'connected' : 'in-memory',
    uptime: Math.round(process.uptime()),
    memoryMB: Math.round(memUsage.heapUsed / 1024 / 1024),
    timestamp: new Date().toISOString(),
  });
});

// ── STRIPE PAYMENT ────────────────────────────────────────────────────────────

app.post('/api/create-payment-intent', async (req, res) => {
  const { amount, currency = 'lkr', appointmentId } = req.body;
  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount),
      currency,
      metadata: { appointmentId: appointmentId || '' },
      automatic_payment_methods: { enabled: true },
    });
    res.json({ clientSecret: paymentIntent.client_secret, transactionId: paymentIntent.id });
  } catch (err) {
    console.error('Stripe error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/process-payment', async (req, res) => {
  try {
    await new Promise(resolve => setTimeout(resolve, 800));
    res.json({ success: true, transactionId: `TXN-${Date.now()}`, message: 'Payment processed successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── QUEUE SNAPSHOT (for ML screens) ──────────────────────────────────────────

app.post('/api/queue/update', (req, res) => {
  const { officeId, currentToken, waitingCount, avgServiceTime } = req.body;
  io.emit('queue_update', { officeId, currentToken, waitingCount, avgServiceTime });
  res.json({ success: true });
});

app.get('/api/queue/:officeId', async (req, res) => {
  const officeId = decodeURIComponent(req.params.officeId);
  try {
    if (dbAvailable) {
      const [waitingRes, servingRes] = await Promise.all([
        pool.query(
          "SELECT COUNT(*) FROM queue_entries WHERE office_id=$1 AND status='waiting'",
          [officeId]
        ),
        pool.query(
          "SELECT service FROM queue_entries WHERE office_id=$1 AND status='serving' ORDER BY served_at DESC LIMIT 1",
          [officeId]
        ),
      ]);
      const waitingCount = parseInt(waitingRes.rows[0].count, 10);
      const serviceType  = servingRes.rows.length ? servingRes.rows[0].service : null;
      res.json({
        officeId,
        waitingCount,
        serviceType,
        avgServiceTime: 8,
        lastUpdated: new Date().toISOString(),
      });
    } else {
      const waiting     = inMemory.queueEntries.filter(q => q.office_id === officeId && q.status === 'waiting');
      const serving     = inMemory.queueEntries.find(q => q.office_id === officeId && q.status === 'serving');
      res.json({
        officeId,
        waitingCount: waiting.length,
        serviceType:  serving ? serving.service : null,
        avgServiceTime: 8,
        lastUpdated: new Date().toISOString(),
      });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── ML INFERENCE PROXY (calls Python Flask server on port 5001) ──────────────
// Flask server: cd ml && python inference.py
// Falls back with { fallback: true } when Python server is not running.

const ML_PORT = 5001;

function mlPost(path, body) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
    const req = http.request(
      {
        hostname: 'localhost', port: ML_PORT, path, method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) },
      },
      (res) => {
        let data = '';
        res.on('data', c => { data += c; });
        res.on('end', () => {
          try { resolve(JSON.parse(data)); }
          catch (e) { reject(new Error('Invalid ML response')); }
        });
      }
    );
    req.setTimeout(4000, () => { req.destroy(); reject(new Error('ML timeout')); });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function mlGet(path) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { hostname: 'localhost', port: ML_PORT, path, method: 'GET' },
      (res) => {
        let data = '';
        res.on('data', c => { data += c; });
        res.on('end', () => {
          try { resolve(JSON.parse(data)); }
          catch (e) { reject(new Error('Invalid ML response')); }
        });
      }
    );
    req.setTimeout(3000, () => { req.destroy(); reject(new Error('ML timeout')); });
    req.on('error', reject);
    req.end();
  });
}

// GET /api/ml/health
app.get('/api/ml/health', async (req, res) => {
  try {
    const result = await mlGet('/health');
    res.json(result);
  } catch {
    res.json({ status: 'unavailable', models_ready: false });
  }
});

// POST /api/ml/predict/wait-time
// Body: { officeType, district, serviceType, hour, dayOfWeek, month, numCounters, serviceAvgMin, queueAtArrival, isHoliday }
app.post('/api/ml/predict/wait-time', async (req, res) => {
  try {
    const result = await mlPost('/predict/wait-time', req.body);
    res.json(result);
  } catch {
    res.json({ fallback: true, error: 'ML server unavailable' });
  }
});

// GET /api/ml/predict/:officeName?hour=&day=&month=&district=&service=&counters=
app.get('/api/ml/predict/:officeName', async (req, res) => {
  const officeName = decodeURIComponent(req.params.officeName);
  const now = new Date();
  const hour      = parseInt(req.query.hour)     || now.getHours();
  const dayOfWeek = parseInt(req.query.day)      || now.getDay() || 1;
  const month     = parseInt(req.query.month)    || (now.getMonth() + 1);
  const district  = req.query.district           || '';
  const service   = req.query.service            || 'NIC Card';
  const counters  = parseInt(req.query.counters) || 3;
  const svcMin    = parseFloat(req.query.svcMin) || 10.0;

  try {
    const result = await mlPost('/predict/wait-time', {
      officeType: req.query.officeType || 'Divisional Secretariat',
      district, serviceType: service,
      hour, dayOfWeek, month,
      numCounters: counters, serviceAvgMin: svcMin,
      queueAtArrival: parseInt(req.query.queueCount) || 0,
      isHoliday: 0,
    });
    res.json({ ...result, officeName });
  } catch {
    // Graceful fallback — return live DB count so Dart can use statistical model
    try {
      const encoded = encodeURIComponent(officeName);
      const [waitRes, servRes] = await Promise.all([
        dbAvailable ? pool.query("SELECT COUNT(*) FROM queue_entries WHERE office_id=$1 AND status='waiting'", [officeName]) : null,
        dbAvailable ? pool.query("SELECT service FROM queue_entries WHERE office_id=$1 AND status='serving' ORDER BY served_at DESC LIMIT 1", [officeName]) : null,
      ]);
      const wc = waitRes ? parseInt(waitRes.rows[0].count, 10) : 0;
      const st = servRes && servRes.rows.length ? servRes.rows[0].service : null;
      res.json({ officeName, waitingCount: wc, serviceType: st, fallback: true, lastUpdated: new Date().toISOString() });
    } catch (err2) {
      res.json({ officeName, waitingCount: 0, fallback: true, error: err2.message });
    }
  }
});

// POST /api/ml/predict/peak-hours
// Body: { officeType, district, serviceType, dayOfWeek, month, numCounters, serviceAvgMin }
app.post('/api/ml/predict/peak-hours', async (req, res) => {
  try {
    const result = await mlPost('/predict/peak-hours', req.body);
    res.json(result);
  } catch {
    res.json({ fallback: true, error: 'ML server unavailable' });
  }
});

// POST /api/ml/predict/demand
// Body: { officeType, district, serviceType, month, dayOfWeek, serviceAvgMin }
app.post('/api/ml/predict/demand', async (req, res) => {
  try {
    const result = await mlPost('/predict/demand', req.body);
    res.json(result);
  } catch {
    res.json({ fallback: true, error: 'ML server unavailable' });
  }
});

// POST /api/ml/predict/crowd
// Body: { officeType, district, serviceType, hour, dayOfWeek, month, numCounters, serviceAvgMin }
app.post('/api/ml/predict/crowd', async (req, res) => {
  try {
    const result = await mlPost('/predict/crowd', req.body);
    res.json(result);
  } catch {
    res.json({ fallback: true, error: 'ML server unavailable' });
  }
});

// POST /api/ml/recommend/office
// Body: { offices:[{name,type,district,counters}], serviceType, serviceAvgMin, hour, dayOfWeek, month }
app.post('/api/ml/recommend/office', async (req, res) => {
  try {
    const result = await mlPost('/recommend/office', req.body);
    res.json(result);
  } catch {
    res.json({ fallback: true, error: 'ML server unavailable' });
  }
});

// POST /api/ml/predict/no-show
// Body: { serviceType, district, hour, dayOfWeek, month, fee, isPrepaid, daysInAdvance, serviceAvgMin }
// → will_no_show, no_show_probability, risk_level, recommendation
app.post('/api/ml/predict/no-show', async (req, res) => {
  try {
    const result = await mlPost('/predict/no-show', req.body);
    res.json(result);
  } catch {
    res.json({ fallback: true, error: 'ML server unavailable' });
  }
});

// POST /api/ml/predict/abandonment
// Body: { currentQueueLength, estimatedWaitMin, serviceType, serviceAvgMin, hour, dayOfWeek, fee, isPriority, district }
// → will_abandon, abandon_probability, risk_level, action
app.post('/api/ml/predict/abandonment', async (req, res) => {
  try {
    const result = await mlPost('/predict/abandonment', req.body);
    res.json(result);
  } catch {
    res.json({ fallback: true, error: 'ML server unavailable' });
  }
});

// POST /api/ml/predict/service-duration
// Body: { serviceType, officeType, hour, dayOfWeek, month, queueAtArrival, district, serviceAvgMin }
// → predicted_duration_min, lower_bound_min, upper_bound_min, vs_average
app.post('/api/ml/predict/service-duration', async (req, res) => {
  try {
    const result = await mlPost('/predict/service-duration', req.body);
    res.json(result);
  } catch {
    res.json({ fallback: true, error: 'ML server unavailable' });
  }
});

// POST /api/ml/recommend/counters
// Body: { officeType, district, serviceType, serviceAvgMin, hour, dayOfWeek, month, arrivalsPerHour, availableStaff }
// → recommended_counters, utilisation_pct, throughput_per_counter, can_handle_demand
app.post('/api/ml/recommend/counters', async (req, res) => {
  try {
    const result = await mlPost('/recommend/counters', req.body);
    res.json(result);
  } catch {
    res.json({ fallback: true, error: 'ML server unavailable' });
  }
});

// POST /api/ml/predict/satisfaction
// Body: { actualWaitMin, predictedWaitMin, serviceType, serviceAvgMin, crowdLevelCode, hour, dayOfWeek, isServiceCompleted, officeType, district }
// → satisfaction_score, satisfaction_label, score_probabilities, improvement_tip
app.post('/api/ml/predict/satisfaction', async (req, res) => {
  try {
    const result = await mlPost('/predict/satisfaction', req.body);
    res.json(result);
  } catch {
    res.json({ fallback: true, error: 'ML server unavailable' });
  }
});

// ── SOCKET.IO ─────────────────────────────────────────────────────────────────

const activeUsers = new Map();
const chatMessages = new Map();
const chatConversations = new Map();

io.on('connection', (socket) => {
  socket.on('register', (data) => {
    const { userId, role, name } = data;
    activeUsers.set(userId, { socketId: socket.id, role, name });
    socket.emit('unread_count', { count: 0 });
  });

  socket.on('send_message', (data) => {
    if (!chatMessages.has(data.chatId)) chatMessages.set(data.chatId, []);
    chatMessages.get(data.chatId).push(data);
    io.emit('new_message', data);
  });

  socket.on('mark_read', (data) => {
    if (chatMessages.has(data.chatId)) {
      chatMessages.get(data.chatId).forEach(msg => {
        if (msg.senderId !== data.userId) msg.isRead = true;
      });
    }
    socket.emit('unread_count', { count: 0 });
  });

  socket.on('get_unread_count', () => socket.emit('unread_count', { count: 0 }));

  socket.on('disconnect', () => {
    for (const [userId, user] of activeUsers.entries()) {
      if (user.socketId === socket.id) { activeUsers.delete(userId); break; }
    }
  });
});

// ── CHAT REST ─────────────────────────────────────────────────────────────────

app.get('/api/chats/:userId', (req, res) => res.json(chatConversations.get(req.params.userId) || []));
app.get('/api/messages/:chatId', (req, res) => res.json(chatMessages.get(req.params.chatId) || []));

app.post('/api/chats/start', (req, res) => {
  const { chatId, participantId, participantName, participantRole, senderId, senderName, senderRole } = req.body;
  try {
    const senderConv = { chatId, participantId, participantName, participantRole, lastMessage: 'Chat started', lastMessageTime: new Date().toISOString(), unreadCount: 0 };
    const participantConv = { chatId, participantId: senderId, participantName: senderName, participantRole: senderRole, lastMessage: 'Chat started', lastMessageTime: new Date().toISOString(), unreadCount: 0 };

    const senderChats = chatConversations.get(senderId) || [];
    senderChats.unshift(senderConv);
    chatConversations.set(senderId, senderChats);

    const participantChats = chatConversations.get(participantId) || [];
    participantChats.unshift(participantConv);
    chatConversations.set(participantId, participantChats);

    if (!chatMessages.has(chatId)) chatMessages.set(chatId, []);

    const participant = activeUsers.get(participantId);
    if (participant) io.to(participant.socketId).emit('new_conversation', participantConv);

    res.json({ success: true, chatId });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── QUEUE: ADD ENTRY / CANCEL / STATS ─────────────────────────────────────────

app.post('/api/web/queue', async (req, res) => {
  const { token, officeId, citizenName, citizenNic, service, counter, isPriority, paymentStatus, fee, waitTime, officerName } = req.body;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        `INSERT INTO queue_entries (token, office_id, citizen_name, citizen_nic, service, counter, is_priority, payment_status, fee, wait_time)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
        [token, officeId, citizenName, citizenNic || null, service, counter || 1, isPriority || false, paymentStatus || 'pending', fee || 0, waitTime || null]
      );
      await logAudit('add_queue', officerName, `Added ${token} for ${service} at ${officeId}`);
      io.emit('queue_update', { officeId, newEntry: rows[0] });
      res.json({ success: true, entry: rows[0] });
    } else {
      const entry = { id: ++inMemory.nextId, token, office_id: officeId, citizen_name: citizenName, citizen_nic: citizenNic || null, service, status: 'waiting', counter: counter || 1, is_priority: isPriority || false, payment_status: paymentStatus || 'pending', fee: fee || 0, wait_time: waitTime || null, created_at: new Date().toISOString() };
      inMemory.queueEntries.push(entry);
      io.emit('queue_update', { officeId, newEntry: entry });
      res.json({ success: true, entry });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/queue/emergency', async (req, res) => {
  const { token, officeId, citizenName, reason, paymentStatus, officerName } = req.body;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        `INSERT INTO emergency_queue (token, office_id, citizen_name, reason, payment_status)
         VALUES ($1,$2,$3,$4,$5) RETURNING *`,
        [token, officeId, citizenName, reason, paymentStatus || 'paid']
      );
      await logAudit('add_emergency', officerName, `Added emergency ${token} for ${citizenName}`);
      io.emit('queue_update', { officeId, newEmergency: rows[0] });
      res.json({ success: true, entry: rows[0] });
    } else {
      const entry = { id: ++inMemory.nextId, token, office_id: officeId, citizen_name: citizenName, reason, payment_status: paymentStatus || 'paid', status: 'priority', created_at: new Date().toISOString() };
      inMemory.emergencyQueue.push(entry);
      io.emit('queue_update', { officeId, newEmergency: entry });
      res.json({ success: true, entry });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/web/queue/:token', async (req, res) => {
  const { token } = req.params;
  const { officerName } = req.body;
  try {
    if (dbAvailable) {
      await pool.query("UPDATE queue_entries SET status='cancelled' WHERE token=$1", [token]);
      await logAudit('cancel_queue', officerName, `Cancelled token ${token}`);
    } else {
      const idx = inMemory.queueEntries.findIndex(q => q.token === token);
      if (idx !== -1) inMemory.queueEntries.splice(idx, 1);
    }
    io.emit('queue_update', { cancelledToken: token });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/web/queue/stats/:officeId', async (req, res) => {
  const officeId = decodeURIComponent(req.params.officeId);
  try {
    if (dbAvailable) {
      const [waiting, serving, completed, emergency] = await Promise.all([
        pool.query("SELECT COUNT(*) FROM queue_entries   WHERE office_id=$1 AND status='waiting'",                               [officeId]),
        pool.query("SELECT COUNT(*) FROM queue_entries   WHERE office_id=$1 AND status='serving'",                               [officeId]),
        pool.query("SELECT COUNT(*) FROM queue_entries   WHERE office_id=$1 AND status='completed' AND DATE(completed_at)=CURRENT_DATE", [officeId]),
        pool.query("SELECT COUNT(*) FROM emergency_queue WHERE office_id=$1 AND status='priority'",                              [officeId]),
      ]);
      res.json({
        waiting:        parseInt(waiting.rows[0].count),
        serving:        parseInt(serving.rows[0].count),
        completedToday: parseInt(completed.rows[0].count),
        emergency:      parseInt(emergency.rows[0].count),
      });
    } else {
      res.json({
        waiting:        inMemory.queueEntries.filter(q => q.office_id === officeId && q.status === 'waiting').length,
        serving:        0,
        completedToday: 0,
        emergency:      inMemory.emergencyQueue.filter(e => e.office_id === officeId).length,
      });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── OFFICE SETTINGS ───────────────────────────────────────────────────────────

app.get('/api/web/office-settings', async (req, res) => {
  try {
    if (dbAvailable) {
      const { rows } = await pool.query('SELECT * FROM office_settings ORDER BY office_id');
      res.json(rows);
    } else {
      res.json(inMemory.officeSettings);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/web/office-settings/:officeId', async (req, res) => {
  const officeId = decodeURIComponent(req.params.officeId);
  try {
    if (dbAvailable) {
      const { rows } = await pool.query('SELECT * FROM office_settings WHERE office_id=$1', [officeId]);
      if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
      res.json(rows[0]);
    } else {
      const s = inMemory.officeSettings.find(s => s.office_id === officeId);
      if (!s) return res.status(404).json({ error: 'Not found' });
      res.json(s);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/office-settings', async (req, res) => {
  const { officeId, openTime, closeTime, maxQueue, isActive, updatedBy } = req.body;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        `INSERT INTO office_settings (office_id, open_time, close_time, max_queue, is_active)
         VALUES ($1,$2,$3,$4,$5)
         ON CONFLICT (office_id) DO UPDATE
           SET open_time=$2, close_time=$3, max_queue=$4, is_active=$5, updated_at=NOW()
         RETURNING *`,
        [officeId, openTime || '08:00', closeTime || '17:00', maxQueue || 100, isActive !== false]
      );
      await logAudit('update_office_settings', updatedBy, `Upserted settings for ${officeId}`);
      res.json({ success: true, settings: rows[0] });
    } else {
      const existing = inMemory.officeSettings.find(s => s.office_id === officeId);
      if (existing) {
        if (openTime  !== undefined) existing.open_time  = openTime;
        if (closeTime !== undefined) existing.close_time = closeTime;
        if (maxQueue  !== undefined) existing.max_queue  = maxQueue;
        if (isActive  !== undefined) existing.is_active  = isActive;
        res.json({ success: true, settings: existing });
      } else {
        const entry = { id: ++inMemory.nextId, office_id: officeId, open_time: openTime || '08:00', close_time: closeTime || '17:00', max_queue: maxQueue || 100, is_active: isActive !== false };
        inMemory.officeSettings.push(entry);
        res.json({ success: true, settings: entry });
      }
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/office-settings/:officeId', async (req, res) => {
  const officeId = decodeURIComponent(req.params.officeId);
  const { openTime, closeTime, maxQueue, isActive, updatedBy } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        'UPDATE office_settings SET open_time=$1, close_time=$2, max_queue=$3, is_active=$4, updated_at=NOW() WHERE office_id=$5',
        [openTime, closeTime, maxQueue, isActive, officeId]
      );
      await logAudit('update_office_settings', updatedBy, `Updated settings for ${officeId}`);
    } else {
      const s = inMemory.officeSettings.find(s => s.office_id === officeId);
      if (s) {
        if (openTime  !== undefined) s.open_time  = openTime;
        if (closeTime !== undefined) s.close_time = closeTime;
        if (maxQueue  !== undefined) s.max_queue  = maxQueue;
        if (isActive  !== undefined) s.is_active  = isActive;
      }
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── STAFF USER: PASSWORD CHANGE & STATUS TOGGLE ───────────────────────────────

app.put('/api/web/users/:id/password', async (req, res) => {
  const { id } = req.params;
  const { currentPassword, newPassword, updatedBy } = req.body;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query('SELECT * FROM staff_users WHERE id=$1', [id]);
      if (rows.length === 0) return res.status(404).json({ error: 'User not found' });
      const match = await bcrypt.compare(currentPassword, rows[0].password_hash);
      if (!match) return res.status(401).json({ error: 'Current password incorrect' });
      const hash = await bcrypt.hash(newPassword, 10);
      await pool.query('UPDATE staff_users SET password_hash=$1 WHERE id=$2', [hash, id]);
      await logAudit('change_password', updatedBy, `Password changed for user ID ${id}`);
    } else {
      const u = inMemory.staffUsers.find(u => u.id === parseInt(id));
      if (!u) return res.status(404).json({ error: 'User not found' });
      if (u.password_hash !== currentPassword) return res.status(401).json({ error: 'Current password incorrect' });
      u.password_hash = newPassword;
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/users/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status, updatedBy } = req.body;
  try {
    if (dbAvailable) {
      await pool.query('UPDATE staff_users SET status=$1 WHERE id=$2', [status, id]);
      await logAudit('update_user_status', updatedBy, `Set user ${id} status to ${status}`);
    } else {
      const u = inMemory.staffUsers.find(u => u.id === parseInt(id));
      if (u) u.status = status;
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── NOTIFICATIONS: CREATE & DELETE ────────────────────────────────────────────

app.post('/api/web/notifications', async (req, res) => {
  const { title, message, type, userId, metadata } = req.body;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        'INSERT INTO notifications (title, message, type, user_id, metadata) VALUES ($1,$2,$3,$4,$5) RETURNING *',
        [title, message, type || 'system', userId || null, metadata ? JSON.stringify(metadata) : null]
      );
      io.emit('new_notification', rows[0]);
      res.json({ success: true, notification: rows[0] });
    } else {
      const n = { id: ++inMemory.nextId, title, message, type: type || 'system', is_read: false, user_id: userId || null, metadata: metadata || null, created_at: new Date().toISOString() };
      io.emit('new_notification', n);
      res.json({ success: true, notification: n });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/web/notifications/:id', async (req, res) => {
  const { id } = req.params;
  try {
    if (dbAvailable) {
      await pool.query('DELETE FROM notifications WHERE id=$1', [id]);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/web/notifications/user/:userId/all', async (req, res) => {
  const { userId } = req.params;
  try {
    if (dbAvailable) {
      await pool.query('DELETE FROM notifications WHERE user_id=$1', [userId]);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── DOCUMENT UPLOAD / DOWNLOAD ────────────────────────────────────────────────

const _uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(_uploadsDir)) fs.mkdirSync(_uploadsDir, { recursive: true });

let _upload = null;
try {
  const multer  = require('multer');
  const storage = multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, _uploadsDir),
    filename:    (_req, file,  cb) =>
      cb(null, `${Date.now()}-${file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_')}`),
  });
  _upload = multer({ storage, limits: { fileSize: 10 * 1024 * 1024 } });
} catch (_) {}

app.post('/api/web/documents/upload', (req, res) => {
  if (!_upload) return res.status(503).json({ error: 'Run: npm install multer  inside lib/web/backend_server' });
  _upload.single('file')(req, res, async (err) => {
    if (err) return res.status(400).json({ error: err.message });
    const { appointmentId, citizenName, documentType, uploadedBy } = req.body;
    const filePath     = req.file ? `uploads/${req.file.filename}` : null;
    const documentName = req.file ? req.file.originalname : (req.body.documentName || 'unknown');
    try {
      if (dbAvailable) {
        const { rows } = await pool.query(
          'INSERT INTO documents (appointment_id, citizen_name, document_name, document_type, file_path) VALUES ($1,$2,$3,$4,$5) RETURNING *',
          [appointmentId || null, citizenName, documentName, documentType || 'General', filePath]
        );
        await logAudit('upload_document', uploadedBy, `Uploaded ${documentName} for ${citizenName}`);
        res.json({ success: true, document: rows[0] });
      } else {
        const doc = { id: ++inMemory.nextId, appointment_id: appointmentId || null, citizen_name: citizenName, document_name: documentName, document_type: documentType || 'General', file_path: filePath, status: 'pending', uploaded_at: new Date().toISOString() };
        inMemory.documents.push(doc);
        res.json({ success: true, document: doc });
      }
    } catch (dbErr) {
      res.status(500).json({ error: dbErr.message });
    }
  });
});

app.get('/api/web/documents/download/:id', async (req, res) => {
  const { id } = req.params;
  try {
    if (!dbAvailable) return res.status(404).json({ error: 'Not available in memory mode' });
    const { rows } = await pool.query('SELECT * FROM documents WHERE id=$1', [id]);
    if (rows.length === 0 || !rows[0].file_path) return res.status(404).json({ error: 'File not found' });
    const filePath = path.join(__dirname, rows[0].file_path);
    if (!fs.existsSync(filePath)) return res.status(404).json({ error: 'File not on disk' });
    res.download(filePath, rows[0].document_name);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── APPOINTMENTS: SEARCH ──────────────────────────────────────────────────────

app.get('/api/web/appointments/search', async (req, res) => {
  const { q } = req.query;
  if (!q) return res.json([]);
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        `SELECT * FROM appointments WHERE citizen_nic ILIKE $1 OR citizen_name ILIKE $1 ORDER BY created_at DESC LIMIT 50`,
        [`%${q}%`]
      );
      res.json(rows);
    } else {
      const lower = q.toLowerCase();
      res.json(inMemory.appointments.filter(a =>
        (a.citizen_nic  || '').toLowerCase().includes(lower) ||
        (a.citizen_name || '').toLowerCase().includes(lower)
      ));
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── ANALYTICS ─────────────────────────────────────────────────────────────────

app.get('/api/web/analytics/overview', async (req, res) => {
  try {
    if (dbAvailable) {
      const [daily, weekly, monthly, byService, byOffice, byStatus] = await Promise.all([
        pool.query("SELECT COUNT(*) FROM appointments WHERE date = CURRENT_DATE"),
        pool.query("SELECT COUNT(*) FROM appointments WHERE date >= CURRENT_DATE - INTERVAL '7 days'"),
        pool.query("SELECT COUNT(*) FROM appointments WHERE date >= CURRENT_DATE - INTERVAL '30 days'"),
        pool.query("SELECT service, COUNT(*) as count FROM appointments GROUP BY service ORDER BY count DESC LIMIT 10"),
        pool.query("SELECT office,  COUNT(*) as count FROM appointments GROUP BY office  ORDER BY count DESC"),
        pool.query("SELECT status,  COUNT(*) as count FROM appointments GROUP BY status"),
      ]);
      res.json({
        dailyAppointments:   parseInt(daily.rows[0].count),
        weeklyAppointments:  parseInt(weekly.rows[0].count),
        monthlyAppointments: parseInt(monthly.rows[0].count),
        topServices: byService.rows,
        byOffice:    byOffice.rows,
        byStatus:    byStatus.rows,
      });
    } else {
      res.json({
        dailyAppointments:   0,
        weeklyAppointments:  0,
        monthlyAppointments: inMemory.appointments.length,
        topServices: [],
        byOffice:    [],
        byStatus:    [],
      });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/web/analytics/queue-trends', async (req, res) => {
  const { officeId, days = '7' } = req.query;
  const numDays = Math.min(Math.abs(parseInt(days) || 7), 90);
  try {
    if (dbAvailable) {
      if (officeId) {
        const { rows } = await pool.query(
          `SELECT DATE(created_at) as date,
                  COUNT(*) as total,
                  SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END) as completed,
                  SUM(CASE WHEN is_priority=true   THEN 1 ELSE 0 END) as priority
           FROM queue_entries
           WHERE office_id=$1 AND created_at >= CURRENT_DATE - ($2 || ' days')::INTERVAL
           GROUP BY DATE(created_at) ORDER BY date`,
          [officeId, numDays]
        );
        res.json(rows);
      } else {
        const { rows } = await pool.query(
          `SELECT DATE(created_at) as date,
                  COUNT(*) as total,
                  SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END) as completed,
                  SUM(CASE WHEN is_priority=true   THEN 1 ELSE 0 END) as priority
           FROM queue_entries
           WHERE created_at >= CURRENT_DATE - ($1 || ' days')::INTERVAL
           GROUP BY DATE(created_at) ORDER BY date`,
          [numDays]
        );
        res.json(rows);
      }
    } else {
      res.json([]);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/web/analytics/service-performance', async (req, res) => {
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(`
        SELECT service,
          COUNT(*) as total,
          SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END) as completed,
          ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - served_at)) / 60)::numeric, 1) as avg_service_minutes
        FROM queue_entries
        WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY service ORDER BY total DESC
      `);
      res.json(rows);
    } else {
      res.json([]);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/web/analytics/staff-performance', async (req, res) => {
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(`
        SELECT user_name,
          COUNT(*) as actions,
          COUNT(CASE WHEN action='complete_service' THEN 1 END) as services_completed,
          COUNT(CASE WHEN action='call_next'        THEN 1 END) as calls_made,
          MAX(created_at) as last_action
        FROM audit_logs
        WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
          AND user_name IS NOT NULL
        GROUP BY user_name ORDER BY actions DESC
      `);
      res.json(rows);
    } else {
      res.json([]);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── STRIPE WEBHOOK ────────────────────────────────────────────────────────────
// Note: For signature verification in production, move this route BEFORE
// app.use(express.json()) and add STRIPE_WEBHOOK_SECRET to .env

app.post('/api/stripe/webhook', async (req, res) => {
  const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;
  const appointmentId  = req.body?.data?.object?.metadata?.appointmentId;
  const eventType      = req.body?.type;

  if (!endpointSecret) {
    if (eventType === 'payment_intent.succeeded' && appointmentId && dbAvailable) {
      await pool.query("UPDATE appointments SET payment_status='paid' WHERE id=$1", [appointmentId]).catch(() => {});
      io.emit('payment_confirmed', { appointmentId });
    }
    return res.json({ received: true });
  }

  try {
    const event = stripe.webhooks.constructEvent(
      JSON.stringify(req.body), req.headers['stripe-signature'], endpointSecret
    );
    if (event.type === 'payment_intent.succeeded') {
      const pi  = event.data.object;
      const aid = pi.metadata?.appointmentId;
      if (aid && dbAvailable) {
        await pool.query("UPDATE appointments SET payment_status='paid' WHERE id=$1", [aid]).catch(() => {});
      }
      io.emit('payment_confirmed', { appointmentId: aid, transactionId: pi.id });
    }
    res.json({ received: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ── START ─────────────────────────────────────────────────────────────────────

const PORT = parseInt(process.env.PORT || '3000');
initDatabase().then(() => {
  server.listen(PORT, () => {
    console.log(`\n🚀 QueueNova Backend running on port ${PORT}`);
    console.log(`📦 Database: ${dbAvailable ? 'PostgreSQL' : 'in-memory fallback'}`);
    console.log(`\n  ── Auth ──────────────────────────────────────────`);
    console.log(`  POST   /api/web/auth/login`);
    console.log(`\n  ── Dashboard ─────────────────────────────────────`);
    console.log(`  GET    /api/web/dashboard/stats`);
    console.log(`  GET    /api/web/dashboard/activity`);
    console.log(`\n  ── Queue ─────────────────────────────────────────`);
    console.log(`  GET    /api/web/queue/:officeId`);
    console.log(`  POST   /api/web/queue                  (add entry)`);
    console.log(`  DELETE /api/web/queue/:token           (cancel)`);
    console.log(`  GET    /api/web/queue/stats/:officeId`);
    console.log(`  POST   /api/web/queue/call-next`);
    console.log(`  POST   /api/web/queue/complete`);
    console.log(`  PUT    /api/web/queue/:token/counter`);
    console.log(`  GET    /api/web/queue/emergency/:officeId`);
    console.log(`  POST   /api/web/queue/emergency        (add entry)`);
    console.log(`  POST   /api/web/queue/emergency/process`);
    console.log(`\n  ── Staff Users ───────────────────────────────────`);
    console.log(`  GET    /api/web/users`);
    console.log(`  POST   /api/web/users`);
    console.log(`  PUT    /api/web/users/:id`);
    console.log(`  DELETE /api/web/users/:id`);
    console.log(`  PUT    /api/web/users/:id/password`);
    console.log(`  PUT    /api/web/users/:id/status`);
    console.log(`\n  ── Documents ─────────────────────────────────────`);
    console.log(`  GET    /api/web/documents`);
    console.log(`  PATCH  /api/web/documents/:id/approve`);
    console.log(`  PATCH  /api/web/documents/:id/reject`);
    console.log(`  POST   /api/web/documents/upload`);
    console.log(`  GET    /api/web/documents/download/:id`);
    console.log(`\n  ── Appointments ──────────────────────────────────`);
    console.log(`  GET    /api/web/appointments`);
    console.log(`  POST   /api/web/appointments`);
    console.log(`  PUT    /api/web/appointments/:id/status`);
    console.log(`  GET    /api/web/appointments/search?q=`);
    console.log(`\n  ── Office Settings ───────────────────────────────`);
    console.log(`  GET    /api/web/office-settings`);
    console.log(`  GET    /api/web/office-settings/:officeId`);
    console.log(`  POST   /api/web/office-settings`);
    console.log(`  PUT    /api/web/office-settings/:officeId`);
    console.log(`\n  ── Notifications ─────────────────────────────────`);
    console.log(`  GET    /api/web/notifications/:userId`);
    console.log(`  PUT    /api/web/notifications/:id/read`);
    console.log(`  POST   /api/web/notifications`);
    console.log(`  DELETE /api/web/notifications/:id`);
    console.log(`  DELETE /api/web/notifications/user/:userId/all`);
    console.log(`\n  ── Analytics ─────────────────────────────────────`);
    console.log(`  GET    /api/web/analytics/overview`);
    console.log(`  GET    /api/web/analytics/queue-trends`);
    console.log(`  GET    /api/web/analytics/service-performance`);
    console.log(`  GET    /api/web/analytics/staff-performance`);
    console.log(`\n  ── System ────────────────────────────────────────`);
    console.log(`  GET    /api/web/audit-logs`);
    console.log(`  GET    /api/web/system/health`);
    console.log(`\n  ── Payments ──────────────────────────────────────`);
    console.log(`  POST   /api/create-payment-intent`);
    console.log(`  POST   /api/process-payment`);
    console.log(`  POST   /api/stripe/webhook`);
    console.log(`\n  ── Chat (Socket.IO) ──────────────────────────────`);
    console.log(`  GET    /api/chats/:userId`);
    console.log(`  GET    /api/messages/:chatId`);
    console.log(`  POST   /api/chats/start`);
    console.log(`  WS     socket.io  (register / send_message / mark_read)\n`);
  });
});
