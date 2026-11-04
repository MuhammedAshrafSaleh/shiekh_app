# Edge Functions — deploy & verify_jwt

The AI pipeline is an async job queue. The two user-facing functions only
*enqueue* a row in `public.generation_jobs` and return HTTP 202; the actual
Gemini work is done by `generation-worker`, invoked every 2 minutes by pg_cron
(see `supabase/migrations/0025`–`0028` and `docs/WHITELABEL.md` → "AI job queue").

## verify_jwt per function — THIS IS NOT OPTIONAL

| Function            | verify_jwt | Auth                                         |
|---------------------|:----------:|----------------------------------------------|
| `transcribe-lesson` | **true**   | admin user JWT                               |
| `generate-questions`| **true**   | admin user JWT                               |
| `generation-worker` | **false**  | `x-worker-secret` header (NOT a JWT)         |
| `transcribe-worker` | **false**  | retired tombstone (returns 410); delete it   |

`generation-worker` **must** be deployed with `verify_jwt` OFF. It is called by
pg_cron, not a signed-in user, and authenticates against
`app_secrets.worker_secret` via the `x-worker-secret` header. If it is deployed
with JWT verification ON, every cron call is rejected with 401, no job is ever
claimed, and the queue silently does nothing — the admin UI just shows jobs
stuck at "في الطابور" forever with no error.

## Deploy commands

The CLI defaults to `verify_jwt: true`, so the worker needs `--no-verify-jwt`:

```bash
supabase functions deploy transcribe-lesson    --project-ref <PROJECT_REF>
supabase functions deploy generate-questions   --project-ref <PROJECT_REF>
supabase functions deploy generation-worker     --project-ref <PROJECT_REF> --no-verify-jwt
```

`transcribe-worker` is retired (its claim RPC was dropped in migration 0027).
It cannot be removed through the management API, so delete it from the Supabase
dashboard (Edge Functions → transcribe-worker → Delete) and remove its folder.

## One-time per project: schedule the worker

After the migrations run and `generation-worker` is deployed, create the cron
schedule once (it embeds this project's ref in the URL):

```sql
select cron.schedule(
  'generation-worker',
  '*/2 * * * *',
  $job$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/generation-worker',
    headers := jsonb_build_object(
                 'Content-Type',    'application/json',
                 'x-worker-secret', (select value from public.app_secrets where key = 'worker_secret')
               ),
    body    := '{}'::jsonb,
    timeout_milliseconds := 150000
  )
  $job$
);
```
