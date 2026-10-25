
✅ Run

> **Note:** `handle_new_user()` and the `on_auth_user_created` trigger are now
> created automatically by `supabase/migrations/0000_baseline.sql`.
> The manual step below is **no longer required** when installing from the
> migration stack.  It is retained here for reference only.

---

### 5.4 Trigger مزامنة auth.users مع public.users *(automated by 0000_baseline.sql)*

```sql
-- This is now created by supabase/migrations/0000_baseline.sql.
-- Do NOT run manually when installing from the migration stack.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
    new.email,
    'student'
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```