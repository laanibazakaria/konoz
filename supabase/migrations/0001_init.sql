-- =====================================================================
-- مسابقة إسلامية — المخطط الأساسي لقاعدة البيانات (Supabase / PostgreSQL)
-- =====================================================================

-- ─────────────────────────── المحتوى ───────────────────────────

-- كل عالم = خلفية (وادٍ، غابة نهارية، أدغال ليلية...)
create table public.worlds (
  id              smallserial primary key,
  name            text not null,
  map_background  text not null,            -- مسار الصورة في التطبيق أو في Storage
  quiz_background text not null,
  sort_order      int  not null unique
);

-- التصنيفات: الصلاة، الأذكار، الأنبياء، القرآن...
create table public.categories (
  id      smallserial primary key,
  name_ar text not null unique
);

create table public.levels (
  id                serial primary key,
  world_id          smallint not null references public.worlds(id),
  number            int not null unique check (number > 0),   -- الترتيب على الخريطة
  title             text,
  coins_per_correct int not null default 10 check (coins_per_correct >= 0),
  is_published      boolean not null default false,
  updated_at        timestamptz not null default now()
);

create type public.question_status as enum ('draft', 'review', 'published');

-- 3 خيارات بالضبط في 3 أعمدة: قاعدة البيانات نفسها تضمن
-- «3 خيارات وإجابة صحيحة واحدة» دون جداول وسيطة أو محفّزات.
create table public.questions (
  id             uuid primary key default gen_random_uuid(),
  level_id       int references public.levels(id) on delete set null,
  position       int not null default 1,
  category_id    smallint references public.categories(id) on delete set null,
  text_ar        text not null check (length(trim(text_ar)) > 0),
  choice_1       text not null check (length(trim(choice_1)) > 0),
  choice_2       text not null check (length(trim(choice_2)) > 0),
  choice_3       text not null check (length(trim(choice_3)) > 0),
  correct_choice smallint not null check (correct_choice between 1 and 3),
  explanation    text,                      -- تظهر بعد الخطأ (هدف تعليمي)
  source_ref     text,                      -- مثال: «صحيح البخاري 6312»
  status         public.question_status not null default 'draft',
  reviewed_by    uuid references auth.users(id) on delete set null,
  updated_at     timestamptz not null default now(),
  constraint choices_distinct check (
    choice_1 <> choice_2 and choice_1 <> choice_3 and choice_2 <> choice_3),
  -- قابل للتأجيل: يسمح بإعادة الترتيب بالسحب والإفلات داخل معاملة واحدة
  constraint questions_level_position_key unique (level_id, position)
    deferrable initially deferred
);
create index questions_published_idx on public.questions (level_id, position)
  where status = 'published';

-- ─────────────────────────── اللاعبون ───────────────────────────

create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  avatar        text,
  coins         int not null default 0 check (coins >= 0),
  role          text not null default 'player' check (role in ('player','editor','admin')),
  created_at    timestamptz not null default now()
);

-- أفضل نتيجة لكل مستوى — هي ما تعرضه الخريطة
create table public.level_progress (
  user_id            uuid references public.profiles(id) on delete cascade,
  level_id           int  references public.levels(id)   on delete cascade,
  best_stars         smallint not null default 0 check (best_stars between 0 and 3),
  best_correct       int not null default 0,
  attempts           int not null default 0,
  first_completed_at timestamptz,
  updated_at         timestamptz not null default now(),
  primary key (user_id, level_id)
);

-- سجلّ المحاولات: للإحصاءات ومعرفة الأسئلة الصعبة
create table public.attempts (
  id            bigserial primary key,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  level_id      int  not null references public.levels(id) on delete cascade,
  answers       smallint[] not null,        -- اختيار اللاعب لكل سؤال (1..3)
  correct       int not null,
  total         int not null,
  stars         smallint not null,
  coins_earned  int not null,
  created_at    timestamptz not null default now()
);
create index attempts_user_idx on public.attempts (user_id, created_at desc);

-- ─────────────────────────── المحفّزات ───────────────────────────

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

create trigger questions_touch before update on public.questions
  for each row execute function public.touch_updated_at();
create trigger levels_touch before update on public.levels
  for each row execute function public.touch_updated_at();

-- إنشاء ملف اللاعب تلقائياً عند التسجيل (بما في ذلك الدخول المجهول)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─────────────────────────── الصلاحيات ───────────────────────────

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and role in ('editor','admin'));
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- المحرّر لا يستطيع نشر سؤال: النشر بعد مراجعة المشرف فقط
create or replace function public.guard_publish() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'published'
     and (tg_op = 'INSERT' or old.status is distinct from 'published')
     and auth.uid() is not null and not public.is_admin() then
    raise exception 'only admins can publish questions';
  end if;
  if new.status = 'published' and (tg_op = 'INSERT' or old.status is distinct from 'published') then
    new.reviewed_by := coalesce(auth.uid(), new.reviewed_by);
  end if;
  return new;
end $$;

create trigger questions_guard_publish before insert or update on public.questions
  for each row execute function public.guard_publish();

