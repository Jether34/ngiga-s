CREATE DATABASE IF NOT EXISTS stockroom CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE stockroom;

CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(36) PRIMARY KEY,
  email VARCHAR(254) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(100) NOT NULL,
  account_id VARCHAR(64) NOT NULL UNIQUE,
  phone VARCHAR(32) NULL UNIQUE,
  year_level VARCHAR(24) NULL,
  program VARCHAR(120) NULL,
  home_address VARCHAR(240) NULL,
  terms_accepted_at DATETIME(6) NULL,
  role ENUM('ADMIN','STUDENT','FACULTY','USER') NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS equipment (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(160) NOT NULL,
  category VARCHAR(100) NOT NULL,
  min_stock INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS units (
  id VARCHAR(36) PRIMARY KEY,
  equipment_id VARCHAR(64) NOT NULL,
  serial VARCHAR(160) NOT NULL UNIQUE,
  status ENUM('AVAILABLE','ISSUED','MAINTENANCE') NOT NULL,
  CONSTRAINT fk_units_equipment FOREIGN KEY (equipment_id) REFERENCES equipment(id),
  INDEX idx_units_equipment_status (equipment_id, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loans (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  unit_id VARCHAR(36) NOT NULL,
  borrowed_at DATETIME(6) NOT NULL,
  due_at DATETIME(6) NOT NULL,
  returned_at DATETIME(6) NULL,
  status ENUM('ACTIVE','RETURNED','OVERDUE') NOT NULL,
  active_unit_id VARCHAR(36) GENERATED ALWAYS AS
    (CASE WHEN status IN ('ACTIVE','OVERDUE') THEN unit_id ELSE NULL END) STORED,
  CONSTRAINT fk_loans_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_loans_unit FOREIGN KEY (unit_id) REFERENCES units(id),
  UNIQUE KEY uq_loans_one_active_per_unit (active_unit_id),
  INDEX idx_loans_borrower_time (user_id, borrowed_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS transactions (
  id VARCHAR(36) PRIMARY KEY,
  equipment_id VARCHAR(64) NOT NULL,
  unit_id VARCHAR(36) NULL,
  loan_id VARCHAR(36) NULL,
  type ENUM('RECEIVE','ISSUE') NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  created_at DATETIME(6) NOT NULL,
  actor_id VARCHAR(36) NOT NULL,
  idempotency_key VARCHAR(128) NOT NULL UNIQUE,
  CONSTRAINT fk_tx_equipment FOREIGN KEY (equipment_id) REFERENCES equipment(id),
  CONSTRAINT fk_tx_unit FOREIGN KEY (unit_id) REFERENCES units(id),
  CONSTRAINT fk_tx_loan FOREIGN KEY (loan_id) REFERENCES loans(id),
  CONSTRAINT fk_tx_actor FOREIGN KEY (actor_id) REFERENCES users(id),
  INDEX idx_tx_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS receipts (
  loan_id VARCHAR(36) PRIMARY KEY,
  receipt_number VARCHAR(32) NOT NULL UNIQUE,
  created_at DATETIME(6) NOT NULL,
  CONSTRAINT fk_receipts_loan FOREIGN KEY (loan_id) REFERENCES loans(id)
) ENGINE=InnoDB;

-- Transactional outbox lets every API replica deliver committed inventory
-- changes to the WebSocket clients connected to that replica.
CREATE TABLE IF NOT EXISTS outbox_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  event_type VARCHAR(32) NOT NULL,
  payload JSON NOT NULL,
  created_at DATETIME(6) NOT NULL,
  INDEX idx_outbox_created (created_at)
) ENGINE=InnoDB;
