-- Tables
DROP TABLE IF EXISTS token_buckets;
CREATE TABLE token_buckets (
    user_id VARCHAR(100) PRIMARY KEY,
    tokens INTEGER,
    last_refill TIMESTAMP
);
DROP TABLE IF EXISTS token_rates;
CREATE TABLE token_rates (
    user_id VARCHAR(100) PRIMARY KEY,
    per_hour INTEGER
);

