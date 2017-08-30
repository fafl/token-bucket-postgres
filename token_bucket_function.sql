-- Function
DROP FUNCTION IF EXISTS take_token(VARCHAR);
CREATE OR REPLACE FUNCTION take_token (user_id VARCHAR(100)) RETURNS boolean AS $$
DECLARE
    rate INTEGER;
    tokens INTEGER;
    extra_tokens INTEGER;
    new_tokens INTEGER;
    last_refill TIMESTAMP;
    this_refill TIMESTAMP;
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
    SELECT b.tokens, b.last_refill INTO tokens, last_refill FROM token_buckets b WHERE b.user_id = $1;
    IF tokens IS NULL THEN
        tokens := rate; -- Start with the max amount of tokens
        last_refill = now();
        raise notice 'Setting up a bucket for user % with % tokens', $1, tokens;
        INSERT INTO token_buckets VALUES ($1, tokens, last_refill);
    END IF;

    -- Calculate newly generated tokens since last call
    extra_tokens := floor(
        EXTRACT(EPOCH FROM (now() - last_refill) * rate / 3600.0)
    )::int;
    this_refill := last_refill + (extra_tokens * interval '1 second' * 3600.0 / rate);
    new_tokens := LEAST(rate, tokens + extra_tokens);
    raise notice 'User % has % tokens, last batch generated at %', $1, new_tokens, this_refill;

    -- If there are no tokens left then we don't need to do anything
    IF new_tokens <= 0 THEN
        RETURN FALSE;
    END IF;

    -- Set new values and return
    UPDATE token_buckets b SET (tokens, last_refill) = (new_tokens - 1, this_refill) WHERE b.user_id = $1;
    RETURN TRUE;
END
$$ LANGUAGE plpgsql;