alter table public.worlds         enable row level security;
alter table public.categories     enable row level security;
alter table public.levels         enable row level security;
alter table public.questions      enable row level security;
alter table public.profiles       enable row level security;
alter table public.level_progress enable row level security;
alter table public.attempts       enable row level security;

create policy worlds_read   on public.worlds     for select using (true);
create policy worlds_staff  on public.worlds     for all using (public.is_staff()) with check (public.is_staff());
create policy cats_read     on public.categories for select using (true);
create policy cats_staff    on public.categories for all using (public.is_staff()) with check (public.is_staff());

create policy levels_read   on public.levels for select using (is_published or public.is_staff());
create policy levels_staff  on public.levels for all using (public.is_staff()) with check (public.is_staff());

create policy questions_read on public.questions for select using (
  public.is_staff() or (status = 'published' and exists (
    select 1 from public.levels l where l.id = level_id and l.is_published)));
create policy questions_staff on public.questions for all
  using (public.is_staff()) with check (public.is_staff());

create policy profiles_self_read on public.profiles for select using (id = auth.uid() or public.is_staff());
-- اللاعب يغيّر اسمه وصورته فقط (القطع والدور عبر الأعمدة المسموح بها أدناه)
create policy profiles_self_update on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from authenticated, anon;
grant update (display_name, avatar) on public.profiles to authenticated;

create policy progress_self_read on public.level_progress for select using (user_id = auth.uid());
create policy attempts_self_read on public.attempts       for select using (user_id = auth.uid() or public.is_staff());
-- لا كتابة مباشرة في التقدّم أو المحاولات: فقط عبر submit_attempt()

-- ─────────────────── حساب النتيجة على الخادم ───────────────────
-- التطبيق يرسل إجابات اللاعب فقط، والخادم يحسب الصحيح والنجوم والقطع.
create or replace function public.submit_attempt(p_level_id int, p_answers smallint[])
returns table (stars smallint, coins_earned int, correct int, total int, coins_balance int)
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_cpc int; v_total int; v_correct int; v_stars smallint; v_prev smallint; v_coins int;
  v_balance int;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select l.coins_per_correct into v_cpc
    from public.levels l where l.id = p_level_id and l.is_published;
  if not found then raise exception 'level not found'; end if;

  select count(*)::int,
         (count(*) filter (where q.correct_choice = p_answers[q.ord]))::int
    into v_total, v_correct
  from (select qq.correct_choice,
               (row_number() over (order by qq.position, qq.id))::int as ord
          from public.questions qq
         where qq.level_id = p_level_id and qq.status = 'published') q;

  if v_total = 0 or coalesce(array_length(p_answers, 1), 0) <> v_total then
    raise exception 'invalid answers: expected %, got %', v_total, coalesce(array_length(p_answers, 1), 0);
  end if;

  v_stars := case when v_correct = v_total               then 3
                  when v_correct >= ceil(v_total * 0.7) then 2
                  when v_correct >= ceil(v_total * 0.4) then 1
                  else 0 end;

  select lp.best_stars into v_prev from public.level_progress lp
   where lp.user_id = v_uid and lp.level_id = p_level_id;
  v_prev := coalesce(v_prev, 0);

  -- القطع تُمنح فقط عند تحسين النتيجة (لمنع تكرار المستوى نفسه لجمع القطع)
  v_coins := case when v_stars > v_prev then v_correct * v_cpc else 0 end;

  insert into public.profiles (id) values (v_uid) on conflict do nothing;

  insert into public.attempts (user_id, level_id, answers, correct, total, stars, coins_earned)
  values (v_uid, p_level_id, p_answers, v_correct, v_total, v_stars, v_coins);

  insert into public.level_progress as lp
         (user_id, level_id, best_stars, best_correct, attempts, first_completed_at)
  values (v_uid, p_level_id, v_stars, v_correct, 1, case when v_stars > 0 then now() end)
  on conflict (user_id, level_id) do update set
    best_stars         = greatest(lp.best_stars, excluded.best_stars),
    best_correct       = greatest(lp.best_correct, excluded.best_correct),
    attempts           = lp.attempts + 1,
    first_completed_at = coalesce(lp.first_completed_at, excluded.first_completed_at),
    updated_at         = now();

  update public.profiles p set coins = p.coins + v_coins
   where p.id = v_uid returning p.coins into v_balance;

  return query select v_stars, v_coins, v_correct, v_total, v_balance;
end $$;

revoke execute on function public.submit_attempt(int, smallint[]) from public, anon;
grant  execute on function public.submit_attempt(int, smallint[]) to authenticated;

-- إعادة ترتيب أسئلة مستوى (لوحة الإدارة): ids بالترتيب الجديد
create or replace function public.reorder_questions(p_level_id int, p_ids uuid[])
returns void language plpgsql security invoker set search_path = public as $$
begin
  if not public.is_staff() then raise exception 'forbidden'; end if;
  update public.questions q set position = t.ord
    from unnest(p_ids) with ordinality as t(id, ord)
   where q.id = t.id and q.level_id = p_level_id;
end $$;
