-- =====================================================================
-- Clubs become chat rooms + "currently reading" on profiles.
--
-- 1. Profiles get a currently-reading book.
-- 2. posts / comments / reactions are replaced by one `messages` table.
--    A message can be plain text, a quoted passage, an attached book,
--    or any mix of those. Messages stream live to the app (Realtime).
-- 3. Reports now point at messages (or users).
--
-- No data is lost: posts, comments, reactions and reports were never used.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. CURRENTLY READING
-- ---------------------------------------------------------------------

alter table public.profiles
  add column currently_reading_book_id uuid references public.books (id) on delete set null;

grant update (currently_reading_book_id) on public.profiles to authenticated;


-- ---------------------------------------------------------------------
-- 2. REMOVE THE OLD POST MODEL
-- ---------------------------------------------------------------------

drop view if exists public.club_feed;
drop table public.reports;      -- recreated below, pointing at messages
drop table public.reactions;
drop table public.comments;
drop table public.posts;
drop function public.post_club(uuid);
drop function public.auto_hide_reported();


-- ---------------------------------------------------------------------
-- 3. MESSAGES
-- ---------------------------------------------------------------------

create table public.messages (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.book_clubs (id) on delete cascade,
  author_id   uuid not null references public.profiles (id) on delete cascade,
  body        text check (char_length(body) <= 2000),                  -- what they wrote
  quote_text  text check (char_length(quote_text) between 1 and 1000), -- a passage they shared
  book_id     uuid references public.books (id) on delete set null,    -- a book they attached
  is_hidden   boolean not null default false,                          -- set by moderation
  created_at  timestamptz not null default now(),
  edited_at   timestamptz,
  -- A message has to contain something.
  check (
    nullif(btrim(coalesce(body, '')), '') is not null
    or quote_text is not null
    or book_id is not null
  )
);

create index messages_club_recent_idx on public.messages (club_id, created_at desc);
create index messages_author_idx      on public.messages (author_id, created_at desc);

alter table public.messages enable row level security;
revoke all on public.messages from anon;
revoke update on public.messages from authenticated;
grant update (body) on public.messages to authenticated;

create policy "Read messages in clubs you can see, minus hidden and blocked"
  on public.messages for select to authenticated
  using (
    public.can_view_club(club_id)
    and not public.i_blocked(author_id)
    and (not is_hidden or public.is_club_mod(club_id))
  );

create policy "Members send messages as themselves"
  on public.messages for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.is_club_member(club_id)
    and public.has_accepted_guidelines()
  );

create policy "Edit your own messages"
  on public.messages for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());

create policy "Delete your own messages, or moderators delete any"
  on public.messages for delete to authenticated
  using (author_id = auth.uid() or public.is_club_mod(club_id));

-- Chat moves faster than posts did: allow 20 messages a minute.
create or replace function public.enforce_rate_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  recent int;
  max_per_minute int := case TG_TABLE_NAME when 'messages' then 20 else 10 end;
begin
  execute format(
    'select count(*) from public.%I where author_id = $1 and created_at > now() - interval ''1 minute''',
    TG_TABLE_NAME)
  into recent using new.author_id;

  if recent >= max_per_minute then
    raise exception 'You''re sending messages too quickly. Wait a minute and try again.'
      using errcode = 'P0001', hint = 'rate_limit';
  end if;
  return new;
end;
$$;

create trigger word_filter before insert or update on public.messages
  for each row execute function public.enforce_word_filter();
create trigger rate_limit before insert on public.messages
  for each row execute function public.enforce_rate_limit();
create trigger set_edited_at before update of body on public.messages
  for each row execute function public.set_edited_at();

-- Stream new, edited and deleted messages to the app.
alter publication supabase_realtime add table public.messages;


-- ---------------------------------------------------------------------
-- 4. REPORTS (now about messages or people)
-- ---------------------------------------------------------------------

create table public.reports (
  id                uuid primary key default gen_random_uuid(),
  reporter_id       uuid not null references public.profiles (id) on delete cascade,
  message_id        uuid references public.messages (id) on delete cascade,
  reported_user_id  uuid references public.profiles (id) on delete cascade,
  reason            text not null
                      check (reason in ('spam', 'harassment', 'hate', 'sexual', 'violence', 'other')),
  details           text check (char_length(details) <= 1000),
  status            text not null default 'open'
                      check (status in ('open', 'actioned', 'dismissed')),
  created_at        timestamptz not null default now(),
  check (num_nonnulls(message_id, reported_user_id) = 1)
);

create index reports_open_idx on public.reports (status, created_at) where status = 'open';

alter table public.reports enable row level security;
revoke all on public.reports from anon;
revoke update on public.reports from authenticated;

create policy "File a report as yourself"
  on public.reports for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open');

create policy "See your own reports"
  on public.reports for select to authenticated
  using (reporter_id = auth.uid());

-- Hide a message once 3 different people report it, until you review it.
create function public.auto_hide_reported()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.message_id is not null and (
    select count(distinct reporter_id) from public.reports
    where message_id = new.message_id and status = 'open') >= 3 then
    update public.messages set is_hidden = true where id = new.message_id;
  end if;
  return new;
end;
$$;

create trigger auto_hide_reported after insert on public.reports
  for each row execute function public.auto_hide_reported();
