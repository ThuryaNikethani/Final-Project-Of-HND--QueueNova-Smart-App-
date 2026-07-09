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
  status        VARCHAR(50)  DEFAULT 'Active',
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
  created_at   TIMESTAMP    DEFAULT NOW()
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
