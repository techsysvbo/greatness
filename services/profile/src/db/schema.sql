CREATE TABLE IF NOT EXISTS profiles (
  id SERIAL PRIMARY KEY,
  user_id INTEGER UNIQUE NOT NULL, -- References users(id) in Auth service. Note: no FK constraint if separate DBs, but here they share DB so we technically could, but loose coupling is better for microservices.
  bio TEXT,
  location VARCHAR(255),
  zip_code VARCHAR(20),
  avatar_url VARCHAR(512),
  profession VARCHAR(255),
  interests TEXT[],
  privacy_settings JSONB DEFAULT '{"profile_visibility": "public"}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


