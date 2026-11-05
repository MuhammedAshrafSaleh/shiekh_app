# AI job queue — why it exists and why its numbers are what they are

Covers lesson transcription and quiz-question generation. Read this before
changing anything in `supabase/functions/generation-worker/` or migrations
`0025`–`0028`. Every constant below was derived from measurement, not taste.

---

## 1. What the system does

Neither AI operation runs inside the Edge Function request any more.

```
app → transcribe-lesson  ─┐
                          ├─→ inserts a row in generation_jobs (status='queued')
app → generate-questions ─┘   and returns 202 {job_id, status} in ~1–2s

pg_cron (*/2 min) → generation-worker
                      ├─ claim_generation_job()  — one job, atomically
                      ├─ ONE Gemini attempt
                      └─ success → write result, status='done'
                         transient failure → status='queued',
                                             next_attempt_at = now() + backoff
                         permanent failure → status='failed'

app ← Supabase Realtime on lessons + generation_jobs (15s poll as fallback)
```

The admin can close the app at any point. All state lives in the database, so
reopening the screen shows the truth.

---

## 2. Why it had to change

### 2.1 Two separate bugs, found 2026-11-03

**Bug A — wrong MIME type sent to Gemini (fixed).**
Google Drive serves many files as `application/octet-stream`. The old code
passed that straight through as `mime_type`. Gemini could not take the audio
path (~32 tokens/second) and instead tried to tokenize the raw bytes:

```
400 INVALID_ARGUMENT
"The input token count exceeds the maximum number of tokens allowed 1048576."
```

Fix: never trust Drive's `Content-Type`; derive the MIME from the filename in
`Content-Disposition`, defaulting to `audio/mpeg`. See `resolveAudioMime()`.

This also explains the deployment history: Ahmed's lectures are `.mp3`, which
Drive labels `audio/mpeg` correctly, so the old code worked there. Medhat's are
`.ogg`, which Drive labels `application/octet-stream`, so it never worked.

**Bug B — the work does not fit in one request (the reason for this queue).**

Measured on the live Ahmed project before the change:

| job type | done | failed | notes |
|---|---|---|---|
| `generate_questions` | 15 | 10 | **38% failure**; slowest SUCCESS 149s against a ~150s platform wall clock; 86s average |
| `transcribe` | 14 | 4 | plus 3 jobs stuck at `running` forever |

There was no room for a second attempt inside one invocation. Shortening the
backoff could not help.

### 2.2 The stuck-`running` class of bug

When the platform kills a function at the wall clock, the `catch` block never
runs. The old design left `lessons.transcript_status = 'running'` forever and
the lesson could not be retried. `claim_generation_job()` now reaps anything
left `running` for more than 5 minutes.

---

## 3. Why the retry budget is 52 attempts over ~47 hours

On the **Gemini free tier**, long audio is frequently refused:

```
503 UNAVAILABLE
"This model is currently experiencing high demand."
```

Measured overnight 2026-11-03 → 04:
**24 consecutive attempts over 7 hours, every one a 503**, across all three
models in `MODEL_FALLBACK`, including 00:00, 01:00, 02:00 and 04:00 local.

Two conclusions, both load-bearing:

1. **There is no "quiet hour".** The overnight run above covered midnight,
   01:00, 02:00 and 04:00 and failed at every one. A budget that expires
   before a full day/night cycle will lose a whole lecture on a bad night.
2. **Capacity does come back.** A 44-minute mp3 succeeded on attempt 4 after
   24 minutes earlier the same day, and Ahmed's project has 14 historical
   successes. So retrying is worth doing — it is not hopeless, it is slow.

### The measurement that set the final number

On 2026-11-04 a transcription was queued at 21:15 and **succeeded on attempt 10
at 01:39** — 4 hours 23 minutes of refusals before capacity opened.

So capacity returns in windows that are **hours** apart and unrelated to time of
day. A budget has to outlast a bad stretch, not a bad hour.

Hence:

```ts
const MAX_ATTEMPTS = 52;
const BACKOFF_MIN  = [2, 5, 10, 20, 30]; // then 60 for every later attempt
```

That is ~47 hours — two full day/night cycles. The first hour of quick retries
catches ordinary transient failures; hourly after that is frequent enough to
land in a capacity window when one opens.

The budget was widened **12 → 24 → 52** as each measurement came in. Every
increase was a response to observed data, not a guess.

**Do not shorten this without new measurements.** An earlier draft used 5
attempts over ~1 hour; against the numbers above it would have failed every
time. Each attempt is one request and a 503 consumes no token quota, so the
cost of a wide budget is close to zero.

### Question generation is not exempt

On 2026-11-05 at 11:31 a `generate_questions` job — plain text input, no audio —
also received a 503 on its first attempt. The free tier throttles by capacity,
not by payload size, so both job types share the same budget.

---

## 4. Why failures are classified

`PermanentError` vs ordinary `Error` decides whether a job is retried.

| kind | examples | behaviour |
|---|---|---|
| permanent | 400, 401, 403, missing Gemini key, bad Drive link, Drive warning page, DB insert rejected | fail immediately, **no retry** |
| transient | 503, 429, 500, network error, attempt deadline | re-queue with backoff |

Retrying a 400 cannot succeed and only burns the free tier's request budget.

---

## 5. Cost, and the one change that makes this fast

A client who enables **billing** on their own Gemini key gets served instead of
rationed, and jobs typically finish on the first attempt — roughly **2–4
minutes** end to end instead of hours or never.

At Gemini Flash pricing as of 2026-11 ($0.75 / 1M input, $3.75 / 1M output),
a one-hour lecture costs about **$0.20** for transcript plus questions
(~115k audio input tokens at 32 tokens/second, ~25k output tokens).
Those prices double on 2027-01-01.

This is a **per-client** decision: every sheikh has his own Supabase project
and his own Gemini key, so each can choose independently. The system works
either way; billing only changes how long the queue takes.

---

## 6. Operational notes

- `generation-worker` must be deployed with **`verify_jwt: false`**. It is
  called by `pg_cron`, not a signed-in user, and authenticates with the
  `x-worker-secret` header checked against `app_secrets.worker_secret`.
  Getting this wrong breaks the queue **silently** — jobs enqueue and nothing
  ever claims them.
- The cron schedule embeds the project ref in a URL, so it must be created
  once per client. See `docs/WHITELABEL.md`, "AI job queue".
- `lessons` and `generation_jobs` must be in the `supabase_realtime`
  publication, and `generation_jobs` needs `REPLICA IDENTITY FULL`. Without
  these the admin UI never updates on its own and looks broken.
- `supabase/functions/transcribe-worker/` is a **tombstone** returning 410.
  It was the transcribe-only predecessor of `generation-worker`. Edge
  Functions cannot be deleted via the management API; delete it in the
  dashboard and remove the folder.

### Diagnosing a stalled queue

```sql
select job_type, status, attempts, next_attempt_at, left(error_message, 120)
from public.generation_jobs
order by created_at desc limit 10;
```

- `attempts` stays 0 → the cron is not reaching the worker. Check the function
  name, the project ref in the schedule, and `verify_jwt`.
- `attempts` climbing with 503s → Gemini capacity. Working as designed; see §3.
- `status = 'running'` for over 5 minutes → a worker was killed; the next
  claim reaps it automatically.

The worker logs one line per attempt, prefixed `[worker]`, including the model,
HTTP status, call duration and the upstream error body.
