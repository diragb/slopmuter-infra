BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'deactivation_reason_type'
  ) THEN
    CREATE TYPE deactivation_reason_type AS ENUM ('expired', 'appeal_approved');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'report_status_type'
  ) THEN
    CREATE TYPE report_status_type AS ENUM ('pending', 'counted', 'enrichment', 'discarded', 'expired');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'appeal_status_type'
  ) THEN
    CREATE TYPE appeal_status_type AS ENUM ('pending', 'approved', 'rejected');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'subscription_plan_type'
  ) THEN
    CREATE TYPE subscription_plan_type AS ENUM ('monthly', 'annual');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'subscription_status_type'
  ) THEN
    CREATE TYPE subscription_status_type AS ENUM ('active', 'cancelled', 'past_due', 'trialing');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'role_type'
  ) THEN
    CREATE TYPE role_type AS ENUM ('admin');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS muted_accounts (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username_hash VARCHAR NOT NULL UNIQUE,
  username VARCHAR NOT NULL,
  report_count INT NOT NULL,
  total_rep_points INT NOT NULL,
  category_mask BIGINT NOT NULL,
  offense_number INT NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  promoted_at TIMESTAMPTZ DEFAULT NOW(),
  deactivated_at TIMESTAMPTZ,
  deactivation_reason deactivation_reason_type
);

CREATE TABLE IF NOT EXISTS mute_expiry (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  muted_account_id INT NOT NULL REFERENCES muted_accounts(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS reports (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  target_username_hash VARCHAR NOT NULL,
  target_username VARCHAR NOT NULL,
  reporter_user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT, -- cross-service (Mute → Users)
  reporter_rep_at_time INT NOT NULL,
  category_mask BIGINT NOT NULL,
  tweet_url VARCHAR NOT NULL,
  note VARCHAR(280),
  offense_number INT NOT NULL,
  status report_status_type NOT NULL DEFAULT 'pending',
  reported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_reports_target_reporter_offense UNIQUE (target_username_hash, reporter_user_id, offense_number)
);

CREATE TABLE IF NOT EXISTS appeals (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  muted_account_id INT NOT NULL REFERENCES muted_accounts(id) ON DELETE RESTRICT,
  appellant_email VARCHAR NOT NULL,
  message TEXT NOT NULL,
  tweet_url VARCHAR,
  status appeal_status_type NOT NULL DEFAULT 'pending',
  reviewed_by INT REFERENCES users(id) ON DELETE SET NULL, -- cross-service: admin user
  appealed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS categories (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bit_position INT NOT NULL UNIQUE,
  slug VARCHAR NOT NULL UNIQUE,
  display_name VARCHAR NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  pro_only_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS roles (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role role_type NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_roles_user_id_role UNIQUE (user_id, role)
);

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  admin_user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT, -- cross-service (references users.id)
  action VARCHAR NOT NULL,
  target_type VARCHAR,
  target_id INT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- cross-service (Payments → Users)
  stripe_customer_id VARCHAR NOT NULL,
  stripe_subscription_id VARCHAR NOT NULL,
  plan subscription_plan_type,
  status subscription_status_type,
  current_period_end TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_muted_accounts_username_hash
  ON muted_accounts(username_hash);

CREATE INDEX IF NOT EXISTS idx_muted_accounts_is_active
  ON muted_accounts(is_active);

CREATE INDEX IF NOT EXISTS idx_reports_target_offense_status
  ON reports(target_username_hash, offense_number, status);

CREATE INDEX IF NOT EXISTS idx_reports_reporter_user_id
  ON reports(reporter_user_id);

CREATE INDEX IF NOT EXISTS idx_reports_reported_at
  ON reports(reported_at);

CREATE INDEX IF NOT EXISTS idx_mute_expiry_expires_at
  ON mute_expiry(expires_at);

CREATE INDEX IF NOT EXISTS idx_mute_expiry_muted_account_id
  ON mute_expiry(muted_account_id);

CREATE INDEX IF NOT EXISTS idx_appeals_muted_account_id
  ON appeals(muted_account_id);

CREATE INDEX IF NOT EXISTS idx_appeals_status
  ON appeals(status);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id
  ON subscriptions(user_id);

CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_customer_id
  ON subscriptions(stripe_customer_id);

CREATE INDEX IF NOT EXISTS idx_categories_is_active
  ON categories(is_active);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin_user_id
  ON admin_audit_log(admin_user_id);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_target
  ON admin_audit_log(target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created_at
  ON admin_audit_log(created_at);

COMMIT;
