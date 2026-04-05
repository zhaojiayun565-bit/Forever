-- Lookup partner id by code without exposing all profiles (SECURITY DEFINER).
create or replace function public.find_partner_by_pairing_code(p_code text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.profiles p
  where p.pairing_code is not null
    and p.pairing_code = trim(p_code)
    and p.id <> auth.uid()
  limit 1;
$$;

revoke all on function public.find_partner_by_pairing_code(text) from public;
grant execute on function public.find_partner_by_pairing_code(text) to authenticated;
