BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'subscription_tier'
  ) THEN
    CREATE TYPE subscription_tier AS ENUM ('free', 'pro');
  END IF;
END $$;

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
  last_inactivity_rep_decay_at TIMESTAMPTZ,
  CONSTRAINT users_provider_user_unique UNIQUE (auth_provider, provider_user_id)
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at TIMESTAMPTZ,
  replaced_by_token_hash TEXT,
  user_agent TEXT,
  ip_address INET
);

CREATE TABLE IF NOT EXISTS user_preferences (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_mask BIGINT NOT NULL,
  mute_on_twitter_default BOOLEAN NOT NULL DEFAULT TRUE,
  notify_on_report_muted_target BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_user_preferences_user_id UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id
  ON user_preferences(user_id);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id
  ON refresh_tokens(user_id);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at
  ON refresh_tokens(expires_at);

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
  reporter_user_id INT REFERENCES users(id) ON DELETE SET NULL,
  reporter_rep_at_time INT NOT NULL,
  category_mask BIGINT NOT NULL,
  tweet_url VARCHAR NOT NULL,
  note VARCHAR(280),
  offense_number INT NOT NULL,
  status report_status_type NOT NULL DEFAULT 'pending',
  reported_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_reports_target_reporter_offense_active
  ON reports (target_username_hash, reporter_user_id, offense_number)
  WHERE reporter_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_reports_reporter_user_id
  ON reports(reporter_user_id);

CREATE TABLE IF NOT EXISTS appeals (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  muted_account_id INT NOT NULL REFERENCES muted_accounts(id) ON DELETE RESTRICT,
  appellant_email VARCHAR NOT NULL,
  message TEXT NOT NULL,
  tweet_url VARCHAR,
  status appeal_status_type NOT NULL DEFAULT 'pending',
  reviewed_by INT REFERENCES users(id) ON DELETE SET NULL,
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
  admin_user_id INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  action VARCHAR NOT NULL,
  target_type VARCHAR,
  target_id INT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
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

INSERT INTO categories (bit_position, slug, display_name, description)
VALUES
  (0, 'ai_slop', 'AI Slop', 'Low-quality, generic, or spammy AI-generated posts and replies.'),
  (1, 'ai_maximalism_evangelists', 'AI Maximalism Evangelists', 'Accounts pushing uncritical hype that AI replaces human creativity or judgment.'),
  (2, 'engagement_farming', 'Engagement Farming', 'Posts designed only to drive likes, reposts, or replies without real substance.'),
  (3, 'low_effort_memes', 'Low Effort Memes', 'Recycled or lazy meme spam that clogs timelines with little originality.'),
  (4, 'crypto_spam', 'Crypto Spam', 'Unsolicited token shilling, airdrop noise, or repetitive crypto promotions.'),
  (5, 'ragebait', 'Ragebait', 'Content crafted mainly to provoke anger or outrage for engagement.'),
  (6, 'porn_bots', 'Porn Bots', 'Automated or spam accounts distributing adult content or links.'),
  (7, 'political_spam', 'Political Spam', 'Repetitive or manipulative political messaging, astroturfing, or bot-like campaigning.'),
  (8, 'reply_bots', 'Reply Bots', 'Automated replies that hijack threads with irrelevant or canned responses.'),
  (9, 'self_promo', 'Self Promo', 'Excessive unsolicited promotion of products, newsletters, or channels.'),
  (10, 'stolen_content', 'Stolen Content', 'Content reposted without credit from creators who own the original work.'),
  (11, 'scams', 'Scams', 'Fraudulent offers, phishing patterns, or obvious scam behavior.'),
  (12, 'health_misinformation', 'Health Misinformation', 'Dangerous or false health claims that could mislead readers.'),
  (13, 'disinfo', 'Disinformation', 'Deliberately false or misleading claims presented as fact.'),
  (14, 'extremist_propaganda', 'Extremist Propaganda', 'Content promoting extremist ideology, recruitment, or violent narratives.'),
  (15, 'hate_speech', 'Hate Speech', 'Harassment or slurs targeting people based on identity or protected traits.'),
  (16, 'doxxing', 'Doxxing', 'Sharing private personal information to harass or endanger someone.'),
  (17, 'gore_shock_media', 'Gore & Shock Media', 'Graphic violence, shock imagery, or gratuitous gore without meaningful context.'),
  (18, 'chain_letter_threads', 'Chain Letter Threads', 'Copy-paste chain posts that pressure others to spread junk across the network.'),
  (19, 'horoscope_spam', 'Horoscope Spam', 'Astrology or horoscope spam used to farm engagement or sell readings.'),
  (20, 'pump_and_dump_traders', 'Pump and Dump Traders', 'Coordinated hype to manipulate asset prices for quick profit.'),
  (21, 'mlm', 'MLM / Pyramid Messaging', 'Multi-level marketing recruitment, downline spam, or pyramid-style pitches.'),
  (22, 'forex_shillers', 'Forex Shillers', 'Aggressive forex or trading course scams and get-rich-quick trading posts.'),
  (23, 'giveaway_bots', 'Giveaway Bots', 'Fake giveaways, prize scams, or bot accounts impersonating brands.'),
  (24, 'pirated_content', 'Pirated Content', 'Links or posts primarily distributing pirated media or warez.'),
  (25, 'follow4follow', 'Follow4Follow Spam', 'Follow-for-follow rings and mutual follow begging that degrades feed quality.'),
  (26, 'nft_clickbait', 'NFT Clickbait', 'NFT hype posts, low-effort PFP grifts, or repetitive NFT promotions.'),
  (27, 'brand_stan_accounts', 'Brand Stan Accounts', 'Accounts that exist mainly to worship or obsessively defend a brand or celebrity.'),
  (28, 'threadboi_fluff', 'Threadboi Fluff', 'Long threads that promise insight but deliver empty motivational filler.'),
  (29, 'quote_tweet_farmers', 'Quote Tweet Farmers', 'Quote-tweeting solely to farm visibility off others without adding value.'),
  (30, 'sob_story_bait', 'Sob Story Bait', 'Emotional manipulation or fabricated hardship stories to drive engagement or donations.'),
  (31, 'fake_expert_gurus', 'Fake Expert Gurus', 'Posing as experts to sell courses, signals, or access with fake credibility.'),
  (32, 'forced_positivity_cult', 'Forced Positivity Cult', 'Toxic positivity that dismisses real harm or shames people for normal feelings.'),
  (33, 'edgelord_trolls', 'Edgelord Trolls', 'Provocateurs who stir drama or offense as their main brand.'),
  (34, 'mass_tagging', 'Mass Tagging', 'Spamming many @mentions or lists to force notifications.'),
  (35, 'lottery_prediction_spam', 'Lottery Prediction Spam', 'Fake winning numbers, prediction scams, or gambling spam.'),
  (36, 'job_listing_scams', 'Job Listing Scams', 'Fake jobs, reshipping scams, or bait-and-switch employment offers.'),
  (37, 'link_shortener_bait', 'Link Shortener Bait', 'Opaque short links used to hide spam, malware, or click fraud.'),
  (38, 'perpetual_preorder_hype', 'Perpetual Preorder Hype', 'Endless preorder or crowdfund hype without shipping real products.')
ON CONFLICT (bit_position) DO NOTHING;

COMMIT;
