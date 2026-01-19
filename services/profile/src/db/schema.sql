CREATE TABLE IF NOT EXISTS profiles (
  id SERIAL PRIMARY KEY,
  user_id INTEGER UNIQUE NOT NULL,
  display_name VARCHAR(150),
  profession VARCHAR(255),
  country_code CHAR(2),
  state VARCHAR(150),
  city VARCHAR(150),
  bio TEXT,
  interests TEXT[],
  privacy_settings JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
