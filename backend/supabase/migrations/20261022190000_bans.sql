-- =====================================================================
-- Bans (App Store guideline 1.2: remove users who post offending content)
--
-- * banned_users: accounts an admin has banned. Only changed through the
--   admin functions below; the app can't read or write it directly.
-- * A banned account can't send messages, start clubs or join clubs.
--   (has_accepted_guidelines() now also checks for a ban, and it's
--   already required for sending messages and creating clubs.)
-- * Banning hides all of that person's messages.
-- * moderate_message() gains 'remove_and_ban'.
-- * moderate_user() handles reports about a person: 'dismiss', 'ban', 'unban'.
--
-- Blocking needs no changes: the blocks table and the rule that hides
-- blocked people's messages have existed since the first migration.
-- =====================================================================

create table public.banned_users (
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  banned_by  uuid references public.profiles (id) on delete set null,
  banned_at  timestamptz not null default now()
);

alter table public.banned_users enable row level security;
revoke all on public.banned_users from anon, authenticated;

-- Is the signed-in person banned? (Used by the app to explain why it can't post.)
create function public.is_banned()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.banned_users where user_id = auth.uid());
$$;

revoke execute on function public.is_banned() from public, anon;
grant execute on function public.is_banned() to authenticated;

-- Posting rules: agreed to the guidelines AND not banned.
create or replace function public.has_accepted_guidelines()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and accepted_guidelines_at is not null
  )
  and not exists (select 1 from public.banned_users where user_id = auth.uid());
$$;

-- Banned accounts can't join clubs either.
drop policy "Join a public club" on public.club_members;
create policy "Join a public club"
  on public.club_members for insert to authenticated
  with check (
    user_id = auth.uid()
    and role = 'member'
    and not public.is_banned()
    and exists (select 1 from public.book_clubs c where c.id = club_id and not c.is_private)
  );

-- Internal helper: ban someone and hide everything they've posted.
create function public.ban_user_internal(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.banned_users (user_id, banned_by)
  values (p_user_id, auth.uid())
  on conflict (user_id) do nothing;

  update public.messages set is_hidden = true where author_id = p_user_id;

  update public.reports set status = 'actioned'
  where status = 'open'
    and (reported_user_id = p_user_id
         or message_id in (select id from public.messages where author_id = p_user_id));
end;
$$;

revoke execute on function public.ban_user_internal(uuid) from public, anon, authenticated;

-- Message reports: 'remove', 'keep', and now 'remove_and_ban'.
create or replace function public.moderate_message(p_message_id uuid, p_action text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_author uuid;
begin
  if not public.is_app_admin() then
    raise exception 'Only admins can moderate.' using errcode = '42501';
  end if;

  if p_action = 'remove' then
    update public.messages set is_hidden = true where id = p_message_id;
    update public.reports set status = 'actioned'
      where message_id = p_message_id and status = 'open';
  elsif p_action = 'keep' then
    update public.messages set is_hidden = false where id = p_message_id;
    update public.reports set status = 'dismissed'
      where message_id = p_message_id and status = 'open';
  elsif p_action = 'remove_and_ban' then
    select author_id into v_author from public.messages where id = p_message_id;
    if v_author is null then
      raise exception 'Message not found.';
    end if;
    perform public.ban_user_internal(v_author);
  else
    raise exception 'Unknown moderation action: %', p_action;
  end if;
end;
$$;

-- Reports about a person: 'dismiss', 'ban', 'unban'.
create function public.moderate_user(p_user_id uuid, p_action text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_app_admin() then
    raise exception 'Only admins can moderate.' using errcode = '42501';
  end if;

  if p_action = 'dismiss' then
    update public.reports set status = 'dismissed'
      where reported_user_id = p_user_id and status = 'open';
  elsif p_action = 'ban' then
    perform public.ban_user_internal(p_user_id);
  elsif p_action = 'unban' then
    delete from public.banned_users where user_id = p_user_id;
  else
    raise exception 'Unknown moderation action: %', p_action;
  end if;
end;
$$;

revoke execute on function public.moderate_user(uuid, text) from public, anon;
grant execute on function public.moderate_user(uuid, text) to authenticated;
