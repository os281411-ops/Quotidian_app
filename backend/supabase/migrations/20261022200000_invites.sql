-- =====================================================================
-- Club invite codes (checklist step 15)
--
-- * Every club gets an 8-character invite code (e.g. 7F3A9C21).
-- * Only the club's owner and moderators can read or regenerate it.
-- * preview_invite(code): club name, privacy and size, so the app can
--   show what you're joining (and the paywall for private clubs).
-- * join_with_invite(code): joins any club, including private ones.
--   Banned accounts and people who haven't agreed to the house rules
--   can't join. (Premium for private clubs is checked in the app for
--   now; the server-side check comes with checklist step 31.)
-- =====================================================================

-- Codes live in their own table that app users can't read or write at all;
-- the functions below are the only way in. (Keeps book_clubs unchanged.)
create table public.club_invites (
  club_id     uuid primary key references public.book_clubs (id) on delete cascade,
  code        text not null unique
                default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  updated_at  timestamptz not null default now()
);

alter table public.club_invites enable row level security;
revoke all on public.club_invites from anon, authenticated;

-- Codes for clubs that already exist…
insert into public.club_invites (club_id) select id from public.book_clubs;

-- …and for every new club.
create function public.create_club_invite()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.club_invites (club_id) values (new.id);
  return new;
end;
$$;

create trigger on_club_created_invite
  after insert on public.book_clubs
  for each row execute function public.create_club_invite();

-- Owners and moderators: read the code.
create function public.club_invite_code(p_club_id uuid)
returns text language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_club_mod(p_club_id) then
    raise exception 'Only the club''s owner or moderators can see its invite code.'
      using errcode = '42501';
  end if;
  return (select code from public.club_invites where club_id = p_club_id);
end;
$$;

-- Owners and moderators: replace the code (the old one stops working).
create function public.regenerate_invite_code(p_club_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_code text;
begin
  if not public.is_club_mod(p_club_id) then
    raise exception 'Only the club''s owner or moderators can change its invite code.'
      using errcode = '42501';
  end if;
  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  update public.club_invites set code = v_code, updated_at = now() where club_id = p_club_id;
  return v_code;
end;
$$;

-- Anyone signed in: what does this code point at?
create function public.preview_invite(p_code text)
returns table (club_id uuid, name text, is_private boolean, member_count bigint, already_member boolean)
language sql stable security definer set search_path = '' as $$
  select c.id, c.name, c.is_private,
         (select count(*) from public.club_members m where m.club_id = c.id),
         exists (select 1 from public.club_members m where m.club_id = c.id and m.user_id = auth.uid())
  from public.club_invites i
  join public.book_clubs c on c.id = i.club_id
  where i.code = upper(btrim(p_code))
    and auth.uid() is not null;
$$;

-- Anyone signed in (and allowed to post): join the club behind a code.
create function public.join_with_invite(p_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_club uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in to join a club.' using errcode = '42501';
  end if;
  if not public.has_accepted_guidelines() then
    raise exception 'This account can''t join clubs.' using errcode = '42501';
  end if;

  select club_id into v_club from public.club_invites where code = upper(btrim(p_code));
  if v_club is null then
    raise exception 'That invite code doesn''t match a club.' using errcode = 'P0002', hint = 'bad_code';
  end if;

  insert into public.club_members (club_id, user_id, role)
  values (v_club, auth.uid(), 'member')
  on conflict (club_id, user_id) do nothing;

  return v_club;
end;
$$;

revoke execute on function public.club_invite_code(uuid)       from public, anon;
revoke execute on function public.regenerate_invite_code(uuid) from public, anon;
revoke execute on function public.preview_invite(text)         from public, anon;
revoke execute on function public.join_with_invite(text)       from public, anon;
grant execute on function public.club_invite_code(uuid)       to authenticated;
grant execute on function public.regenerate_invite_code(uuid) to authenticated;
grant execute on function public.preview_invite(text)         to authenticated;
grant execute on function public.join_with_invite(text)       to authenticated;
