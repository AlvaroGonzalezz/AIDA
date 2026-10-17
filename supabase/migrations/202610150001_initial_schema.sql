-- Esquema inicial de AIDA para Supabase.
-- Ejecutar una sola vez desde el SQL Editor del proyecto.

create table public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text,
    age_range text check (age_range in ('18 - 24', '25 - 34', '35 - 44', '45 - 54', '55+')),
    occupation text,
    occupation_detail text,
    schedule_type text check (schedule_type in ('fixed', 'variable', 'flexible')),
    organization_challenge text,
    extra_context text,
    country text,
    assistant_personality text not null default 'direct'
        check (assistant_personality in ('direct', 'friendly', 'professional', 'motivational')),
    assistant_proactivity text not null default 'medium'
        check (assistant_proactivity in ('low', 'medium', 'high')),
    avatar_path text,
    onboarding_completed_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.tasks (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    title text not null check (char_length(trim(title)) between 1 and 300),
    notes text,
    project text,
    due_date date,
    due_time time,
    estimated_minutes integer check (estimated_minutes is null or estimated_minutes > 0),
    priority text not null default 'normal'
        check (priority in ('low', 'normal', 'high')),
    status text not null default 'pending'
        check (status in ('pending', 'in_progress', 'completed', 'cancelled')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.conversations (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    title text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.messages (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid not null references public.conversations (id) on delete cascade,
    role text not null check (role in ('user', 'assistant')),
    content text not null check (char_length(trim(content)) > 0),
    created_at timestamptz not null default now()
);

create index tasks_user_due_date_idx on public.tasks (user_id, due_date, due_time);
create index tasks_user_status_idx on public.tasks (user_id, status);
create index conversations_user_updated_idx on public.conversations (user_id, updated_at desc);
create index messages_conversation_created_idx on public.messages (conversation_id, created_at);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger tasks_set_updated_at
before update on public.tasks
for each row execute function public.set_updated_at();

create trigger conversations_set_updated_at
before update on public.conversations
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, display_name)
    values (new.id, nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''))
    on conflict (id) do nothing;
    return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

create policy "Users can view their own profile"
on public.profiles for select to authenticated
using ((select auth.uid()) = id);

create policy "Users can create their own profile"
on public.profiles for insert to authenticated
with check ((select auth.uid()) = id);

create policy "Users can update their own profile"
on public.profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "Users can manage their own tasks"
on public.tasks for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can manage their own conversations"
on public.conversations for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can view messages in their conversations"
on public.messages for select to authenticated
using (
    exists (
        select 1
        from public.conversations
        where conversations.id = messages.conversation_id
          and conversations.user_id = (select auth.uid())
    )
);

create policy "Users can add messages to their conversations"
on public.messages for insert to authenticated
with check (
    exists (
        select 1
        from public.conversations
        where conversations.id = messages.conversation_id
          and conversations.user_id = (select auth.uid())
    )
);

create policy "Users can delete messages in their conversations"
on public.messages for delete to authenticated
using (
    exists (
        select 1
        from public.conversations
        where conversations.id = messages.conversation_id
          and conversations.user_id = (select auth.uid())
    )
);

grant usage on schema public to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.tasks to authenticated;
grant select, insert, update, delete on public.conversations to authenticated;
grant select, insert, delete on public.messages to authenticated;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

create policy "Users can view their own avatar files"
on storage.objects for select to authenticated
using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users can upload their own avatar files"
on storage.objects for insert to authenticated
with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users can update their own avatar files"
on storage.objects for update to authenticated
using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Users can delete their own avatar files"
on storage.objects for delete to authenticated
using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
);