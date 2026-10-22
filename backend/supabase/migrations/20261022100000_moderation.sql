-- =====================================================================
-- Moderation (checklist A13 / step 25)
--
-- * app_admins: who can moderate. Add yourself once in the SQL Editor:
--     insert into public.app_admins (user_id) values ('<your user id>');
--   (Developer Menu → Copy My User ID). Nobody can add themselves from
--   the app: the table has no access rules for app users at all.
-- * Admins can read every report and every reported message, including
--   hidden messages and private clubs.
-- * moderate_message(): the only way to act on reports.
--     'remove' → message stays hidden, its reports are marked actioned
--     'keep'   → message is un-hidden, its reports are dismissed
-- * Fix: the word filter only re-checks a message when its text changes,
--   so hiding an old message can't be blocked by a newly banned word.
-- =====================================================================

create table public.app_admins (
  user_id   uuid primary key references public.profiles (id) on delete cascade,
  added_at  timestamptz not null default now()
);

alter table public.app_admins enable row level security;
revoke all on public.app_admins from anon, authenticated;

create function public.is_app_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid());
$$;

revoke execute on function public.is_app_admin() from public, anon;
grant execute on function public.is_app_admin() to authenticated;

-- Admins can see everything they need to review reports.
create policy "Admins read all reports"
  on public.reports for select to authenticated
  using (public.is_app_admin());

create policy "Admins read all messages"
  on public.messages for select to authenticated
  using (public.is_app_admin());

create policy "Admins read all clubs"
  on public.book_clubs for select to authenticated
  using (public.is_app_admin());

create function public.moderate_message(p_message_id uuid, p_action text)
returns void language plpgsql security definer set search_path = '' as $$
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
  else
    raise exception 'Unknown moderation action: %', p_action;
  end if;
end;
$$;

revoke execute on function public.moderate_message(uuid, text) from public, anon;
grant execute on function public.moderate_message(uuid, text) to authenticated;

-- Only re-run the word filter when a message's text actually changes.
drop trigger word_filter on public.messages;
create trigger word_filter before insert or update of body, quote_text on public.messages
  for each row execute function public.enforce_word_filter();
