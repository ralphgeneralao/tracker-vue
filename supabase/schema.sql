create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_url text,
  habits jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  constraint profiles_habits_must_be_array
    check (jsonb_typeof(habits) = 'array')
);

alter table public.profiles enable row level security;

revoke all on table public.profiles from anon;
grant select, insert, update on table public.profiles to authenticated;

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "Users can create their own profile" on public.profiles;
create policy "Users can create their own profile"
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create table if not exists public.habits (
  user_id uuid not null references auth.users (id) on delete cascade,
  id text not null,
  name text not null,
  icon text not null,
  color text not null,
  completions date[] not null default '{}',
  expected_finish_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

alter table public.habits enable row level security;

revoke all on table public.habits from anon;
grant select, insert, update, delete on table public.habits to authenticated;

drop policy if exists "Users can read their own habits" on public.habits;
create policy "Users can read their own habits"
  on public.habits for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own habits" on public.habits;
create policy "Users can create their own habits"
  on public.habits for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own habits" on public.habits;
create policy "Users can update their own habits"
  on public.habits for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own habits" on public.habits;
create policy "Users can delete their own habits"
  on public.habits for delete
  to authenticated
  using ((select auth.uid()) = user_id);

insert into public.habits (
  user_id,
  id,
  name,
  icon,
  color,
  completions,
  expected_finish_at
)
select
  profiles.id,
  habit.value->>'id',
  coalesce(nullif(habit.value->>'name', ''), 'Untitled habit'),
  coalesce(nullif(habit.value->>'icon', ''), '✳'),
  coalesce(nullif(habit.value->>'color', ''), 'green'),
  case
    when jsonb_typeof(habit.value->'completions') = 'array' then
      array(
        select completion::date
        from jsonb_array_elements_text(habit.value->'completions') as item(completion)
      )
    else '{}'
  end,
  case
    when habit.value->>'expectedFinishAt' ~ '^\d{4}-\d{2}-\d{2}T'
      then (habit.value->>'expectedFinishAt')::timestamptz
    else null
  end
from public.profiles as profiles
cross join lateral jsonb_array_elements(profiles.habits) as habit(value)
where jsonb_typeof(profiles.habits) = 'array'
  and nullif(habit.value->>'id', '') is not null
on conflict (user_id, id) do nothing;

update public.profiles
set habits = '[]'::jsonb
where habits <> '[]'::jsonb;

create table if not exists public.debts (
  user_id uuid not null references auth.users (id) on delete cascade,
  id uuid not null,
  debtor_name text not null check (length(trim(debtor_name)) > 0),
  amount numeric(12, 2) not null check (amount > 0),
  expected_payment_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

alter table public.debts enable row level security;

revoke all on table public.debts from anon;
grant select, insert, update, delete on table public.debts to authenticated;

drop policy if exists "Users can read their own debts" on public.debts;
create policy "Users can read their own debts"
  on public.debts for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own debts" on public.debts;
create policy "Users can create their own debts"
  on public.debts for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own debts" on public.debts;
create policy "Users can update their own debts"
  on public.debts for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own debts" on public.debts;
create policy "Users can delete their own debts"
  on public.debts for delete
  to authenticated
  using ((select auth.uid()) = user_id);
