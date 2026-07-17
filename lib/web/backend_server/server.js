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
const os   = require('os');
const zlib = require('zlib');
const PDFDocument = require('pdfkit');

// ── Stripe ────────────────────────────────────────────────────────────────────
const stripe = Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_REPLACE_WITH_YOUR_STRIPE_SECRET_KEY');

// ── Firebase Admin (push notifications) ────────────────────────────────────────
// Requires a service account key: Firebase Console → Project settings →
// Service accounts → Generate new private key. Save the JSON file and point
// FIREBASE_SERVICE_ACCOUNT_PATH at it in .env.
const admin = require('firebase-admin');
let firebaseApp = null;
try {
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './firebase-service-account.json';
  const serviceAccount = require(path.resolve(serviceAccountPath));
  firebaseApp = admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
} catch (err) {
  console.warn('Firebase Admin not initialized (push notifications disabled):', err.message);
}

// ── Express + Socket.IO ───────────────────────────────────────────────────────
const app = express();
const server = http.createServer(app);
const io = socketIo(server, { cors: { origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'] } });

app.use(cors());
app.use(express.json({ limit: '10mb' })); // raised to fit base64 profile photo uploads

// ── System Health tracking (request rate + CPU sampling) ───────────────────────
const _requestTimestamps = [];
app.use((req, res, next) => {
  _requestTimestamps.push(Date.now());
  next();
});
function getRequestsPerMinute() {
  const oneMinuteAgo = Date.now() - 60000;
  while (_requestTimestamps.length && _requestTimestamps[0] < oneMinuteAgo) _requestTimestamps.shift();
  return _requestTimestamps.length;
}

// CPU % between consecutive health checks (not a lifetime average), so it
// reflects how busy the process has been recently rather than diluting a
// single startup spike forever.
let _lastCpuSample = { time: Date.now(), usage: process.cpuUsage() };
function sampleCpuPercent() {
  const now = Date.now();
  const usage = process.cpuUsage();
  const elapsedMs = now - _lastCpuSample.time;
  let percent = 0;
  if (elapsedMs > 0) {
    const deltaMs = (usage.user - _lastCpuSample.usage.user + usage.system - _lastCpuSample.usage.system) / 1000;
    percent = Math.min(100, (deltaMs / elapsedMs) * 100);
  }
  _lastCpuSample = { time: now, usage };
  return percent;
}

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
  feedback: [],
  staffPreferences: {},
  auditLogs: [],
  officeSettings: [
    { id: 1,  office_id: 'Divisional Secretariat - Colombo',      open_time: '08:00', close_time: '17:00', max_queue: 100, is_active: true },
    { id: 2,  office_id: 'Divisional Secretariat - Kandy',        open_time: '08:00', close_time: '17:00', max_queue: 100, is_active: true },
    { id: 3,  office_id: 'Divisional Secretariat - Galle',        open_time: '08:00', close_time: '17:00', max_queue: 100, is_active: true },
    { id: 4,  office_id: 'Divisional Secretariat - Kurunegala',   open_time: '08:00', close_time: '17:00', max_queue: 100, is_active: true },
    { id: 5,  office_id: 'RMV - Werahera',                        open_time: '09:00', close_time: '16:00', max_queue: 80,  is_active: true },
    { id: 6,  office_id: 'RMV - Kiribathgoda',                    open_time: '09:00', close_time: '16:00', max_queue: 80,  is_active: true },
    { id: 7,  office_id: 'RMV - Kandy',                           open_time: '09:00', close_time: '16:00', max_queue: 80,  is_active: true },
    { id: 8,  office_id: 'Passport Office - Battaramulla',        open_time: '08:30', close_time: '16:30', max_queue: 120, is_active: true },
    { id: 9,  office_id: 'Passport Office - Kandy',                open_time: '08:30', close_time: '16:30', max_queue: 120, is_active: true },
    { id: 10, office_id: 'Department of Registration - Colombo',  open_time: '08:00', close_time: '16:00', max_queue: 60,  is_active: true },
    { id: 11, office_id: 'NIC Service Center - Colombo',           open_time: '08:00', close_time: '16:00', max_queue: 90,  is_active: true },
    { id: 12, office_id: 'NIC Service Center - Kandy',             open_time: '08:00', close_time: '16:00', max_queue: 90,  is_active: true },
    { id: 13, office_id: 'Immigration Department - Battaramulla',  open_time: '08:30', close_time: '16:30', max_queue: 100, is_active: true },
    { id: 14, office_id: 'Land Registry Office - Colombo',         open_time: '08:00', close_time: '16:00', max_queue: 60,  is_active: true },
    { id: 15, office_id: 'Land Registry Office - Kandy',           open_time: '08:00', close_time: '16:00', max_queue: 60,  is_active: true },
    { id: 16, office_id: 'Municipal Council - Colombo',            open_time: '08:00', close_time: '16:00', max_queue: 70,  is_active: true },
    { id: 17, office_id: 'Municipal Council - Kandy',              open_time: '08:00', close_time: '16:00', max_queue: 70,  is_active: true },
    { id: 18, office_id: 'Registrar General Department - Colombo', open_time: '08:00', close_time: '16:00', max_queue: 60,  is_active: true },
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
        phone         VARCHAR(20),
        status        VARCHAR(50)  DEFAULT 'Active',
        last_active   TIMESTAMP    DEFAULT NOW(),
        created_at    TIMESTAMP    DEFAULT NOW()
      )
    `);
    // phone added after the initial table shape shipped — My Profile
    // (web_profile.dart) shows/edits it but there was nowhere to persist it.
    await pool.query(`ALTER TABLE staff_users ADD COLUMN IF NOT EXISTS phone VARCHAR(20)`).catch(() => {});
    // photo_url stores the profile photo as a base64 data string directly
    // (same approach the citizen app uses for its Firestore photoURL field),
    // so it persists across logout/login and needs no separate file storage.
    await pool.query(`ALTER TABLE staff_users ADD COLUMN IF NOT EXISTS photo_url TEXT`).catch(() => {});

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
    // documents columns added after the initial table shape shipped —
    // citizen_nic (Document Management shows/needs it), rejection_reason
    // and reviewed_by_name (persist what the reject/approve dialogs already
    // collect — reviewed_by is an INTEGER FK to staff_users, not a display
    // name, so this is a separate text column), and shared_with (cross-
    // department sharing).
    await pool.query(`ALTER TABLE documents ADD COLUMN IF NOT EXISTS citizen_nic VARCHAR(20)`).catch(() => {});
    await pool.query(`ALTER TABLE documents ADD COLUMN IF NOT EXISTS rejection_reason TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE documents ADD COLUMN IF NOT EXISTS reviewed_by_name VARCHAR(255)`).catch(() => {});
    await pool.query(`ALTER TABLE documents ADD COLUMN IF NOT EXISTS shared_with TEXT[] DEFAULT '{}'`).catch(() => {});
    // Staff Performance screen — attribute a completed queue entry / rating
    // to the officer who handled it, and give each staff member a real
    // (persisted) service target instead of a hardcoded UI number.
    await pool.query(`ALTER TABLE queue_entries ADD COLUMN IF NOT EXISTS served_by VARCHAR(255)`).catch(() => {});
    await pool.query(`ALTER TABLE feedback ADD COLUMN IF NOT EXISTS served_by VARCHAR(255)`).catch(() => {});
    await pool.query(`ALTER TABLE staff_users ADD COLUMN IF NOT EXISTS target INTEGER DEFAULT 100`).catch(() => {});
    // One-time backfill so staff seeded before the `target` column existed
    // get the same role-based defaults a fresh install would seed.
    await pool.query(`UPDATE staff_users SET target = 150 WHERE role = 'Queue Manager'      AND target = 100`).catch(() => {});
    await pool.query(`UPDATE staff_users SET target = 140 WHERE role = 'Service Officer'    AND target = 100`).catch(() => {});
    await pool.query(`UPDATE staff_users SET target = 120 WHERE role = 'Department Manager' AND target = 100`).catch(() => {});

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

    await pool.query(`
      CREATE TABLE IF NOT EXISTS staff_preferences (
        staff_id   INTEGER PRIMARY KEY REFERENCES staff_users(id),
        settings   JSONB     NOT NULL DEFAULT '{}',
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS feedback (
        id           SERIAL PRIMARY KEY,
        citizen_name VARCHAR(255),
        citizen_nic  VARCHAR(20),
        service      VARCHAR(255),
        rating       INTEGER      NOT NULL,
        comment      TEXT,
        created_at   TIMESTAMP    DEFAULT NOW()
      )
    `);
    // reply/replied_by/replied_at added after the initial table shape
    // shipped — lets an officer reply to a citizen's feedback from the
    // Dashboard's Avg. Satisfaction stat card.
    await pool.query(`ALTER TABLE feedback ADD COLUMN IF NOT EXISTS reply TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE feedback ADD COLUMN IF NOT EXISTS replied_by VARCHAR(255)`).catch(() => {});
    await pool.query(`ALTER TABLE feedback ADD COLUMN IF NOT EXISTS replied_at TIMESTAMP`).catch(() => {});

    await pool.query(`
      CREATE TABLE IF NOT EXISTS system_settings (
        id         INTEGER PRIMARY KEY DEFAULT 1,
        settings   JSONB     NOT NULL DEFAULT '{}',
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS security_settings (
        id         INTEGER PRIMARY KEY DEFAULT 1,
        settings   JSONB     NOT NULL DEFAULT '{}',
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
    await pool.query(`ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS ip_address VARCHAR(64)`).catch(() => {});

    await pool.query(`
      CREATE TABLE IF NOT EXISTS departments (
        id         SERIAL PRIMARY KEY,
        name       VARCHAR(255) NOT NULL,
        code       VARCHAR(50)  NOT NULL,
        type       VARCHAR(100),
        active     BOOLEAN      DEFAULT TRUE,
        created_at TIMESTAMP    DEFAULT NOW()
      )
    `);

    // Seed default departments if empty (matches the list the System
    // Settings screen used to hardcode before it was wired to the DB)
    const { rowCount: deptCount } = await pool.query('SELECT 1 FROM departments LIMIT 1');
    if (deptCount === 0) {
      const defaultDepartments = [
        { name: 'Divisional Secretariat - Colombo',     code: 'DSC', type: 'Divisional Secretariat' },
        { name: 'RMV - Werahera',                        code: 'RMV', type: 'RMV' },
        { name: 'Passport Office - Battaramulla',        code: 'PO',  type: 'Passport Office' },
        { name: 'Department of Registration',            code: 'DOR', type: 'Registration' },
        { name: 'NIC Service Center - Colombo',           code: 'NIC', type: 'NIC Center' },
      ];
      for (const d of defaultDepartments) {
        await pool.query(
          'INSERT INTO departments (name, code, type, active) VALUES ($1,$2,$3,TRUE)',
          [d.name, d.code, d.type]
        );
      }
    }

    await pool.query(`
      CREATE TABLE IF NOT EXISTS services (
        id            SERIAL PRIMARY KEY,
        name          VARCHAR(255) NOT NULL,
        name_key      VARCHAR(100),
        desc_key      VARCHAR(100),
        req_key       VARCHAR(100),
        category      VARCHAR(50),
        icon          VARCHAR(50),
        time_minutes  INTEGER       DEFAULT 0,
        fee           DECIMAL(10,2) DEFAULT 0,
        popular       BOOLEAN       DEFAULT FALSE,
        created_at    TIMESTAMP     DEFAULT NOW()
      )
    `);

    // Seed default services if empty (matches the list the citizen app's
    // All Services / Book Appointment screens used to hardcode before they
    // were wired to the DB)
    const { rowCount: svcCount } = await pool.query('SELECT 1 FROM services LIMIT 1');
    if (svcCount === 0) {
      const defaultServices = [
        { name: 'Passport Renewal',         nameKey: 'svc_passport_renewal_name',     descKey: 'svc_passport_renewal_desc',     reqKey: 'svc_passport_renewal_req',     category: 'Passport',    icon: 'airplane_ticket',        time: 30, fee: 5000, popular: true },
        { name: 'New Passport Application', nameKey: 'svc_new_passport_name',         descKey: 'svc_new_passport_desc',         reqKey: 'svc_new_passport_req',         category: 'Passport',    icon: 'airplane_ticket',        time: 45, fee: 8000, popular: false },
        { name: 'National ID Card',         nameKey: 'svc_national_id_name',          descKey: 'svc_national_id_desc',          reqKey: 'svc_national_id_req',          category: 'NIC',         icon: 'badge',                  time: 20, fee: 500,  popular: true },
        { name: 'NIC Replacement',          nameKey: 'svc_nic_replacement_name',      descKey: 'svc_nic_replacement_desc',      reqKey: 'svc_nic_replacement_req',      category: 'NIC',         icon: 'badge',                  time: 15, fee: 1000, popular: false },
        { name: 'Driving License',          nameKey: 'svc_driving_license_name',      descKey: 'svc_driving_license_desc',      reqKey: 'svc_driving_license_req',      category: 'License',     icon: 'directions_car',         time: 60, fee: 3000, popular: true },
        { name: 'License Renewal',          nameKey: 'svc_license_renewal_name',      descKey: 'svc_license_renewal_desc',      reqKey: 'svc_license_renewal_req',      category: 'License',     icon: 'directions_car',         time: 25, fee: 1500, popular: false },
        { name: 'Birth Certificate',        nameKey: 'svc_birth_certificate_name',    descKey: 'svc_birth_certificate_desc',    reqKey: 'svc_birth_certificate_req',    category: 'Certificate', icon: 'celebration',            time: 10, fee: 200,  popular: true },
        { name: 'Marriage Certificate',     nameKey: 'svc_marriage_certificate_name', descKey: 'svc_marriage_certificate_desc', reqKey: 'svc_marriage_certificate_req', category: 'Certificate', icon: 'favorite',               time: 15, fee: 300,  popular: false },
        { name: 'Death Certificate',        nameKey: 'svc_death_certificate_name',    descKey: 'svc_death_certificate_desc',    reqKey: 'svc_death_certificate_req',    category: 'Certificate', icon: 'sentiment_dissatisfied', time: 10, fee: 200,  popular: false },
        { name: 'Police Clearance',         nameKey: 'svc_police_clearance_name',     descKey: 'svc_police_clearance_desc',     reqKey: 'svc_police_clearance_req',     category: 'Other',       icon: 'gavel',                  time: 40, fee: 1000, popular: true },
        { name: 'Visa Services',            nameKey: 'svc_visa_services_name',        descKey: 'svc_visa_services_desc',        reqKey: 'svc_visa_services_req',        category: 'Other',       icon: 'flight',                 time: 50, fee: 4000, popular: false },
        { name: 'Land Registration',        nameKey: 'svc_land_registration_name',    descKey: 'svc_land_registration_desc',    reqKey: 'svc_land_registration_req',    category: 'Other',       icon: 'description',            time: 90, fee: 5000, popular: false },
      ];
      for (const s of defaultServices) {
        await pool.query(
          'INSERT INTO services (name, name_key, desc_key, req_key, category, icon, time_minutes, fee, popular) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)',
          [s.name, s.nameKey, s.descKey, s.reqKey, s.category, s.icon, s.time, s.fee, s.popular]
        );
      }
      console.log('✅ Seeded default services');
    }

    await pool.query(`
      CREATE TABLE IF NOT EXISTS system_health_checks (
        id                   SERIAL PRIMARY KEY,
        db_healthy           BOOLEAN,
        db_response_ms       INTEGER,
        notification_healthy BOOLEAN,
        api_response_ms      INTEGER,
        cpu_percent          NUMERIC(5,1),
        memory_used_mb       INTEGER,
        memory_total_mb      INTEGER,
        disk_used_percent    NUMERIC(5,1),
        active_sessions      INTEGER,
        requests_per_min     INTEGER,
        checked_at           TIMESTAMP DEFAULT NOW()
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS reports (
        id           SERIAL PRIMARY KEY,
        report_type  VARCHAR(20)  NOT NULL,
        report_date  DATE         NOT NULL,
        file_name    VARCHAR(255) NOT NULL,
        file_path    VARCHAR(500) NOT NULL,
        generated_by VARCHAR(255),
        generated_at TIMESTAMP    DEFAULT NOW()
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS backups (
        id           SERIAL PRIMARY KEY,
        file_name    VARCHAR(255) NOT NULL,
        file_path    VARCHAR(500) NOT NULL,
        size_bytes   BIGINT       NOT NULL DEFAULT 0,
        backup_type  VARCHAR(20)  NOT NULL DEFAULT 'Full',
        status       VARCHAR(20)  NOT NULL DEFAULT 'Success',
        created_by   VARCHAR(255),
        created_at   TIMESTAMP    DEFAULT NOW()
      )
    `);

    // Seed default staff users if table is empty
    const { rowCount } = await pool.query('SELECT 1 FROM staff_users LIMIT 1');
    if (rowCount === 0) {
      const defaultUsers = [
        { name: 'Admin User',        email: 'admin@queuenova.gov.lk',    password: 'admin123',      role: 'Administrator',      target: 100 },
        { name: 'Queue Officer',     email: 'queue@queuenova.gov.lk',    password: 'queue123',      role: 'Queue Manager',      target: 150 },
        { name: 'Service Officer',   email: 'service@queuenova.gov.lk',  password: 'service123',    role: 'Service Officer',    target: 140 },
        { name: 'Reception Officer', email: 'reception@queuenova.gov.lk',password: 'reception123',  role: 'Reception',          target: 100 },
        { name: 'Dept. Manager',     email: 'manager@queuenova.gov.lk',  password: 'manager123',    role: 'Department Manager', target: 120 },
      ];
      for (const u of defaultUsers) {
        const hash = await bcrypt.hash(u.password, 10);
        await pool.query(
          'INSERT INTO staff_users (name, email, password_hash, role, target) VALUES ($1, $2, $3, $4, $5)',
          [u.name, u.email, hash, u.role, u.target]
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

// Escapes user-supplied text before it's interpolated into the public
// /qr/:appointmentId HTML page below — citizen_name/service/office etc. are
// attacker-controllable strings, so this is required to avoid stored XSS.
function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Helper: log audit action to DB or in-memory. Every call site (login,
// call-next, check-in, book/approve/reject, feedback, user management,
// etc.) already routes through here, so emitting the live-update event
// from this one place guarantees Recent Activity refreshes instantly for
// every audited action — not just the handful that also happen to emit
// their own domain-specific event (queue_update, appointment_update, ...).
async function logAudit(action, userName, details, ipAddress = null) {
  try {
    if (dbAvailable) {
      await pool.query(
        'INSERT INTO audit_logs (action, user_name, details, ip_address) VALUES ($1, $2, $3, $4)',
        [action, userName || 'System', details || '', ipAddress]
      );
    } else {
      inMemory.auditLogs.unshift({ id: ++inMemory.nextId, action, user_name: userName, details, ip_address: ipAddress, created_at: new Date().toISOString() });
    }
    io.emit('activity_logged', { action, userName, details });
  } catch (_) {}
}

// ── WEB AUTH ──────────────────────────────────────────────────────────────────

app.post('/api/web/auth/login', async (req, res) => {
  const { email, password } = req.body;
  const clientIp = req.ip;
  try {
    if (dbAvailable) {
      const security = await getSecuritySettings();

      // IP whitelisting is scoped to login only (matches its placement
      // under "Login Security") — an already-open session is never kicked
      // by a later whitelist change, only new logins are gated.
      if (security.enableIpWhitelisting && Array.isArray(security.whitelistedIPs) && security.whitelistedIPs.length > 0) {
        if (!security.whitelistedIPs.includes(clientIp)) {
          await logAudit('login_blocked_ip', email, 'Blocked login from non-whitelisted IP', clientIp);
          return res.status(403).json({ error: 'Access denied from this IP address' });
        }
      }

      // Lockout is derived from recent failed_login audit entries in a
      // rolling 15-minute window, so it always self-resets and never
      // requires a manual unlock.
      const maxAttempts = security.maxLoginAttempts || 5;
      const { rows: recentFails } = await pool.query(
        `SELECT COUNT(*) FROM audit_logs WHERE action='failed_login' AND user_name=$1 AND created_at >= NOW() - INTERVAL '15 minutes'`,
        [email]
      );
      if (parseInt(recentFails[0].count, 10) >= maxAttempts) {
        return res.status(429).json({ error: 'Too many failed login attempts. Please try again in a few minutes.' });
      }

      const { rows } = await pool.query(
        'SELECT * FROM staff_users WHERE email = $1 AND status != $2',
        [email, 'Deleted']
      );
      const user = rows[0];
      const match = user ? await bcrypt.compare(password, user.password_hash) : false;
      if (!user || !match) {
        if (security.logFailedLogins !== false) {
          await logAudit('failed_login', email, 'Invalid credentials', clientIp);
        }
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      // Update last_active
      await pool.query('UPDATE staff_users SET last_active = NOW() WHERE id = $1', [user.id]);
      await logAudit('login', user.name, `Login from web dashboard`, clientIp);

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
      const [
        queueCount, docPending, appointmentsToday, totalAppointments, distinctCitizens, completed,
        avgSatisfaction, avgResponseToday, avgResponseAllTime, checkInsToday,
      ] = await Promise.all([
        pool.query("SELECT COUNT(*) FROM queue_entries WHERE status = 'waiting'"),
        pool.query("SELECT COUNT(*) FROM documents WHERE status = 'pending'"),
        pool.query("SELECT COUNT(*) FROM appointments WHERE date = CURRENT_DATE"),
        pool.query('SELECT COUNT(*) FROM appointments'),
        pool.query('SELECT COUNT(DISTINCT citizen_nic) FROM appointments WHERE citizen_nic IS NOT NULL'),
        pool.query("SELECT COUNT(*) FROM appointments WHERE status = 'completed'"),
        pool.query('SELECT AVG(rating) FROM feedback'),
        pool.query("SELECT AVG(EXTRACT(EPOCH FROM (served_at - created_at)) / 60) FROM queue_entries WHERE served_at IS NOT NULL AND created_at::date = CURRENT_DATE"),
        pool.query('SELECT AVG(EXTRACT(EPOCH FROM (served_at - created_at)) / 60) FROM queue_entries WHERE served_at IS NOT NULL'),
        pool.query('SELECT COUNT(*) FROM queue_entries WHERE created_at::date = CURRENT_DATE'),
      ]);
      const avgResponseMinutes = avgResponseToday.rows[0].avg !== null
        ? parseFloat(avgResponseToday.rows[0].avg)
        : (avgResponseAllTime.rows[0].avg !== null ? parseFloat(avgResponseAllTime.rows[0].avg) : null);
      res.json({
        activeQueues: parseInt(queueCount.rows[0].count),
        pendingDocuments: parseInt(docPending.rows[0].count),
        todaysAppointments: parseInt(appointmentsToday.rows[0].count),
        totalServices: parseInt(totalAppointments.rows[0].count),
        totalCitizens: parseInt(distinctCitizens.rows[0].count),
        completedServices: parseInt(completed.rows[0].count),
        avgSatisfaction: avgSatisfaction.rows[0].avg !== null ? parseFloat(avgSatisfaction.rows[0].avg) : null,
        avgResponseMinutes,
        todaysCheckIns: parseInt(checkInsToday.rows[0].count),
        activeUsers: activeUsers.size,
      });
    } else {
      const today = new Date().toDateString();
      res.json({
        activeQueues: inMemory.queueEntries.filter(q => q.status === 'waiting').length,
        pendingDocuments: inMemory.documents.filter(d => d.status === 'pending').length,
        todaysAppointments: inMemory.appointments.filter(a => new Date(a.date).toDateString() === today).length,
        totalServices: inMemory.appointments.length,
        totalCitizens: new Set(inMemory.appointments.map(a => a.citizen_nic).filter(Boolean)).size,
        completedServices: inMemory.appointments.filter(a => a.status === 'completed').length,
        avgSatisfaction: inMemory.feedback.length
          ? inMemory.feedback.reduce((sum, f) => sum + f.rating, 0) / inMemory.feedback.length
          : null,
        avgResponseMinutes: null,
        todaysCheckIns: inMemory.queueEntries.filter(q => new Date(q.created_at).toDateString() === today).length,
        activeUsers: activeUsers.size,
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
        "UPDATE queue_entries SET status = 'serving', served_at = NOW(), served_by = $2 WHERE id = $1",
        [token.id, officerName || null]
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

// Approves or rejects a citizen's self-requested priority-queue upgrade
// (the mobile app's "Request Priority Queue" toggle sends a staff_notification
// asking for this; the Queue Manager's Approve/Reject action calls this).
app.patch('/api/web/queue/:token/priority', async (req, res) => {
  const { token } = req.params;
  const { approve, officerName } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        "UPDATE queue_entries SET is_priority = $1 WHERE token = $2 AND status = 'waiting'",
        [!!approve, token]
      );
    } else {
      const entry = inMemory.queueEntries.find(q => q.token === token && q.status === 'waiting');
      if (entry) entry.is_priority = !!approve;
    }
    await logAudit(
      approve ? 'approve_priority' : 'reject_priority',
      officerName,
      `${approve ? 'Approved' : 'Rejected'} priority request for token ${token}`
    );
    io.emit('queue_update', { priorityToken: token, approved: !!approve });
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
        'SELECT id, name, email, role, phone, photo_url, status, last_active FROM staff_users ORDER BY created_at ASC'
      );
      res.json(rows);
    } else {
      res.json(inMemory.staffUsers.map(u => ({ id: u.id, name: u.name, email: u.email, role: u.role, phone: u.phone || null, photo_url: u.photo_url || null, status: u.status, last_active: u.last_active })));
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/users', async (req, res) => {
  const { name, email, password, role, createdBy } = req.body;
  try {
    if (dbAvailable) {
      // Only enforce the Password Policy when an explicit password was
      // typed — the "leave blank" fallback below is a system-generated
      // temporary password the officer is expected to change on first use.
      if (password) {
        const security = await getSecuritySettings();
        const policyError = validatePasswordPolicy(password, security);
        if (policyError) return res.status(400).json({ error: policyError });
      }
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
  const { name, email, role, phone, updatedBy } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        'UPDATE staff_users SET name = $1, email = $2, role = $3, phone = COALESCE($4, phone) WHERE id = $5',
        [name, email, role, phone, id]
      );
      await logAudit('update_user', updatedBy, `Updated user ${email}`);
    } else {
      const u = inMemory.staffUsers.find(u => u.id === parseInt(id));
      if (u) { u.name = name; u.email = email; u.role = role; if (phone) u.phone = phone; }
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/users/:id/photo', async (req, res) => {
  const { id } = req.params;
  const { photoBase64, updatedBy } = req.body;
  try {
    if (dbAvailable) {
      await pool.query('UPDATE staff_users SET photo_url = $1 WHERE id = $2', [photoBase64 || null, id]);
      await logAudit('update_user_photo', updatedBy, `Updated profile photo`);
    } else {
      const u = inMemory.staffUsers.find(u => u.id === parseInt(id));
      if (u) u.photo_url = photoBase64 || null;
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
        "UPDATE documents SET status = 'approved', reviewed_at = NOW(), reviewed_by_name = $1 WHERE id = $2",
        [reviewedBy || null, id]
      );
      await logAudit('approve_document', reviewedBy, `Approved document #${id}`);
    } else {
      const d = inMemory.documents.find(d => d.id === parseInt(id));
      if (d) { d.status = 'approved'; d.reviewed_by_name = reviewedBy || null; }
    }
    io.emit('document_update', { id, status: 'approved' });
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
        "UPDATE documents SET status = 'rejected', reviewed_at = NOW(), reviewed_by_name = $1, rejection_reason = $2 WHERE id = $3",
        [reviewedBy || null, reason || null, id]
      );
      await logAudit('reject_document', reviewedBy, `Rejected document #${id}: ${reason || ''}`);
    } else {
      const d = inMemory.documents.find(d => d.id === parseInt(id));
      if (d) { d.status = 'rejected'; d.reviewed_by_name = reviewedBy || null; d.rejection_reason = reason || null; }
    }
    io.emit('document_update', { id, status: 'rejected' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.patch('/api/web/documents/:id/share', async (req, res) => {
  const { id } = req.params;
  const { departments, sharedBy } = req.body;
  const list = Array.isArray(departments) ? departments : [];
  try {
    if (dbAvailable) {
      await pool.query('UPDATE documents SET shared_with = $1 WHERE id = $2', [list, id]);
    } else {
      const d = inMemory.documents.find(d => d.id === parseInt(id));
      if (d) d.shared_with = list;
    }
    await logAudit('share_document', sharedBy, `Shared document #${id} with ${list.join(', ')}`);
    io.emit('document_update', { id, sharedWith: list });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── APPOINTMENTS (mirror from Firestore) ──────────────────────────────────────

app.get('/api/web/appointments', async (req, res) => {
  try {
    if (dbAvailable) {
      // date is cast to a plain 'YYYY-MM-DD' string (TO_CHAR) rather than
      // returned as-is — node-postgres otherwise serializes the DATE column
      // through a timezone-aware JS Date, which can shift it a calendar day
      // off from the intended date once converted to UTC for JSON.
      const { rows } = await pool.query(
        `SELECT id, citizen_nic, citizen_name, service, office, TO_CHAR(date, 'YYYY-MM-DD') AS date,
                time, token, status, payment_status, fee_amount, payment_method, qr_data, created_at
         FROM appointments ORDER BY created_at DESC LIMIT 100`
      );
      res.json(rows);
    } else {
      res.json(inMemory.appointments);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/appointments', async (req, res) => {
  // 'status' was previously not read from the body nor included in the
  // INSERT column list, so EXCLUDED.status always fell back to the column
  // default ('scheduled') — the citizen app's real status ('Confirmed',
  // 'Cancelled', etc.) was silently discarded on every booking/re-sync.
  const { id, citizen_nic, citizen_name, service, office, date, time, token, status, payment_status, fee_amount, payment_method, qr_data } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        `INSERT INTO appointments (id, citizen_nic, citizen_name, service, office, date, time, token, status, payment_status, fee_amount, payment_method, qr_data)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
         ON CONFLICT (id) DO UPDATE SET
           status         = EXCLUDED.status,
           payment_status = EXCLUDED.payment_status,
           qr_data        = COALESCE(EXCLUDED.qr_data, appointments.qr_data)`,
        [id, citizen_nic, citizen_name, service, office, date, time, token, status || 'Confirmed', payment_status, fee_amount, payment_method, qr_data || null]
      );
    } else {
      inMemory.appointments.push(req.body);
    }
    await logAudit('book_appointment', citizen_name, `Booked ${service} at ${office} (token ${token})`);
    io.emit('appointment_update', { id, office });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Public, read-only appointment details page — no auth, and deliberately no
// check-in/call-token actions. This is what the citizen's QR code links to,
// so anyone scanning it with an ordinary camera app sees a formatted details
// view instead of raw JSON. Only Reception's own authenticated dashboard
// (web_reception.dart) can actually check someone in.
app.get('/qr/:appointmentId', async (req, res) => {
  const { appointmentId } = req.params;
  res.set('Content-Type', 'text/html');
  try {
    let appt = null;
    if (dbAvailable) {
      const { rows } = await pool.query('SELECT * FROM appointments WHERE id = $1', [appointmentId]);
      appt = rows[0] || null;
    } else {
      appt = inMemory.appointments.find(a => a.id === appointmentId) || null;
    }

    if (!appt) {
      res.status(404).send(`<!DOCTYPE html><html><head><meta charset="utf-8"><title>Not Found</title></head>
        <body style="font-family:sans-serif;text-align:center;padding:60px;color:#666;">
          <h2>Appointment not found</h2>
        </body></html>`);
      return;
    }

    const dateStr = appt.date ? new Date(appt.date).toDateString() : (appt.date || '—');
    const feeStr = appt.fee_amount != null ? `Rs. ${appt.fee_amount}` : '—';

    res.send(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>QueueNova Appointment</title>
  <style>
    body { font-family: -apple-system, "Segoe UI", Roboto, sans-serif; background: #F5F7FA; margin: 0; padding: 16px; }
    .card { max-width: 420px; margin: 24px auto; background: #fff; border-radius: 20px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); overflow: hidden; }
    .header { background: linear-gradient(135deg, #1A56DB, #0E3A9B); color: #fff; padding: 24px; text-align: center; }
    .header h1 { margin: 0; font-size: 18px; font-weight: 600; }
    .token { font-size: 32px; font-weight: bold; margin-top: 8px; letter-spacing: 1px; }
    .body { padding: 8px 24px 20px; }
    .row { display: flex; justify-content: space-between; gap: 12px; padding: 10px 0; border-bottom: 1px solid #eee; }
    .row:last-child { border-bottom: none; }
    .label { color: #888; font-size: 13px; white-space: nowrap; }
    .value { font-weight: 600; font-size: 14px; text-align: right; }
    .footer { padding: 14px 24px; font-size: 11px; color: #999; text-align: center; background: #FAFAFA; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>${escapeHtml(appt.service)}</h1>
      <div class="token">${escapeHtml(appt.token)}</div>
    </div>
    <div class="body">
      <div class="row"><span class="label">Citizen</span><span class="value">${escapeHtml(appt.citizen_name)}</span></div>
      <div class="row"><span class="label">Office</span><span class="value">${escapeHtml(appt.office)}</span></div>
      <div class="row"><span class="label">Date</span><span class="value">${escapeHtml(dateStr)}</span></div>
      <div class="row"><span class="label">Time</span><span class="value">${escapeHtml(appt.time)}</span></div>
      <div class="row"><span class="label">Status</span><span class="value">${escapeHtml(appt.status)}</span></div>
      <div class="row"><span class="label">Payment</span><span class="value">${escapeHtml(appt.payment_status)} (${escapeHtml(feeStr)})</span></div>
    </div>
    <div class="footer">Read-only. Check-in is handled by office staff only.</div>
  </div>
</body>
</html>`);
  } catch (err) {
    res.status(500).send('<h2>Something went wrong</h2>');
  }
});

app.post('/api/web/feedback', async (req, res) => {
  const { citizenName, citizenNic, service, rating, comment } = req.body;
  try {
    if (dbAvailable) {
      // Attribute this rating to whichever staff member most recently
      // served this citizen for this service, so Staff Performance can
      // show real per-officer satisfaction instead of a fabricated number.
      let servedBy = null;
      if (citizenNic) {
        const match = await pool.query(
          `SELECT served_by FROM queue_entries
           WHERE citizen_nic = $1 AND service = $2 AND served_by IS NOT NULL
           ORDER BY COALESCE(completed_at, served_at) DESC LIMIT 1`,
          [citizenNic, service]
        );
        if (match.rows.length) servedBy = match.rows[0].served_by;
      }
      await pool.query(
        `INSERT INTO feedback (citizen_name, citizen_nic, service, rating, comment, served_by) VALUES ($1,$2,$3,$4,$5,$6)`,
        [citizenName, citizenNic || null, service, rating, comment || null, servedBy]
      );
    } else {
      inMemory.feedback.push({
        id: ++inMemory.nextId,
        citizen_name: citizenName,
        citizen_nic: citizenNic || null,
        service,
        rating,
        comment: comment || null,
        created_at: new Date().toISOString(),
      });
    }
    await logAudit('submit_feedback', citizenName, `Rated ${service} ${rating}/5`);
    io.emit('feedback_update', { citizenName, rating });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Full feedback list for staff — powers the Dashboard's "Avg. Satisfaction"
// stat card (tap to view individual ratings/comments and reply).
app.get('/api/web/feedback', async (req, res) => {
  try {
    if (!dbAvailable) return res.json([]);
    const { rows } = await pool.query('SELECT * FROM feedback ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Officer reply to a citizen's feedback. The citizen-side push (Firestore
// `notifications`) is sent by the caller (web dashboard), same pattern as
// service request approve/reject notifying the citizen — this endpoint only
// persists the reply.
app.put('/api/web/feedback/:id/reply', async (req, res) => {
  const { id } = req.params;
  const { reply, repliedBy } = req.body;
  try {
    if (!dbAvailable) return res.status(503).json({ error: 'Database not connected' });
    const { rows } = await pool.query(
      'UPDATE feedback SET reply = $1, replied_by = $2, replied_at = NOW() WHERE id = $3 RETURNING *',
      [reply, repliedBy || null, id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Feedback not found' });
    await logAudit('reply_feedback', repliedBy, `Replied to feedback #${id}`);
    res.json({ success: true, feedback: rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// This citizen's own average rating across all feedback they've submitted —
// used by the mobile app's home screen "Rating" stat card (as opposed to
// the office/staff-wide averages the other feedback queries compute).
app.get('/api/web/feedback/citizen/:nic', async (req, res) => {
  const nic = decodeURIComponent(req.params.nic);
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        'SELECT AVG(rating) as avg_rating, COUNT(*) as count FROM feedback WHERE citizen_nic = $1',
        [nic]
      );
      res.json({
        avgRating: rows[0].avg_rating !== null ? parseFloat(rows[0].avg_rating) : null,
        count: parseInt(rows[0].count, 10),
      });
    } else {
      const entries = inMemory.feedback.filter(f => f.citizen_nic === nic);
      const avg = entries.length ? entries.reduce((sum, f) => sum + f.rating, 0) / entries.length : null;
      res.json({ avgRating: avg, count: entries.length });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/appointments/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status, payment_status, updatedBy } = req.body;
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
    const changes = [status ? `status=${status}` : null, payment_status ? `payment=${payment_status}` : null].filter(Boolean).join(', ');
    await logAudit('update_appointment_status', updatedBy, `Updated appointment #${id} (${changes})`);
    io.emit('appointment_update', { id, status, payment_status });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── SERVICE REQUESTS (Service Processing screen — appointments with their
// attached documents grouped into one application to approve/reject) ─────────

app.get('/api/web/service-requests', async (req, res) => {
  try {
    if (!dbAvailable) return res.json([]);
    const { rows } = await pool.query(
      `SELECT a.id, a.citizen_nic, a.citizen_name, a.service, TO_CHAR(a.date, 'YYYY-MM-DD') AS date,
              a.payment_status, a.fee_amount,
              json_agg(json_build_object(
                'id', d.id,
                'document_name', d.document_name,
                'file_path', d.file_path,
                'status', d.status,
                'rejection_reason', d.rejection_reason,
                'reviewed_by_name', d.reviewed_by_name,
                'reviewed_at', d.reviewed_at
              ) ORDER BY d.uploaded_at) AS documents
       FROM appointments a
       JOIN documents d ON d.appointment_id = a.id
       GROUP BY a.id
       ORDER BY MAX(d.uploaded_at) DESC`
    );
    const requests = rows.map(r => {
      const docs = r.documents || [];
      const anyRejected = docs.some(d => d.status === 'rejected');
      const allApproved = docs.length > 0 && docs.every(d => d.status === 'approved');
      const anyApproved = docs.some(d => d.status === 'approved');
      const status = anyRejected ? 'rejected' : allApproved ? 'approved' : anyApproved ? 'processing' : 'pending';
      const reviewed = docs.filter(d => d.reviewed_at).sort((a, b) => new Date(b.reviewed_at) - new Date(a.reviewed_at));
      const latest = reviewed[0];
      const rejectedDoc = [...docs].reverse().find(d => d.status === 'rejected' && d.rejection_reason);
      return {
        id: r.id,
        citizen_nic: r.citizen_nic,
        citizen_name: r.citizen_name,
        service: r.service,
        date: r.date,
        payment_status: r.payment_status,
        fee_amount: r.fee_amount,
        status,
        comments: status === 'rejected'
          ? (rejectedDoc?.rejection_reason || '')
          : (status === 'approved' ? 'Application approved successfully' : ''),
        processed_by: latest?.reviewed_by_name || '',
        processed_at: latest?.reviewed_at || '',
        documents: docs.map(d => d.document_name),
        doc_ids: docs.map(d => d.id),
      };
    });
    res.json(requests);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.patch('/api/web/service-requests/:appointmentId/approve', async (req, res) => {
  const { appointmentId } = req.params;
  const { reviewedBy } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        "UPDATE documents SET status = 'approved', reviewed_at = NOW(), reviewed_by_name = $1 WHERE appointment_id = $2",
        [reviewedBy || null, appointmentId]
      );
      await logAudit('approve_service_request', reviewedBy, `Approved application #${appointmentId}`);
    }
    io.emit('document_update', { appointmentId, status: 'approved' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.patch('/api/web/service-requests/:appointmentId/reject', async (req, res) => {
  const { appointmentId } = req.params;
  const { reviewedBy, reason } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        "UPDATE documents SET status = 'rejected', reviewed_at = NOW(), reviewed_by_name = $1, rejection_reason = $2 WHERE appointment_id = $3",
        [reviewedBy || null, reason || null, appointmentId]
      );
      await logAudit('reject_service_request', reviewedBy, `Rejected application #${appointmentId}: ${reason || ''}`);
    }
    io.emit('document_update', { appointmentId, status: 'rejected' });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Additive: adds the given department(s) to whatever each document is
// already shared with, rather than replacing the list — the Service
// Processing share sheet shares one department per tap.
app.patch('/api/web/service-requests/:appointmentId/share', async (req, res) => {
  const { appointmentId } = req.params;
  const { departments, sharedBy } = req.body;
  const list = Array.isArray(departments) ? departments : [];
  try {
    if (dbAvailable && list.length > 0) {
      await pool.query(
        `UPDATE documents
         SET shared_with = (SELECT array_agg(DISTINCT elem) FROM unnest(shared_with || $1::text[]) AS elem)
         WHERE appointment_id = $2`,
        [list, appointmentId]
      );
      await logAudit('share_service_request', sharedBy, `Shared application #${appointmentId} documents with ${list.join(', ')}`);
    }
    io.emit('document_update', { appointmentId, sharedWith: list });
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

// ── SMS (Twilio) ──────────────────────────────────────────────────────────────
// Requires TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER in .env
// (sign up at https://www.twilio.com/console)

const twilioClient = process.env.TWILIO_ACCOUNT_SID
  ? require('twilio')(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN)
  : null;

async function sendSms(phoneNumber, message) {
  if (!twilioClient) throw new Error('Twilio credentials are missing. Set TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN / TWILIO_FROM_NUMBER in .env.');
  if (!process.env.TWILIO_FROM_NUMBER) throw new Error('TWILIO_FROM_NUMBER is missing in .env.');
  return twilioClient.messages.create({
    to: phoneNumber,
    from: process.env.TWILIO_FROM_NUMBER,
    body: message,
  });
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

// ── Push Notifications (Firebase Cloud Messaging) ──────────────────────────────

app.post('/api/push/send', async (req, res) => {
  const { tokens, title, body } = req.body;
  const tokenList = Array.isArray(tokens) ? tokens : (tokens ? [tokens] : []);
  if (tokenList.length === 0 || !title || !body) {
    return res.status(400).json({ error: 'tokens (array or string), title and body are required' });
  }
  if (!firebaseApp) {
    return res.status(500).json({ success: false, error: 'Firebase Admin is not configured on the server (missing service account).' });
  }
  try {
    const result = await admin.messaging().sendEachForMulticast({
      tokens: tokenList,
      notification: { title, body },
    });
    res.json({ success: true, successCount: result.successCount, failureCount: result.failureCount });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── AUDIT LOGS ────────────────────────────────────────────────────────────────

app.get('/api/web/audit-logs', async (req, res) => {
  const limit = parseInt(req.query.limit || '100');
  try {
    if (dbAvailable) {
      // Best-effort role lookup: audit_logs.user_name is free text (an
      // email for failed logins, a display name for most other actions),
      // so this only resolves when it happens to match a real staff name —
      // callers should treat a missing role as "Unknown", not an error.
      const { rows } = await pool.query(
        `SELECT al.*, su.role AS user_role
         FROM audit_logs al
         LEFT JOIN staff_users su ON su.name = al.user_name
         ORDER BY al.created_at DESC LIMIT $1`,
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
  const requestStart = Date.now();
  const memUsage = process.memoryUsage();
  const memoryUsedMb = Math.round(memUsage.rss / (1024 * 1024));
  const memoryTotalMb = Math.round(os.totalmem() / (1024 * 1024));

  let diskUsedPercent = null;
  try {
    const stat = fs.statfsSync(__dirname);
    diskUsedPercent = Math.round((1 - stat.bavail / stat.blocks) * 1000) / 10;
  } catch (_) {}

  let dbHealthy = false;
  let dbResponseMs = null;
  if (dbAvailable) {
    const dbStart = Date.now();
    try {
      await pool.query('SELECT 1');
      dbHealthy = true;
      dbResponseMs = Date.now() - dbStart;
    } catch (_) {}
  }

  const notificationHealthy = firebaseApp !== null;
  const cpuPercent = Math.round(sampleCpuPercent() * 10) / 10;
  const activeSessions = activeUsers.size;
  const requestsPerMin = getRequestsPerMinute();
  const apiResponseMs = Date.now() - requestStart;

  // Per-service uptime %, each computed from the same recorded booleans —
  // "API Gateway" and "QR Service" run in this same process with nothing
  // separate to fail, so a written row (this endpoint having responded)
  // counts as them being up for that check, same honest self-reporting
  // caveat every service here shares: only checks performed since this
  // table started recording are reflected.
  let uptimes = {};
  if (dbAvailable) {
    try {
      const { rows } = await pool.query(`
        SELECT
          AVG(CASE WHEN checked_at >= NOW() - INTERVAL '24 hours' THEN db_healthy::int END) AS db_24h,
          AVG(CASE WHEN checked_at >= NOW() - INTERVAL '24 hours' THEN notification_healthy::int END) AS notif_24h,
          AVG(CASE WHEN checked_at >= NOW() - INTERVAL '24 hours' THEN (disk_used_percent < 90)::int END) AS disk_24h,
          COUNT(*) FILTER (WHERE checked_at >= NOW() - INTERVAL '24 hours') AS n_24h,
          AVG(CASE WHEN checked_at >= NOW() - INTERVAL '24 hours' THEN (db_healthy AND notification_healthy AND disk_used_percent < 90)::int END) AS overall_24h,
          AVG(CASE WHEN checked_at >= NOW() - INTERVAL '30 days'  THEN (db_healthy AND notification_healthy AND disk_used_percent < 90)::int END) AS overall_30d
        FROM system_health_checks
      `);
      const r = rows[0];
      const pct = (v) => v !== null ? Math.round(parseFloat(v) * 1000) / 10 : null;
      uptimes = {
        db: pct(r.db_24h),
        api: parseInt(r.n_24h, 10) > 0 ? 100 : null,
        notif: pct(r.notif_24h),
        disk: pct(r.disk_24h),
        overall24h: pct(r.overall_24h),
        overall30d: pct(r.overall_30d),
      };

      await pool.query(
        `INSERT INTO system_health_checks
           (db_healthy, db_response_ms, notification_healthy, api_response_ms,
            cpu_percent, memory_used_mb, memory_total_mb, disk_used_percent,
            active_sessions, requests_per_min)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
        [dbHealthy, dbResponseMs, notificationHealthy, apiResponseMs,
         cpuPercent, memoryUsedMb, memoryTotalMb, diskUsedPercent,
         activeSessions, requestsPerMin]
      );
    } catch (_) {}
  }

  const diskHealthy = diskUsedPercent === null || diskUsedPercent < 90;
  const overallHealthy = dbHealthy && notificationHealthy && diskHealthy;
  res.json({
    status: overallHealthy ? 'Operational' : 'Degraded',
    database: dbAvailable ? 'connected' : 'in-memory',
    uptimeSeconds: Math.round(process.uptime()),
    overallUptime24h: uptimes.overall24h,
    overallUptime30d: uptimes.overall30d,
    cpuPercent,
    memoryUsedMb,
    memoryTotalMb,
    diskUsedPercent,
    activeSessions,
    requestsPerMin,
    services: [
      { name: 'Database Server', healthy: dbHealthy, responseMs: dbResponseMs, uptime24h: uptimes.db },
      { name: 'API Gateway', healthy: true, responseMs: apiResponseMs, uptime24h: uptimes.api },
      { name: 'Notification Service', healthy: notificationHealthy, responseMs: notificationHealthy ? apiResponseMs : null, uptime24h: uptimes.notif },
      { name: 'QR Service', healthy: true, responseMs: apiResponseMs, uptime24h: uptimes.api },
      { name: 'File Storage', healthy: diskHealthy, responseMs: null, uptime24h: uptimes.disk },
    ],
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

// ── SERVICES CATALOG (citizen app's All Services / Book Appointment screens) ──

app.get('/api/services', async (req, res) => {
  try {
    if (!dbAvailable) return res.json([]);
    const { rows } = await pool.query('SELECT * FROM services ORDER BY id');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
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

// Live "where do I stand right now" lookup for the citizen app's Home screen.
// Position is counted using the same ordering /api/web/queue/call-next
// actually serves in (priority first, then first-come-first-served).
app.get('/api/queue/position/:nic', async (req, res) => {
  const nic = decodeURIComponent(req.params.nic);
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        "SELECT * FROM queue_entries WHERE citizen_nic=$1 AND status IN ('waiting','serving') ORDER BY created_at DESC LIMIT 1",
        [nic]
      );
      if (rows.length === 0) return res.json({ found: false });
      const entry = rows[0];
      if (entry.status === 'serving') {
        return res.json({ found: true, token: entry.token, officeId: entry.office_id, service: entry.service, status: 'serving', position: 0, isPriority: !!entry.is_priority });
      }
      const aheadRes = await pool.query(
        `SELECT COUNT(*) FROM queue_entries
         WHERE office_id=$1 AND status='waiting'
           AND (is_priority > $2 OR (is_priority = $2 AND created_at < $3))`,
        [entry.office_id, entry.is_priority, entry.created_at]
      );
      res.json({
        found: true,
        token: entry.token,
        officeId: entry.office_id,
        service: entry.service,
        status: 'waiting',
        position: parseInt(aheadRes.rows[0].count, 10),
        isPriority: !!entry.is_priority,
      });
    } else {
      const entry = inMemory.queueEntries.find(q => q.citizen_nic === nic && (q.status === 'waiting' || q.status === 'serving'));
      if (!entry) return res.json({ found: false });
      if (entry.status === 'serving') {
        return res.json({ found: true, token: entry.token, officeId: entry.office_id, service: entry.service, status: 'serving', position: 0, isPriority: !!entry.is_priority });
      }
      const ahead = inMemory.queueEntries.filter(q =>
        q.office_id === entry.office_id && q.status === 'waiting' &&
        (q.is_priority > entry.is_priority || (q.is_priority === entry.is_priority && q.created_at < entry.created_at))
      ).length;
      res.json({ found: true, token: entry.token, officeId: entry.office_id, service: entry.service, status: 'waiting', position: ahead, isPriority: !!entry.is_priority });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// All of a citizen's currently active (waiting/serving) queue entries — unlike
// /api/queue/position/:nic above, which only returns the single most recent
// one. Needed when a citizen has more than one appointment checked in at
// once, so they can pick which one an emergency-priority request is for.
app.get('/api/queue/positions/:nic', async (req, res) => {
  const nic = decodeURIComponent(req.params.nic);
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        "SELECT * FROM queue_entries WHERE citizen_nic=$1 AND status IN ('waiting','serving') ORDER BY created_at DESC",
        [nic]
      );
      res.json({
        positions: rows.map(entry => ({
          token: entry.token,
          officeId: entry.office_id,
          service: entry.service,
          status: entry.status,
          isPriority: !!entry.is_priority,
        })),
      });
    } else {
      const entries = inMemory.queueEntries.filter(
        q => q.citizen_nic === nic && (q.status === 'waiting' || q.status === 'serving')
      );
      res.json({
        positions: entries.map(entry => ({
          token: entry.token,
          officeId: entry.office_id,
          service: entry.service,
          status: entry.status,
          isPriority: !!entry.is_priority,
        })),
      });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Single queue entry by token, any status (unlike the endpoints above this
// isn't limited to waiting/serving) — used to backfill the approved/rejected
// outcome onto old priority-request notifications that predate the
// `resolution` field, by checking whether is_priority ended up true or false.
app.get('/api/queue/entry/:token', async (req, res) => {
  const token = decodeURIComponent(req.params.token);
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        'SELECT * FROM queue_entries WHERE token=$1 ORDER BY created_at DESC LIMIT 1',
        [token]
      );
      if (rows.length === 0) return res.json({ found: false });
      const entry = rows[0];
      res.json({ found: true, token: entry.token, status: entry.status, isPriority: !!entry.is_priority });
    } else {
      const entry = inMemory.queueEntries.find(q => q.token === token);
      if (!entry) return res.json({ found: false });
      res.json({ found: true, token: entry.token, status: entry.status, isPriority: !!entry.is_priority });
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
// Tracks every open socket per user (activeUsers above only keeps the most
// recent one) purely so "Limit Concurrent Sessions" has something real to
// enforce, without changing activeUsers' single-socket shape that chat and
// online-status already depend on.
const userSessions = new Map();
const chatMessages = new Map();
const chatConversations = new Map();

io.on('connection', (socket) => {
  socket.on('register', async (data) => {
    const { userId, role, name } = data;
    activeUsers.set(userId, { socketId: socket.id, role, name });

    let sessions = userSessions.get(userId);
    if (!sessions) { sessions = new Set(); userSessions.set(userId, sessions); }
    sessions.add(socket.id);

    const security = await getSecuritySettings();
    if (security.limitConcurrentSessions) {
      const maxSessions = security.maxConcurrentSessions || 3;
      while (sessions.size > maxSessions) {
        const oldestSocketId = sessions.values().next().value;
        if (oldestSocketId === socket.id) break;
        sessions.delete(oldestSocketId);
        io.to(oldestSocketId).emit('session_kicked', { reason: 'max_concurrent_sessions' });
        io.sockets.sockets.get(oldestSocketId)?.disconnect(true);
      }
    }

    socket.emit('unread_count', { count: 0 });
    io.emit('active_users_changed', { count: activeUsers.size });
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
    for (const sessions of userSessions.values()) {
      sessions.delete(socket.id);
    }
    io.emit('active_users_changed', { count: activeUsers.size });
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
      const [waiting, serving, completed, emergency, currentServing, avgWait] = await Promise.all([
        pool.query("SELECT COUNT(*) FROM queue_entries   WHERE office_id=$1 AND status='waiting'",                               [officeId]),
        pool.query("SELECT COUNT(*) FROM queue_entries   WHERE office_id=$1 AND status='serving'",                               [officeId]),
        pool.query("SELECT COUNT(*) FROM queue_entries   WHERE office_id=$1 AND status='completed' AND DATE(completed_at)=CURRENT_DATE", [officeId]),
        pool.query("SELECT COUNT(*) FROM emergency_queue WHERE office_id=$1 AND status='priority'",                              [officeId]),
        pool.query("SELECT token FROM queue_entries WHERE office_id=$1 AND status='serving' ORDER BY served_at DESC LIMIT 1",    [officeId]),
        pool.query("SELECT AVG(EXTRACT(EPOCH FROM (served_at - created_at)) / 60) FROM queue_entries WHERE office_id=$1 AND served_at IS NOT NULL AND created_at::date = CURRENT_DATE", [officeId]),
      ]);
      const waitingCount = parseInt(waiting.rows[0].count);
      res.json({
        waiting:            waitingCount,
        serving:            parseInt(serving.rows[0].count),
        completedToday:     parseInt(completed.rows[0].count),
        emergency:          parseInt(emergency.rows[0].count),
        currentServingToken: currentServing.rows[0]?.token || null,
        avgWaitMinutes:     avgWait.rows[0].avg !== null ? parseFloat(avgWait.rows[0].avg) : null,
        crowdLevel:         waitingCount > 10 ? 'High' : waitingCount > 4 ? 'Medium' : 'Low',
      });
    } else {
      const waitingCount = inMemory.queueEntries.filter(q => q.office_id === officeId && q.status === 'waiting').length;
      res.json({
        waiting:        waitingCount,
        serving:        0,
        completedToday: 0,
        emergency:      inMemory.emergencyQueue.filter(e => e.office_id === officeId).length,
        currentServingToken: null,
        avgWaitMinutes: null,
        crowdLevel:     waitingCount > 10 ? 'High' : waitingCount > 4 ? 'Medium' : 'Low',
      });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// This citizen's own average wait time across all their completed queue
// entries (any office) — used by the mobile app's home screen "Avg Wait"
// stat card, as opposed to the office-wide averages above.
app.get('/api/web/queue/stats/citizen/:nic', async (req, res) => {
  const nic = decodeURIComponent(req.params.nic);
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        "SELECT AVG(EXTRACT(EPOCH FROM (served_at - created_at)) / 60) as avg_wait FROM queue_entries WHERE citizen_nic=$1 AND served_at IS NOT NULL",
        [nic]
      );
      res.json({
        avgWaitMinutes: rows[0].avg_wait !== null ? parseFloat(rows[0].avg_wait) : null,
      });
    } else {
      res.json({ avgWaitMinutes: null });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Reception dashboard's own stat cards: active queue (waiting+serving),
// arrivals today (any queue_entries row created today — a row only ever
// gets created when someone is checked in or walks in), and walk-ins today
// specifically (tokens are prefixed 'W-' by Reception's Add Walk-in flow).
app.get('/api/web/reception/stats/:officeId', async (req, res) => {
  const officeId = decodeURIComponent(req.params.officeId);
  try {
    if (dbAvailable) {
      const [activeQueue, arrivalsToday, walkInsToday] = await Promise.all([
        pool.query("SELECT COUNT(*) FROM queue_entries WHERE office_id=$1 AND status IN ('waiting','serving')", [officeId]),
        pool.query("SELECT COUNT(*) FROM queue_entries WHERE office_id=$1 AND created_at::date=CURRENT_DATE", [officeId]),
        pool.query("SELECT COUNT(*) FROM queue_entries WHERE office_id=$1 AND created_at::date=CURRENT_DATE AND token LIKE 'W-%'", [officeId]),
      ]);
      res.json({
        activeQueue:   parseInt(activeQueue.rows[0].count, 10),
        arrivalsToday: parseInt(arrivalsToday.rows[0].count, 10),
        walkInsToday:  parseInt(walkInsToday.rows[0].count, 10),
      });
    } else {
      const today = new Date().toDateString();
      const officeEntries = inMemory.queueEntries.filter(q => q.office_id === officeId);
      res.json({
        activeQueue: officeEntries.filter(q => q.status === 'waiting' || q.status === 'serving').length,
        arrivalsToday: officeEntries.filter(q => new Date(q.created_at).toDateString() === today).length,
        walkInsToday: officeEntries.filter(q => new Date(q.created_at).toDateString() === today && q.token.startsWith('W-')).length,
      });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Calls a *specific* queue token (used by Reception's Walk-in "Call Next",
// which must call the walk-in at the front of the walk-in sub-list rather
// than whichever entry /api/web/queue/call-next would auto-pick for the
// whole office queue).
app.post('/api/web/queue/:token/serve', async (req, res) => {
  const { token } = req.params;
  const { officerName } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        "UPDATE queue_entries SET status='serving', served_at=NOW(), served_by=$2 WHERE token=$1",
        [token, officerName || null]
      );
    } else {
      const idx = inMemory.queueEntries.findIndex(q => q.token === token);
      if (idx !== -1) inMemory.queueEntries.splice(idx, 1);
    }
    await logAudit('call_next', officerName, `Called walk-in token ${token}`);
    io.emit('queue_update', { calledToken: token });
    res.json({ success: true });
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

// ── SYSTEM SETTINGS ────────────────────────────────────────────────────────────

app.get('/api/web/system-settings', async (req, res) => {
  try {
    if (!dbAvailable) return res.json({ settings: {} });
    const { rows } = await pool.query('SELECT * FROM system_settings WHERE id=1');
    res.json(rows.length ? rows[0] : { settings: {} });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/system-settings', async (req, res) => {
  const { settings, updatedBy } = req.body;
  try {
    if (!dbAvailable) return res.status(503).json({ error: 'Database not connected' });
    const { rows } = await pool.query(
      `INSERT INTO system_settings (id, settings) VALUES (1, $1)
       ON CONFLICT (id) DO UPDATE SET settings=$1, updated_at=NOW()
       RETURNING *`,
      [JSON.stringify(settings || {})]
    );
    await logAudit('update_system_settings', updatedBy, 'Updated system settings');
    res.json({ success: true, settings: rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── SECURITY SETTINGS ──────────────────────────────────────────────────────────

/// Reads the persisted security settings blob (empty object if nothing
/// saved yet or DB unavailable). Used both by the settings screen and by
/// the enforcement points below (password policy, login lockout, IP
/// whitelist).
async function getSecuritySettings() {
  if (!dbAvailable) return {};
  try {
    const { rows } = await pool.query('SELECT settings FROM security_settings WHERE id=1');
    return rows.length ? rows[0].settings : {};
  } catch (_) {
    return {};
  }
}

/// Checks a password against the persisted Password Policy. Returns an
/// error message string if it fails, or null if it passes.
function validatePasswordPolicy(password, security) {
  const minLen = security.minPasswordLength || 8;
  if (!password || password.length < minLen) return `Password must be at least ${minLen} characters long`;
  if (security.requireUppercase && !/[A-Z]/.test(password)) return 'Password must contain an uppercase letter';
  if (security.requireLowercase && !/[a-z]/.test(password)) return 'Password must contain a lowercase letter';
  if (security.requireNumbers && !/[0-9]/.test(password)) return 'Password must contain a number';
  if (security.requireSpecialChars && !/[^A-Za-z0-9]/.test(password)) return 'Password must contain a special character';
  return null;
}

app.get('/api/web/security-settings', async (req, res) => {
  try {
    if (!dbAvailable) return res.json({ settings: {} });
    const { rows } = await pool.query('SELECT * FROM security_settings WHERE id=1');
    res.json(rows.length ? rows[0] : { settings: {} });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/security-settings', async (req, res) => {
  const { settings, updatedBy } = req.body;
  try {
    if (!dbAvailable) return res.status(503).json({ error: 'Database not connected' });
    const { rows } = await pool.query(
      `INSERT INTO security_settings (id, settings) VALUES (1, $1)
       ON CONFLICT (id) DO UPDATE SET settings=$1, updated_at=NOW()
       RETURNING *`,
      [JSON.stringify(settings || {})]
    );
    await logAudit('update_security_settings', updatedBy, 'Updated security settings');
    res.json({ success: true, settings: rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── DEPARTMENTS ────────────────────────────────────────────────────────────────

app.get('/api/web/departments', async (req, res) => {
  try {
    if (!dbAvailable) return res.json([]);
    const { rows } = await pool.query('SELECT * FROM departments ORDER BY id');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/departments', async (req, res) => {
  const { name, code, type, createdBy } = req.body;
  try {
    if (!dbAvailable) return res.status(503).json({ error: 'Database not connected' });
    const { rows } = await pool.query(
      'INSERT INTO departments (name, code, type, active) VALUES ($1,$2,$3,TRUE) RETURNING *',
      [name, code, type]
    );
    await logAudit('add_department', createdBy, `Added department ${name}`);
    res.json({ success: true, department: rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/departments/:id/status', async (req, res) => {
  const { id } = req.params;
  const { active } = req.body;
  try {
    if (!dbAvailable) return res.status(503).json({ error: 'Database not connected' });
    await pool.query('UPDATE departments SET active=$1 WHERE id=$2', [active, id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/web/departments/:id', async (req, res) => {
  const { id } = req.params;
  const { deletedBy } = req.body;
  try {
    if (!dbAvailable) return res.status(503).json({ error: 'Database not connected' });
    await pool.query('DELETE FROM departments WHERE id=$1', [id]);
    await logAudit('delete_department', deletedBy, `Deleted department ${id}`);
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
      const security = await getSecuritySettings();
      const policyError = validatePasswordPolicy(newPassword, security);
      if (policyError) return res.status(400).json({ error: policyError });
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

// Per-officer Settings screen (web_settings_screen.dart) — one flexible
// JSONB blob rather than one column per setting, since the set of settings
// differs by role.
app.get('/api/web/users/:id/preferences', async (req, res) => {
  const { id } = req.params;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query('SELECT settings FROM staff_preferences WHERE staff_id=$1', [id]);
      res.json(rows.length ? rows[0].settings : {});
    } else {
      res.json(inMemory.staffPreferences[id] || {});
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/web/users/:id/preferences', async (req, res) => {
  const { id } = req.params;
  const { settings } = req.body;
  try {
    if (dbAvailable) {
      await pool.query(
        `INSERT INTO staff_preferences (staff_id, settings, updated_at) VALUES ($1, $2, NOW())
         ON CONFLICT (staff_id) DO UPDATE SET settings = $2, updated_at = NOW()`,
        [id, JSON.stringify(settings || {})]
      );
    } else {
      inMemory.staffPreferences[id] = settings || {};
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
    const { appointmentId, citizenName, citizenNic, documentType, uploadedBy } = req.body;
    const filePath     = req.file ? `uploads/${req.file.filename}` : null;
    const documentName = req.file ? req.file.originalname : (req.body.documentName || 'unknown');
    try {
      if (dbAvailable) {
        const { rows } = await pool.query(
          'INSERT INTO documents (appointment_id, citizen_name, citizen_nic, document_name, document_type, file_path) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
          [appointmentId || null, citizenName, citizenNic || null, documentName, documentType || 'General', filePath]
        );
        await logAudit('upload_document', uploadedBy, `Uploaded ${documentName} for ${citizenName}`);
        io.emit('document_update', { id: rows[0].id, status: 'pending' });
        res.json({ success: true, document: rows[0] });
      } else {
        const doc = { id: ++inMemory.nextId, appointment_id: appointmentId || null, citizen_name: citizenName, citizen_nic: citizenNic || null, document_name: documentName, document_type: documentType || 'General', file_path: filePath, status: 'pending', uploaded_at: new Date().toISOString() };
        inMemory.documents.push(doc);
        io.emit('document_update', { id: doc.id, status: 'pending' });
        res.json({ success: true, document: doc });
      }
    } catch (dbErr) {
      res.status(500).json({ error: dbErr.message });
    }
  });
});

app.delete('/api/web/documents/:id', async (req, res) => {
  const { id } = req.params;
  try {
    if (dbAvailable) {
      const { rows } = await pool.query('SELECT file_path FROM documents WHERE id=$1', [id]);
      await pool.query('DELETE FROM documents WHERE id=$1', [id]);
      if (rows[0]?.file_path) {
        fs.unlink(path.join(__dirname, rows[0].file_path), () => {});
      }
    } else {
      const idx = inMemory.documents.findIndex(d => d.id === parseInt(id));
      if (idx !== -1) inMemory.documents.splice(idx, 1);
    }
    io.emit('document_update', { id, deleted: true });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
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

// ── REPORTS ────────────────────────────────────────────────────────────────────

const _reportsDir = path.join(__dirname, 'reports');
if (!fs.existsSync(_reportsDir)) fs.mkdirSync(_reportsDir, { recursive: true });

app.get('/api/web/reports', async (req, res) => {
  try {
    if (!dbAvailable) return res.json([]);
    const { rows } = await pool.query('SELECT * FROM reports ORDER BY generated_at DESC LIMIT 20');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/reports/generate', async (req, res) => {
  const { reportType, date, generatedBy } = req.body;
  if (!reportType || !date) return res.status(400).json({ error: 'reportType and date are required' });
  try {
    if (!dbAvailable) return res.status(503).json({ error: 'Reports require the database to be connected' });

    const endDate = new Date(date);
    const startDate = new Date(endDate);
    if (reportType === 'Weekly') startDate.setDate(startDate.getDate() - 6);
    else if (reportType === 'Monthly') startDate.setDate(startDate.getDate() - 29);
    const startStr = startDate.toISOString().slice(0, 10);
    const endStr = endDate.toISOString().slice(0, 10);

    const [totals, byService, byStatus, satisfaction] = await Promise.all([
      pool.query(
        "SELECT COUNT(*) AS total, SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END) AS completed FROM queue_entries WHERE created_at::date BETWEEN $1 AND $2",
        [startStr, endStr]
      ),
      pool.query(
        "SELECT service, COUNT(*) AS count FROM queue_entries WHERE created_at::date BETWEEN $1 AND $2 GROUP BY service ORDER BY count DESC",
        [startStr, endStr]
      ),
      pool.query(
        "SELECT status, COUNT(*) AS count FROM queue_entries WHERE created_at::date BETWEEN $1 AND $2 GROUP BY status",
        [startStr, endStr]
      ),
      pool.query(
        "SELECT AVG(rating) AS avg, COUNT(*) AS count FROM feedback WHERE created_at::date BETWEEN $1 AND $2",
        [startStr, endStr]
      ),
    ]);

    const fileName = `${reportType}_Report_${endStr}_${Date.now()}.pdf`;
    const filePath = path.join(_reportsDir, fileName);

    const pdf = new PDFDocument({ margin: 50 });
    const writeStream = fs.createWriteStream(filePath);
    pdf.pipe(writeStream);

    pdf.fontSize(20).text('QueueNova Pulse — Service Report', { align: 'center' });
    pdf.moveDown();
    pdf.fontSize(12).text(`Report Type: ${reportType}`);
    pdf.text(`Period: ${startStr} to ${endStr}`);
    pdf.text(`Generated: ${new Date().toLocaleString()}`);
    pdf.moveDown();

    pdf.fontSize(14).text('Summary', { underline: true });
    pdf.fontSize(12);
    pdf.text(`Total Services: ${totals.rows[0].total}`);
    pdf.text(`Completed Services: ${totals.rows[0].completed}`);
    pdf.text(`Average Satisfaction: ${satisfaction.rows[0].avg ? parseFloat(satisfaction.rows[0].avg).toFixed(1) : 'N/A'} (${satisfaction.rows[0].count} ratings)`);
    pdf.moveDown();

    pdf.fontSize(14).text('By Service Type', { underline: true });
    pdf.fontSize(12);
    if (byService.rows.length === 0) pdf.text('No data for this period.');
    byService.rows.forEach(r => pdf.text(`${r.service}: ${r.count}`));
    pdf.moveDown();

    pdf.fontSize(14).text('By Status', { underline: true });
    pdf.fontSize(12);
    if (byStatus.rows.length === 0) pdf.text('No data for this period.');
    byStatus.rows.forEach(r => pdf.text(`${r.status}: ${r.count}`));

    pdf.end();
    await new Promise((resolve, reject) => {
      writeStream.on('finish', resolve);
      writeStream.on('error', reject);
    });

    const { rows } = await pool.query(
      `INSERT INTO reports (report_type, report_date, file_name, file_path, generated_by)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [reportType, endStr, fileName, `reports/${fileName}`, generatedBy || 'Admin']
    );
    await logAudit('generate_report', generatedBy, `Generated ${reportType} report for ${endStr}`);
    res.json({ success: true, report: rows[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/web/reports/download/:id', async (req, res) => {
  const { id } = req.params;
  try {
    if (!dbAvailable) return res.status(404).json({ error: 'Not available in memory mode' });
    const { rows } = await pool.query('SELECT * FROM reports WHERE id=$1', [id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Report not found' });
    const filePath = path.join(__dirname, rows[0].file_path);
    if (!fs.existsSync(filePath)) return res.status(404).json({ error: 'File not on disk' });
    res.download(filePath, rows[0].file_name);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── BACKUP & RESTORE ──────────────────────────────────────────────────────────

const _backupsDir = path.join(__dirname, 'backups');
if (!fs.existsSync(_backupsDir)) fs.mkdirSync(_backupsDir, { recursive: true });

// Every FK in this schema currently points at staff_users, so restoring it
// first (before any other table) satisfies every foreign key constraint
// without needing per-table dependency ordering.
const BACKUP_TABLE_PRIORITY = ['staff_users'];

/// Dumps every table in the `public` schema to a single gzipped JSON file,
/// writes it to disk, and records it in `backups`. Returns the new row.
async function createDatabaseBackup(createdBy) {
  const { rows: tableRows } = await pool.query(
    `SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename != 'backups'`
  );
  const dump = {};
  for (const { tablename } of tableRows) {
    const { rows } = await pool.query(`SELECT * FROM "${tablename}"`);
    dump[tablename] = rows;
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const fileName = `full_backup_${timestamp}.json.gz`;
  const filePath = path.join(_backupsDir, fileName);
  const gzipped = zlib.gzipSync(Buffer.from(JSON.stringify(dump)));
  fs.writeFileSync(filePath, gzipped);

  const { rows } = await pool.query(
    `INSERT INTO backups (file_name, file_path, size_bytes, backup_type, status, created_by)
     VALUES ($1,$2,$3,'Full','Success',$4) RETURNING *`,
    [fileName, `backups/${fileName}`, gzipped.length, createdBy || 'Admin']
  );
  return rows[0];
}

app.get('/api/web/backup', async (req, res) => {
  try {
    if (!dbAvailable) return res.json([]);
    const { rows } = await pool.query('SELECT * FROM backups ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/web/backup/create', async (req, res) => {
  const { createdBy } = req.body;
  try {
    if (!dbAvailable) return res.status(503).json({ error: 'Database not connected' });
    const backup = await createDatabaseBackup(createdBy);
    await logAudit('create_backup', createdBy, `Created backup ${backup.file_name}`);
    io.emit('activity_logged', { action: 'create_backup' });
    res.json({ success: true, backup });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/web/backup/download/:id', async (req, res) => {
  const { id } = req.params;
  try {
    if (!dbAvailable) return res.status(404).json({ error: 'Not available in memory mode' });
    const { rows } = await pool.query('SELECT * FROM backups WHERE id=$1', [id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Backup not found' });
    const filePath = path.join(__dirname, rows[0].file_path);
    if (!fs.existsSync(filePath)) return res.status(404).json({ error: 'File not on disk' });
    res.download(filePath, rows[0].file_name);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/web/backup/:id', async (req, res) => {
  const { id } = req.params;
  const { deletedBy } = req.body;
  try {
    if (!dbAvailable) return res.status(503).json({ error: 'Database not connected' });
    const { rows } = await pool.query('SELECT * FROM backups WHERE id=$1', [id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Backup not found' });
    const filePath = path.join(__dirname, rows[0].file_path);
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    await pool.query('DELETE FROM backups WHERE id=$1', [id]);
    await logAudit('delete_backup', deletedBy, `Deleted backup ${rows[0].file_name}`);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Restores the database from a backup file. Destructive: truncates every
// table the backup captured and reloads it from the dump, inside a single
// transaction (so a failure rolls back to the pre-restore state rather than
// leaving the database half-restored). A fresh safety backup of the CURRENT
// state is always taken first, so this action can itself be undone by
// restoring that safety backup afterward.
app.post('/api/web/backup/:id/restore', async (req, res) => {
  const { id } = req.params;
  const { restoredBy } = req.body;
  if (!dbAvailable) return res.status(503).json({ error: 'Database not connected' });

  const { rows } = await pool.query('SELECT * FROM backups WHERE id=$1', [id]);
  if (rows.length === 0) return res.status(404).json({ error: 'Backup not found' });
  const backup = rows[0];
  const filePath = path.join(__dirname, backup.file_path);
  if (!fs.existsSync(filePath)) return res.status(404).json({ error: 'Backup file not on disk' });

  let dump;
  try {
    dump = JSON.parse(zlib.gunzipSync(fs.readFileSync(filePath)).toString());
  } catch (err) {
    return res.status(400).json({ error: `Backup file is corrupt: ${err.message}` });
  }

  let safetyBackup;
  try {
    safetyBackup = await createDatabaseBackup(`${restoredBy || 'Admin'} (auto, pre-restore)`);
  } catch (err) {
    return res.status(500).json({ error: `Could not create safety backup, restore aborted: ${err.message}` });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tableNames = Object.keys(dump);
    const orderedTables = [
      ...BACKUP_TABLE_PRIORITY.filter(t => tableNames.includes(t)),
      ...tableNames.filter(t => !BACKUP_TABLE_PRIORITY.includes(t)),
    ];

    const quotedList = orderedTables.map(t => `"${t}"`).join(', ');
    if (quotedList) {
      await client.query(`TRUNCATE TABLE ${quotedList} RESTART IDENTITY CASCADE`);
    }

    for (const table of orderedTables) {
      const tableRows = dump[table];
      if (!Array.isArray(tableRows) || tableRows.length === 0) continue;
      const columns = Object.keys(tableRows[0]);
      const columnList = columns.map(c => `"${c}"`).join(', ');
      for (const row of tableRows) {
        const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');
        const values = columns.map(c => row[c]);
        await client.query(
          `INSERT INTO "${table}" (${columnList}) VALUES (${placeholders})`,
          values
        );
      }
    }

    // Rows above were reinserted with their original explicit ids, which
    // does NOT advance each table's SERIAL sequence — without this, the
    // very next INSERT anywhere would collide with a restored id and fail.
    // Not every table has an `id` column (e.g. staff_preferences uses
    // staff_id as its key), so check before asking Postgres for its
    // sequence — pg_get_serial_sequence errors if the column is missing.
    for (const table of orderedTables) {
      const { rows: colRows } = await client.query(
        `SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name=$1 AND column_name='id'`,
        [table]
      );
      if (colRows.length === 0) continue;
      const { rows: seqRows } = await client.query(`SELECT pg_get_serial_sequence($1, 'id') AS seq`, [table]);
      const seqName = seqRows[0]?.seq;
      if (seqName) {
        await client.query(`SELECT setval($1, COALESCE((SELECT MAX(id) FROM "${table}"), 1))`, [seqName]);
      }
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: `Restore failed and was rolled back: ${err.message}` });
  } finally {
    client.release();
  }

  await logAudit('restore_backup', restoredBy, `Restored from backup ${backup.file_name} (safety backup ${safetyBackup.file_name} created first)`);
  io.emit('activity_logged', { action: 'restore_backup' });
  res.json({ success: true, safetyBackup });
});

// ── APPOINTMENTS: SEARCH ──────────────────────────────────────────────────────

app.get('/api/web/appointments/search', async (req, res) => {
  const { q } = req.query;
  if (!q) return res.json([]);
  try {
    if (dbAvailable) {
      // date is cast to a plain 'YYYY-MM-DD' string (TO_CHAR), same as
      // GET /api/web/appointments — otherwise node-postgres serializes the
      // DATE column through a timezone-aware JS Date, which can shift it a
      // calendar day off once converted to UTC for JSON.
      const { rows } = await pool.query(
        `SELECT id, citizen_nic, citizen_name, service, office, TO_CHAR(date, 'YYYY-MM-DD') AS date,
                time, token, status, payment_status, fee_amount, payment_method, qr_data, created_at
         FROM appointments WHERE citizen_nic ILIKE $1 OR citizen_name ILIKE $1 ORDER BY created_at DESC LIMIT 50`,
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
  const numDays = Math.min(Math.abs(parseInt(req.query.days) || 7), 365);
  try {
    if (dbAvailable) {
      const { rows } = await pool.query(
        `SELECT su.name AS user_name, su.role, su.target,
           COALESCE(qe.services_completed, 0) AS services_completed,
           qe.avg_time_minutes,
           fb.avg_satisfaction
         FROM staff_users su
         LEFT JOIN (
           SELECT served_by,
             COUNT(*) AS services_completed,
             ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - served_at)) / 60)::numeric, 1) AS avg_time_minutes
           FROM queue_entries
           WHERE status = 'completed' AND served_by IS NOT NULL
             AND completed_at >= CURRENT_DATE - ($1 || ' days')::INTERVAL
           GROUP BY served_by
         ) qe ON qe.served_by = su.name
         LEFT JOIN (
           SELECT served_by, ROUND(AVG(rating)::numeric, 1) AS avg_satisfaction
           FROM feedback
           WHERE served_by IS NOT NULL
             AND created_at >= CURRENT_DATE - ($1 || ' days')::INTERVAL
           GROUP BY served_by
         ) fb ON fb.served_by = su.name
         WHERE su.status != 'Deleted'
         ORDER BY services_completed DESC`,
        [numDays]
      );
      const onlineNames = new Set(Array.from(activeUsers.values()).map(u => u.name));
      const withStatus = rows.map(r => ({ ...r, status: onlineNames.has(r.user_name) ? 'Online' : 'Away' }));
      res.json(withStatus);
    } else {
      res.json([]);
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/web/payment-reports', async (req, res) => {
  const numDays = Math.min(Math.abs(parseInt(req.query.days) || 30), 365);
  try {
    if (!dbAvailable) return res.json({ transactions: [], byMethod: [], byService: [] });

    const [{ rows: transactions }, { rows: byMethod }, { rows: byService }] = await Promise.all([
      pool.query(
        `SELECT id, citizen_name, service, fee_amount, date, payment_method, payment_status
         FROM appointments
         WHERE fee_amount > 0 AND date >= CURRENT_DATE - ($1 || ' days')::INTERVAL
         ORDER BY date DESC, created_at DESC`,
        [numDays]
      ),
      pool.query(
        `SELECT payment_method, SUM(fee_amount) AS total, COUNT(*) AS count
         FROM appointments
         WHERE fee_amount > 0 AND date >= CURRENT_DATE - ($1 || ' days')::INTERVAL AND payment_method IS NOT NULL
         GROUP BY payment_method ORDER BY total DESC`,
        [numDays]
      ),
      pool.query(
        `SELECT service, SUM(fee_amount) AS total, COUNT(*) AS count
         FROM appointments
         WHERE fee_amount > 0 AND date >= CURRENT_DATE - ($1 || ' days')::INTERVAL
         GROUP BY service ORDER BY total DESC LIMIT 3`,
        [numDays]
      ),
    ]);

    res.json({ transactions, byMethod, byService });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── IMAGE MODERATION (local NSFWJS model — free, no API key, no billing) ────
// Runs fully offline on this server; images are never sent to a third party.

const { moderateImage, getModel } = require('./image_moderation');

app.post('/api/moderate-image', async (req, res) => {
  const { imageBase64 } = req.body;
  if (!imageBase64) return res.status(400).json({ error: 'imageBase64 is required' });

  try {
    const result = await moderateImage(Buffer.from(imageBase64, 'base64'));
    res.json({ safe: result.safe, reasons: result.reasons });
  } catch (err) {
    console.error('Image moderation error:', err.message);
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
getModel().catch((err) => console.warn('⚠️  Image moderation model failed to load:', err.message));
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
    console.log(`  GET    /api/web/reports`);
    console.log(`  POST   /api/web/reports/generate`);
    console.log(`  GET    /api/web/reports/download/:id`);
    console.log(`  GET    /api/web/backup`);
    console.log(`  POST   /api/web/backup/create`);
    console.log(`  GET    /api/web/backup/download/:id`);
    console.log(`  DELETE /api/web/backup/:id`);
    console.log(`  POST   /api/web/backup/:id/restore`);
    console.log(`\n  ── Appointments ──────────────────────────────────`);
    console.log(`  GET    /api/web/appointments`);
    console.log(`  POST   /api/web/appointments`);
    console.log(`  PUT    /api/web/appointments/:id/status`);
    console.log(`  GET    /api/web/appointments/search?q=`);
    console.log(`\n  ── Feedback ──────────────────────────────────────`);
    console.log(`  POST   /api/web/feedback`);
    console.log(`\n  ── Office Settings ───────────────────────────────`);
    console.log(`  GET    /api/web/office-settings`);
    console.log(`  GET    /api/web/office-settings/:officeId`);
    console.log(`  POST   /api/web/office-settings`);
    console.log(`  PUT    /api/web/office-settings/:officeId`);
    console.log(`  GET    /api/web/system-settings`);
    console.log(`  PUT    /api/web/system-settings`);
    console.log(`  GET    /api/web/departments`);
    console.log(`  POST   /api/web/departments`);
    console.log(`  PUT    /api/web/departments/:id/status`);
    console.log(`  DELETE /api/web/departments/:id`);
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
    console.log(`  GET    /api/web/payment-reports`);
    console.log(`\n  ── System ────────────────────────────────────────`);
    console.log(`  GET    /api/web/audit-logs`);
    console.log(`  GET    /api/web/system/health`);
    console.log(`\n  ── Payments ──────────────────────────────────────`);
    console.log(`  POST   /api/create-payment-intent`);
    console.log(`  POST   /api/process-payment`);
    console.log(`  POST   /api/stripe/webhook`);
    console.log(`\n  ── Moderation ────────────────────────────────────`);
    console.log(`  POST   /api/moderate-image`);
    console.log(`\n  ── Chat (Socket.IO) ──────────────────────────────`);
    console.log(`  GET    /api/chats/:userId`);
    console.log(`  GET    /api/messages/:chatId`);
    console.log(`  POST   /api/chats/start`);
    console.log(`  WS     socket.io  (register / send_message / mark_read)\n`);
  });
});
