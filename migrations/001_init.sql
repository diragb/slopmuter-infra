CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE subscription_tier AS ENUM ('free', 'pro');

CREATE TABLE IF NOT EXISTS users (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  name TEXT,
  avatar_url TEXT,
  twitter_username TEXT,
  accounts_reported_count INT DEFAULT 0,
  successful_reports_count INT DEFAULT 0,
  reputation_points INT DEFAULT 10,
  subscription_tier subscription_tier DEFAULT 'free',
  auth_provider TEXT NOT NULL DEFAULT 'google',
  provider_user_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active_at TIMESTAMPTZ,
  last_report_at TIMESTAMPTZ,
  last_monthly_rep_awarded_at TIMESTAMPTZ,
  CONSTRAINT users_provider_user_unique UNIQUE (auth_provider, provider_user_id)
);

create table if not exists refresh_tokens (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  replaced_by_token_hash text,
  user_agent text,
  ip_address inet
);

create index if not exists idx_refresh_tokens_user_id
  on refresh_tokens(user_id);

create index if not exists idx_refresh_tokens_expires_at
  on refresh_tokens(expires_at);
