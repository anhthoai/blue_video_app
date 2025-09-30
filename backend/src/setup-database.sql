-- Create database and user for Blue Video App
-- Run this as a PostgreSQL superuser (postgres)

-- Create database
CREATE DATABASE blue_video_db;

-- Create user
CREATE USER blue_video_user WITH PASSWORD 'your_db_password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE blue_video_db TO blue_video_user;

-- Connect to the database and grant schema privileges
\c blue_video_db;
GRANT ALL ON SCHEMA public TO blue_video_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO blue_video_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO blue_video_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO blue_video_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO blue_video_user;
