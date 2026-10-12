-- Comment threads on shared (paired) map memories, with a partner push on each new comment.

create table if not exists public.memory_comments (
    id uuid primary key default gen_random_uuid(),
    memory_id uuid not null references public.memories (id) on delete cascade,
    author_id uuid not null references auth.users (id) on delete cascade,
    body text not null check (char_length(btrim(body)) > 0),
    created_at timestamptz not null default now()
);

create index if not exists memory_comments_memory_id_created_at_idx
    on public.memory_comments (memory_id, created_at);

alter table public.memory_comments enable row level security;

-- True when the memory belongs to a couple the caller is part of (solo memories never qualify).
create or replace function public.is_member_of_memory_couple(p_memory_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.memories m
        join public.couples c on c.id = m.couple_id
        where m.id = p_memory_id
          and (c.user1_id = auth.uid() or c.user2_id = auth.uid())
    );
$$;

revoke all on function public.is_member_of_memory_couple(uuid) from public, anon;
grant execute on function public.is_member_of_memory_couple(uuid) to authenticated;

drop policy if exists "Couple members can read memory comments" on public.memory_comments;
create policy "Couple members can read memory comments"
    on public.memory_comments
    for select
    to authenticated
    using (public.is_member_of_memory_couple(memory_id));

drop policy if exists "Couple members can add memory comments" on public.memory_comments;
create policy "Couple members can add memory comments"
    on public.memory_comments
    for insert
    to authenticated
    with check (author_id = auth.uid() and public.is_member_of_memory_couple(memory_id));

drop policy if exists "Authors can delete their memory comments" on public.memory_comments;
create policy "Authors can delete their memory comments"
    on public.memory_comments
    for delete
    to authenticated
    using (author_id = auth.uid());

do $$
begin
    alter publication supabase_realtime add table public.memory_comments;
exception
    when duplicate_object then null;
end;
$$;

create or replace function public.notify_memory_comment_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.invoke_apns_sync(jsonb_build_object(
        'table', 'memory_comments',
        'type', TG_OP,
        'record', to_jsonb(NEW)
    ));
    return NEW;
end;
$$;

drop trigger if exists memory_comments_push_trigger on public.memory_comments;
create trigger memory_comments_push_trigger
    after insert on public.memory_comments
    for each row
    execute function public.notify_memory_comment_push();
