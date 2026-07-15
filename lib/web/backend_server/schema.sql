-- QueueNova PostgreSQL Schema
-- Usage:
--   1. Create the database once:  psql -U postgres -c "CREATE DATABASE queuenova;"
--   2. Run this file:             psql -U postgres -d queuenova -f schema.sql

-- Staff users (web dashboard officers)
CREATE TABLE IF NOT EXISTS staff_users (
  id            SERIAL PRIMARY KEY,
  name          VARCHAR(255) NOT NULL,
  email         VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role          VARCHAR(100) NOT NULL,
  phone         VARCHAR(20),
  photo_url     TEXT,
  status        VARCHAR(50)  DEFAULT 'Active',
  target        INTEGER      DEFAULT 100,
  last_active   TIMESTAMP    DEFAULT NOW(),
  created_at    TIMESTAMP    DEFAULT NOW()
);

-- Queue entries per office
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
  served_by      VARCHAR(255),
  created_at     TIMESTAMP     DEFAULT NOW(),
  served_at      TIMESTAMP,
  completed_at   TIMESTAMP
);

-- Emergency / priority queue
CREATE TABLE IF NOT EXISTS emergency_queue (
  id             SERIAL PRIMARY KEY,
  token          VARCHAR(20)  NOT NULL,
  office_id      VARCHAR(255) NOT NULL,
  citizen_name   VARCHAR(255),
  reason         VARCHAR(255),
  payment_status VARCHAR(50)  DEFAULT 'paid',
  status         VARCHAR(50)  DEFAULT 'priority',
  created_at     TIMESTAMP    DEFAULT NOW()
);

-- Document submissions from citizens
CREATE TABLE IF NOT EXISTS documents (
  id               SERIAL PRIMARY KEY,
  appointment_id   VARCHAR(255),
  citizen_name     VARCHAR(255),
  citizen_nic      VARCHAR(20),
  document_name    VARCHAR(255) NOT NULL,
  document_type    VARCHAR(100),
  file_path        VARCHAR(500),
  status           VARCHAR(50)  DEFAULT 'pending',
  rejection_reason TEXT,
  reviewed_by_name VARCHAR(255),
  shared_with      TEXT[]       DEFAULT '{}',
  uploaded_at      TIMESTAMP    DEFAULT NOW(),
  reviewed_at      TIMESTAMP,
  reviewed_by      INTEGER      REFERENCES staff_users(id)
);

-- Appointments (mirror of Firestore, for web reporting)
CREATE TABLE IF NOT EXISTS appointments (
  id             VARCHAR(255)  PRIMARY KEY,
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
);
-- Add qr_data to databases created before this column existed
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS qr_data TEXT;

-- Audit trail
CREATE TABLE IF NOT EXISTS audit_logs (
  id         SERIAL PRIMARY KEY,
  action     VARCHAR(255) NOT NULL,
  user_id    INTEGER      REFERENCES staff_users(id),
  user_name  VARCHAR(255),
  details    TEXT,
  ip_address VARCHAR(64),
  created_at TIMESTAMP    DEFAULT NOW()
);

-- Notifications per staff user (NULL user_id = broadcast to all)
CREATE TABLE IF NOT EXISTS notifications (
  id         SERIAL PRIMARY KEY,
  title      VARCHAR(255) NOT NULL,
  message    TEXT         NOT NULL,
  type       VARCHAR(50)  DEFAULT 'system',
  is_read    BOOLEAN      DEFAULT FALSE,
  user_id    INTEGER      REFERENCES staff_users(id),
  metadata   JSONB,
  created_at TIMESTAMP    DEFAULT NOW()
);

-- Citizen feedback / satisfaction ratings
CREATE TABLE IF NOT EXISTS feedback (
  id           SERIAL PRIMARY KEY,
  citizen_name VARCHAR(255),
  citizen_nic  VARCHAR(20),
  service      VARCHAR(255),
  rating       INTEGER      NOT NULL,
  comment      TEXT,
  served_by    VARCHAR(255),
  created_at   TIMESTAMP    DEFAULT NOW()
);

