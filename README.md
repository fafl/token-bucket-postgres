This is a small plpgsql function for Postgres that manages a token bucket rate limiter.

# What is a token bucket?

Wikipedia explains it pretty well, it is a mechanism to limit the rate of incoming requests: https://en.wikipedia.org/wiki/Token_bucket

# When do I use this?

Usually you would implement the rate limiting in the load balancer of your web service. If you, like me on cloud foundry, can't do that,
then you can implement it in postgres, so you app will call `SELECT take_token(user_id)` before each request.

This implementation is thread-safe and requires very little memory.

# When do I avoid this?

If you have a lot of requests per second, then postgres will at some point become the bottleneck.
In this case you should keep the buckets in memory and ditch the persistence.

You can figure out the speed on your setup by running this test:
* Make sure you have postgres installed
* Run ```psql -f token_bucket_tables.sql``` to set up the tables
* Run ```psql -f token_bucket_function.sql``` to set up the plpgsql function
* Run ```time python test.py``` to try and fetch 5000 tokens from the local database, where only 3600 are available.

On my machine the last step takes less than two seconds. It would take a bit longer if it were to access postgres over the network. By running it on your setup you should be able to determine if the speed is sufficient.

# How do I install this?

You need an instance of postgres, where you can create the function and the two needed tables `token_rates` and `token_buckets`.
Then you configure the rates by adding rows to `token_rates` as you see fit.

# How do I use this?

Run `SELECT take_token(user_id)` when a request arrives in your app. If it returns true, allow the request. Otherwise return an error code like 429.
