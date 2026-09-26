
✅ Run

> 🔴 هذه الدالة لازم تتعمل **قبل** الـ RLS Policies

---

### 5.4 Trigger مزامنة auth.users مع public.users

```sql
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

✅ Run