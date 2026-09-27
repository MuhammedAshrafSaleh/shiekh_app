## Confirmed Decisions
- **State management:** Bloc/Cubit (`flutter_bloc`) — Cubit for most screens, full **Bloc for the exam**.
- **Backend gaps:** one **additive companion migration** (student-safe views + `submit_final_exam` RPC).
- **Auth:** email confirmation **ON** (code handles both ON/OFF); `on_auth_user_created` trigger **already exists → verify, don't duplicate**; client does **not** insert the profile row.
- **Media images:** default to one public `media` Storage bucket (confirm at Phase 6) — else paste URL.

---

## ⚠️ Conflicts & Ambiguities (resolved)
| # | Issue | Resolution |
|---|---|---|
| A | `certificates` has **no INSERT policy** | Issue certs inside `submit_final_exam` SECURITY DEFINER RPC |
| B | `correct_choice` client-readable (CC-18) | Student views omit it; base SELECT tightened to `is_admin()`; grade server-side |
| C | Q&A `user_id` exposed (CC-22) | `student_questions_public` view (no user_id); base SELECT → `is_admin()` |
| D | PRD's `handle_new_user` vs schema | Trigger `on_auth_user_created` **exists in live DB** → use it; don't duplicate |
| E | Old setup guide = wrong app | Corrected Sheikhy guide now authoritative |
| F | Email confirm ON vs guide "OFF" | Code handles both; target ON (flip Supabase toggle) |
| G | No Storage bucket, but upload UI | Add one public `media` bucket (admin-write/public-read) or paste URL |
| H | `achievement` notif has no admin path | System-generated on certificate issuance |
| I | Mockups show Google sign-in + photos | Spec wins: email/password only, **initials avatars** |
| J | Mockup brand "Sakinah" | Per-deployment variable; nothing hardcoded |
| K | Docs say 16 tables | Actually **15**; build against those |
| L | Lesson "complete" undefined | ~90% of primary medium **or** tap "الدرس التالي", **and** quiz answered (if any) |
| M | Study-hours/heatmap undefined | Heatmap = daily activity events (progress + attempts) in 4 buckets. **Study hours (revised 2026-09-20):** admin enters per-medium duration manually in minutes (`lessons.video_duration_minutes` / `audio_duration_minutes`, 1..600, nullable); `get_my_study_seconds()` RPC sums completed→full duration, in-progress→`max(video_pos,audio_pos)` capped at known duration. Old flat `completed × 15min` estimate removed. Migrations `0015_lesson_duration.sql` + `0016_lessons_public_duration.sql`. See done-checklist below. |

### Study-hours fix (all 4 steps done — verified on device 2026-09-21)
- [x] **1. DB** — `0015`: per-medium duration columns (1..600, nullable) + `get_my_study_seconds()` RPC (`SECURITY DEFINER`, `revoke` from public/anon, grant to authenticated).
- [x] **2. Achievements** — card computes study time from the RPC (`totalStudySeconds`); `<3600s`→"دقيقة دراسة", `≥3600s`→"ساعة دراسة"; old 15-min getter/constant removed.
- [x] **3. Admin form** — optional video/audio duration fields (minutes), medium-gated, validated 1..600 inline, persisted via the unified lesson save.
- [x] **4. Student tag** — `0016`: durations exposed through `lessons_public` (DROP + CREATE in txn, grants re-applied); duration tag rendered on the student lesson card.
| N | FCM/scheduled sends unspecified | v1 = full in-app notifications; optional topic-based FCM; scheduled = follow-up |

**"Implementer must document" corner cases:**
- **CC-2** unpublish enrolled book → **hide + "غير متاح حاليًا"**, enrollment row persists.
- **CC-11** app closed mid-exam → **persist start; resume remaining time or auto-submit if expired**.
- **CC-20** lesson without enrolling → **require enrollment first** (tap opens enroll dialog).
---

## Backlog / Tech debt
- **Rename `LessonNoteEntity` → `NoteEntity`.** Since the Suggestions feature (2026-09-27), this entity backs both `lesson_notes` and `suggestion_notes` (nullable `lessonId`/`bookId`/`suggestionId`), so the `Lesson`-prefixed name is misleading. Deferred to avoid churn right after the notes-source refactor; purely mechanical (rename class + `lesson_note_entity.dart` file + ~8 imports), behavior-preserving. Related accepted trade-offs kept as-is: `SuggestionNotesRepository` mirrors `NotesRepository` boilerplate (matches the per-repo pattern), and `BookNotesSource.add()` throws `UnsupportedError` (book scope never adds).