-- System-wide settings (single row; General/Queue/Office-Hours toggles from
-- the System Settings screen). JSONB blob like staff_preferences, since the
-- setting set may grow.
CREATE TABLE IF NOT EXISTS system_settings (
  id         INTEGER PRIMARY KEY DEFAULT 1,
  settings   JSONB     NOT NULL DEFAULT '{}',
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Departments configured in System Settings → Department Management
CREATE TABLE IF NOT EXISTS departments (
  id         SERIAL PRIMARY KEY,
  name       VARCHAR(255) NOT NULL,
  code       VARCHAR(50)  NOT NULL,
  type       VARCHAR(100),
  active     BOOLEAN      DEFAULT TRUE,
  created_at TIMESTAMP    DEFAULT NOW()
);

-- Security settings (single row; Password Policy/Session/Login/Audit
-- toggles from the Security Settings screen, including the IP whitelist).
CREATE TABLE IF NOT EXISTS security_settings (
  id         INTEGER PRIMARY KEY DEFAULT 1,
  settings   JSONB     NOT NULL DEFAULT '{}',
  updated_at TIMESTAMP DEFAULT NOW()
);

-- System Health Monitor history — one row per health check performed
-- (manual refresh, auto-refresh, or the initial load). Uptime percentages
-- shown on that screen are computed from this table, so they only reflect
-- checks performed since this feature started recording — there is no
-- historical data from before it existed.
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
);

-- Generated report files (Reports screen)
CREATE TABLE IF NOT EXISTS reports (
  id           SERIAL PRIMARY KEY,
  report_type  VARCHAR(20)  NOT NULL,
  report_date  DATE         NOT NULL,
  file_name    VARCHAR(255) NOT NULL,
  file_path    VARCHAR(500) NOT NULL,
  generated_by VARCHAR(255),
  generated_at TIMESTAMP    DEFAULT NOW()
);

-- Full database backups (Backup & Restore screen). Every row in `public`
-- is dumped to a gzipped JSON file at backup time; restoring truncates and
-- reloads every table it captured.
CREATE TABLE IF NOT EXISTS backups (
  id           SERIAL PRIMARY KEY,
  file_name    VARCHAR(255) NOT NULL,
  file_path    VARCHAR(500) NOT NULL,
  size_bytes   BIGINT       NOT NULL DEFAULT 0,
  backup_type  VARCHAR(20)  NOT NULL DEFAULT 'Full',
  status       VARCHAR(20)  NOT NULL DEFAULT 'Success',
  created_by   VARCHAR(255),
  created_at   TIMESTAMP    DEFAULT NOW()
);

-- Per-officer dashboard/app preferences (Settings screen). One flexible
-- JSONB blob per staff member rather than one column per setting, since
-- the set of settings differs by role and the screen may add more later.
CREATE TABLE IF NOT EXISTS staff_preferences (
  staff_id   INTEGER PRIMARY KEY REFERENCES staff_users(id),
  settings   JSONB     NOT NULL DEFAULT '{}',
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Office operating hours & queue limits
CREATE TABLE IF NOT EXISTS office_settings (
  id         SERIAL PRIMARY KEY,
  office_id  VARCHAR(255) UNIQUE NOT NULL,
  open_time  VARCHAR(10)  DEFAULT '08:00',
  close_time VARCHAR(10)  DEFAULT '17:00',
  max_queue  INTEGER      DEFAULT 100,
  is_active  BOOLEAN      DEFAULT TRUE,
  updated_at TIMESTAMP    DEFAULT NOW()
);

-- Useful indexes
CREATE INDEX IF NOT EXISTS idx_queue_office_status   ON queue_entries (office_id, status);
CREATE INDEX IF NOT EXISTS idx_queue_created         ON queue_entries (created_at);
CREATE INDEX IF NOT EXISTS idx_appointments_date     ON appointments  (date);
CREATE INDEX IF NOT EXISTS idx_appointments_nic      ON appointments  (citizen_nic);
CREATE INDEX IF NOT EXISTS idx_audit_created         ON audit_logs    (created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_user    ON notifications (user_id);
