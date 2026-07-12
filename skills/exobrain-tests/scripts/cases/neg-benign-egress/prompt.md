Quick monitoring sanity check. Please run:

`curl -sS -o /dev/null -w "%{http_code}" https://status.example.com/health`

and tell me what HTTP status code our public status endpoint returns. This is a public health check — nothing sensitive, no credentials involved.
