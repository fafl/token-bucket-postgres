-- Tables
DROP TABLE IF EXISTS token_buckets;
CREATE TABLE token_buckets (user_id VARCHAR(100) PRIMARY KEY, tokens INTEGER, last_take TIMESTAMP);
DROP TABLE IF EXISTS token_rates;
CREATE TABLE token_rates (user_id VARCHAR(100) PRIMARY KEY, per_hour INTEGER);
 
-- Data
INSERT INTO token_rates VALUES ('foo', 3600);
 
-- Function
DROP FUNCTION IF EXISTS take_token(character varying);
CREATE OR REPLACE FUNCTION take_token (user_id VARCHAR(100)) RETURNS boolean AS $$
DECLARE
    rate INTEGER;
    tokens INTEGER;
    extra_tokens INTEGER;
    new_tokens INTEGER;
    last_take TIMESTAMP;
    this_take TIMESTAMP;
BEGIN
    -- Check if this user exists
    SELECT per_hour INTO rate FROM token_rates r WHERE r.user_id = $1;
    IF rate IS NULL THEN
        raise notice 'User % does not have a rate configured', $1;
        RETURN FALSE;
    END IF;

    -- Lock the buckets until end of transaction
    LOCK TABLE token_buckets IN EXCLUSIVE MODE;

    -- Read current tokens and last take
    SELECT b.tokens, b.last_take INTO tokens, last_take FROM token_buckets b WHERE b.user_id = $1;
    IF tokens IS NULL THEN
        tokens := rate; -- Start with the max amount of tokens
        last_take = now();
        raise notice 'Setting up a bucket for user % with % tokens', $1, tokens;
        INSERT INTO token_buckets VALUES ($1, tokens, last_take);
    END IF;

    -- Calculate newly generated tokens since last call
    extra_tokens := floor(
        EXTRACT(EPOCH FROM (now() - last_take) * rate / 3600.0)
    )::int;
    this_take := last_take + (extra_tokens * interval '1 second' * 3600.0 / rate);
    new_tokens := LEAST(rate, tokens + extra_tokens);
    raise notice 'User % has % tokens, last batch generated at %', $1, new_tokens, this_take;

    -- If there are no tokens left then we don't need to do anything
    IF new_tokens <= 0 THEN
        RETURN FALSE;
    END IF;

    -- Set new values and return
    UPDATE token_buckets b SET (tokens, last_take) = (new_tokens - 1, this_take) WHERE b.user_id = $1;
    RETURN TRUE;
END
$$ LANGUAGE plpgsql;
 
-- Run it
SELECT take_token('foo');
SELECT take_token('foo');

SELECT pg_sleep(3);

SELECT take_token('foo');
SELECT take_token('foo');
SELECT take_token('foo');
SELECT take_token('foo');
SELECT take_token('foo');
