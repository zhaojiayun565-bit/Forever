-- Revert an earlier comments attempt. Recreated by 20261011200000_memory_comments.

drop trigger if exists memory_comments_push_trigger on public.memory_comments;
drop function if exists public.notify_memory_comment_push();

do $$
begin
    alter publication supabase_realtime drop table public.memory_comments;
exception
    when undefined_table then null;
    when undefined_object then null;
end;
$$;

drop table if exists public.memory_comments;
