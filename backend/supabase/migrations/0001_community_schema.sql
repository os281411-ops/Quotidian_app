-- =====================================================================
-- Quotidian Community — database schema (Step 1)
-- Book clubs, members, quote posts, comments, reactions,
-- plus the safety features the App Store requires (report, block,
-- word filter) and basic spam protection.
--
-- How to use: Supabase dashboard → SQL Editor → New query →
-- paste this whole file → Run. Run it once on a fresh project.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------

-- One row per user. Created automatically when someone signs in
-- for the first time (see trigger in section 4).
create table public.profiles (
  id                      uuid primary key references auth.users (id) on delete cascade,
  username                text unique
                            check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name            text check (char_length(display_name) <= 40),
  avatar_url              text,
  -- Set when the user agrees to the community guidelines.
  -- Nobody can post or create a club until this is set.
  accepted_guidelines_at  timestamptz,
  created_at              timestamptz not null default now()
);

-- Books people discuss. Filled from Open Library / Google Books search.
create table public.books (
  id               uuid primary key default gen_random_uuid(),
  title            text not null check (char_length(title) between 1 and 300),
  author           text check (char_length(author) <= 200),
  isbn13           text unique check (isbn13 ~ '^[0-9]{13}$'),
  open_library_id  text unique,
  cover_url        text,
  created_at       timestamptz not null default now()
);

create table public.book_clubs (
  id               uuid primary key default gen_random_uuid(),
  name             text not null check (char_length(name) between 3 and 60),
  description      text check (char_length(description) <= 500),
  is_private       boolean not null default false,
  current_book_id  uuid references public.books (id) on delete set null,
  -- If the owner deletes their account the club survives without an owner.
  owner_id         uuid references public.profiles (id) on delete set null,
  created_at       timestamptz not null default now()
);

create table public.club_members (
  club_id    uuid not null references public.book_clubs (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  role       text not null default 'member'
               check (role in ('owner', 'moderator', 'member')),
  joined_at  timestamptz not null default now(),
  primary key (club_id, user_id)
);

-- A quote someone shares into a club, with their own thoughts.
create table public.posts (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.book_clubs (id) on delete cascade,
  author_id   uuid not null references public.profiles (id) on delete cascade,
  book_id     uuid references public.books (id) on delete set null,
  quote_text  text not null check (char_length(quote_text) between 1 and 1000),
  page_ref    text check (char_length(page_ref) <= 40),   -- e.g. "p. 112" or "Ch. 4"
  commentary  text check (char_length(commentary) <= 2000),
  is_hidden   boolean not null default false,              -- set by moderation
  created_at  timestamptz not null default now(),
  edited_at   timestamptz
);

create table public.comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.posts (id) on delete cascade,
  author_id   uuid not null references public.profiles (id) on delete cascade,
  parent_id   uuid references public.comments (id) on delete cascade,  -- for replies
  body        text not null check (char_length(body) between 1 and 2000),
  is_hidden   boolean not null default false,
  created_at  timestamptz not null default now(),
  edited_at   timestamptz
);

-- "Resonated" / like on a post. One per user per post.
create table public.reactions (
  post_id     uuid not null references public.posts (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- App Store guideline 1.2: users must be able to report content.
create table public.reports (
  id                uuid primary key default gen_random_uuid(),
  reporter_id       uuid not null references public.profiles (id) on delete cascade,
  post_id           uuid references public.posts (id) on delete cascade,
  comment_id        uuid references public.comments (id) on delete cascade,
  reported_user_id  uuid references public.profiles (id) on delete cascade,
  reason            text not null
                      check (reason in ('spam', 'harassment', 'hate', 'sexual', 'violence', 'other')),
  details           text check (char_length(details) <= 1000),
  status            text not null default 'open'
                      check (status in ('open', 'actioned', 'dismissed')),
  created_at        timestamptz not null default now(),
  -- Each report is about exactly one thing.
  check (num_nonnulls(post_id, comment_id, reported_user_id) = 1)
);

-- App Store guideline 1.2: users must be able to block abusive users.
create table public.blocks (
  blocker_id  uuid not null references public.profiles (id) on delete cascade,
  blocked_id  uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- Word filter list. Only you (via the dashboard) can edit it.
-- Add terms in the Table Editor, one word or phrase per row, lowercase.
create table public.blocked_terms (
  term  text primary key check (term = lower(term) and char_length(term) > 0)
);

-- Indexes for the queries the app will run most.
create index posts_club_feed_idx     on public.posts (club_id, created_at desc);
create index posts_author_idx        on public.posts (author_id, created_at desc);
create index comments_post_idx       on public.comments (post_id, created_at);
create index comments_author_idx     on public.comments (author_id, created_at desc);
create index club_members_user_idx   on public.club_members (user_id);
create index reports_open_idx        on public.reports (status, created_at) where status = 'open';
create index book_clubs_public_idx   on public.book_clubs (created_at desc) where not is_private;


-- ---------------------------------------------------------------------
-- 2. HELPER FUNCTIONS (used by the access rules below)
--    "security definer" lets them look across tables without the
--    access rules calling themselves in a loop.
-- ---------------------------------------------------------------------

create function public.club_role(p_club uuid)
returns text language sql stable security definer set search_path = '' as $$
  select role from public.club_members
  where club_id = p_club and user_id = auth.uid();
$$;

create function public.is_club_member(p_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.club_members
    where club_id = p_club and user_id = auth.uid()
  );
$$;

create function public.is_club_mod(p_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.club_role(p_club) in ('owner', 'moderator'), false);
$$;

-- Public clubs are visible to everyone signed in; private ones only to members.
create function public.can_view_club(p_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.book_clubs c
    where c.id = p_club
      and (not c.is_private or public.is_club_member(c.id))
  );
$$;

create function public.has_accepted_guidelines()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and accepted_guidelines_at is not null
  );
$$;

-- True if the signed-in user has blocked this person.
create function public.i_blocked(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.blocks
    where blocker_id = auth.uid() and blocked_id = p_user
  );
$$;

create function public.post_club(p_post uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select club_id from public.posts where id = p_post;
$$;


-- ---------------------------------------------------------------------
-- 3. ACCESS RULES (Row Level Security)
--    These run on the server, so a modified app can't get around them.
-- ---------------------------------------------------------------------

alter table public.profiles       enable row level security;
alter table public.books          enable row level security;
alter table public.book_clubs     enable row level security;
alter table public.club_members   enable row level security;
alter table public.posts          enable row level security;
alter table public.comments       enable row level security;
alter table public.reactions      enable row level security;
alter table public.reports        enable row level security;
alter table public.blocks         enable row level security;
alter table public.blocked_terms  enable row level security;  -- no policies = app can't touch it

-- Signed-out visitors get nothing.
revoke all on public.profiles, public.books, public.book_clubs, public.club_members,
              public.posts, public.comments, public.reactions, public.reports,
              public.blocks, public.blocked_terms
  from anon;
revoke all on public.blocked_terms from authenticated;

-- Only allow editing the columns users should be able to change.
-- (Stops someone un-hiding their own moderated post, or moving it to another club.)
revoke update on public.profiles, public.book_clubs, public.club_members,
                 public.posts, public.comments, public.books, public.reports
  from authenticated;
grant update (username, display_name, avatar_url, accepted_guidelines_at) on public.profiles     to authenticated;
grant update (name, description, is_private, current_book_id)             on public.book_clubs   to authenticated;
grant update (role)                                                       on public.club_members to authenticated;
grant update (quote_text, page_ref, commentary)                           on public.posts        to authenticated;
grant update (body)                                                       on public.comments     to authenticated;

-- PROFILES ---------------------------------------------------------------
create policy "Signed-in users can see profiles"
  on public.profiles for select to authenticated
  using (true);

create policy "Users edit their own profile"
  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- BOOKS -----------------------------------------------------------------
create policy "Signed-in users can see books"
  on public.books for select to authenticated
  using (true);

create policy "Signed-in users can add books"
  on public.books for insert to authenticated
  with check (true);

-- BOOK CLUBS ------------------------------------------------------------
create policy "See public clubs and clubs you belong to"
  on public.book_clubs for select to authenticated
  using (not is_private or public.is_club_member(id));

create policy "Create a club as yourself"
  on public.book_clubs for insert to authenticated
  with check (owner_id = auth.uid() and public.has_accepted_guidelines());

create policy "Owners and moderators edit club details"
  on public.book_clubs for update to authenticated
  using (public.is_club_mod(id)) with check (public.is_club_mod(id));

create policy "Owners delete their club"
  on public.book_clubs for delete to authenticated
  using (public.club_role(id) = 'owner');

-- CLUB MEMBERS ----------------------------------------------------------
create policy "See members of clubs you can see"
  on public.club_members for select to authenticated
  using (public.can_view_club(club_id));

-- Joining is for public clubs only. Private clubs get invites later.
create policy "Join a public club"
  on public.club_members for insert to authenticated
  with check (
    user_id = auth.uid()
    and role = 'member'
    and exists (select 1 from public.book_clubs c where c.id = club_id and not c.is_private)
  );

create policy "Leave a club, or moderators remove members"
  on public.club_members for delete to authenticated
  using (
    (user_id = auth.uid() and role <> 'owner')
    or (public.is_club_mod(club_id) and role = 'member')
  );

create policy "Owners promote or demote moderators"
  on public.club_members for update to authenticated
  using (public.club_role(club_id) = 'owner' and role <> 'owner')
  with check (role in ('moderator', 'member'));

-- POSTS -----------------------------------------------------------------
create policy "See posts in clubs you can see, minus hidden and blocked"
  on public.posts for select to authenticated
  using (
    public.can_view_club(club_id)
    and not public.i_blocked(author_id)
    and (not is_hidden or public.is_club_mod(club_id))
  );

create policy "Members post as themselves"
  on public.posts for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.is_club_member(club_id)
    and public.has_accepted_guidelines()
  );

create policy "Edit your own posts"
  on public.posts for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());

create policy "Delete your own posts, or moderators delete any"
  on public.posts for delete to authenticated
  using (author_id = auth.uid() or public.is_club_mod(club_id));

-- COMMENTS --------------------------------------------------------------
create policy "See comments on posts you can see, minus hidden and blocked"
  on public.comments for select to authenticated
  using (
    public.can_view_club(public.post_club(post_id))
    and not public.i_blocked(author_id)
    and (not is_hidden or public.is_club_mod(public.post_club(post_id)))
  );

create policy "Members comment as themselves"
  on public.comments for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.is_club_member(public.post_club(post_id))
    and public.has_accepted_guidelines()
  );

create policy "Edit your own comments"
  on public.comments for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());

create policy "Delete your own comments, or moderators delete any"
  on public.comments for delete to authenticated
  using (author_id = auth.uid() or public.is_club_mod(public.post_club(post_id)));

-- REACTIONS -------------------------------------------------------------
create policy "See reactions on posts you can see"
  on public.reactions for select to authenticated
  using (public.can_view_club(public.post_club(post_id)));

create policy "Members react as themselves"
  on public.reactions for insert to authenticated
  with check (user_id = auth.uid() and public.is_club_member(public.post_club(post_id)));

create policy "Remove your own reaction"
  on public.reactions for delete to authenticated
  using (user_id = auth.uid());

-- REPORTS ---------------------------------------------------------------
-- Users can file reports and see their own. You review them in the dashboard.
create policy "File a report as yourself"
  on public.reports for insert to authenticated
  with check (reporter_id = auth.uid() and status = 'open');

create policy "See your own reports"
  on public.reports for select to authenticated
  using (reporter_id = auth.uid());

-- BLOCKS ----------------------------------------------------------------
create policy "See who you've blocked"
  on public.blocks for select to authenticated
  using (blocker_id = auth.uid());

create policy "Block someone"
  on public.blocks for insert to authenticated
  with check (blocker_id = auth.uid());

create policy "Unblock someone"
  on public.blocks for delete to authenticated
  using (blocker_id = auth.uid());


-- ---------------------------------------------------------------------
-- 4. AUTOMATIC BEHAVIOUR (triggers)
-- ---------------------------------------------------------------------

-- Create an empty profile the first time someone signs in.
-- The app then asks them to pick a username.
create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Whoever creates a club becomes its owner member.
create function public.add_owner_membership()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.owner_id is not null then
    insert into public.club_members (club_id, user_id, role)
    values (new.id, new.owner_id, 'owner');
  end if;
  return new;
end;
$$;

create trigger on_club_created
  after insert on public.book_clubs
  for each row execute function public.add_owner_membership();

-- Word filter: rejects text containing any term in blocked_terms.
create function public.enforce_word_filter()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  content text;
  r jsonb := to_jsonb(new);
begin
  content := lower(concat_ws(' ',
    r->>'quote_text', r->>'commentary', r->>'body',
    r->>'name', r->>'description', r->>'username', r->>'display_name'));

  if exists (
    select 1 from public.blocked_terms t
    where content ~ ('\m' || regexp_replace(t.term, '([.^$*+?()\[\]{}|\\])', '\\\1', 'g') || '\M')
  ) then
    raise exception 'This contains language that isn''t allowed in the community.'
      using errcode = 'P0001', hint = 'word_filter';
  end if;
  return new;
end;
$$;

create trigger word_filter before insert or update on public.posts
  for each row execute function public.enforce_word_filter();
create trigger word_filter before insert or update on public.comments
  for each row execute function public.enforce_word_filter();
create trigger word_filter before insert or update on public.book_clubs
  for each row execute function public.enforce_word_filter();
create trigger word_filter before insert or update on public.profiles
  for each row execute function public.enforce_word_filter();

-- Spam protection: max 5 posts or 10 comments per user per minute.
create function public.enforce_rate_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  recent int;
  max_per_minute int := case TG_TABLE_NAME when 'posts' then 5 else 10 end;
begin
  execute format(
    'select count(*) from public.%I where author_id = $1 and created_at > now() - interval ''1 minute''',
    TG_TABLE_NAME)
  into recent using new.author_id;

  if recent >= max_per_minute then
    raise exception 'You''re posting too quickly. Wait a minute and try again.'
      using errcode = 'P0001', hint = 'rate_limit';
  end if;
  return new;
end;
$$;

create trigger rate_limit before insert on public.posts
  for each row execute function public.enforce_rate_limit();
create trigger rate_limit before insert on public.comments
  for each row execute function public.enforce_rate_limit();

-- Record when a post or comment was edited.
create function public.set_edited_at()
returns trigger language plpgsql as $$
begin
  new.edited_at := now();
  return new;
end;
$$;

create trigger set_edited_at before update of quote_text, page_ref, commentary on public.posts
  for each row execute function public.set_edited_at();
create trigger set_edited_at before update of body on public.comments
  for each row execute function public.set_edited_at();

-- Auto-hide a post or comment once 3 different people report it.
-- It stays hidden until you review it (set is_hidden = false in the dashboard).
create function public.auto_hide_reported()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.post_id is not null and (
    select count(distinct reporter_id) from public.reports
    where post_id = new.post_id and status = 'open') >= 3 then
    update public.posts set is_hidden = true where id = new.post_id;
  end if;

  if new.comment_id is not null and (
    select count(distinct reporter_id) from public.reports
    where comment_id = new.comment_id and status = 'open') >= 3 then
    update public.comments set is_hidden = true where id = new.comment_id;
  end if;
  return new;
end;
$$;

create trigger auto_hide_reported after insert on public.reports
  for each row execute function public.auto_hide_reported();


-- ---------------------------------------------------------------------
-- 5. CONVENIENCE VIEW for the club feed
--    Each post with author name, book title, comment and reaction counts,
--    and whether *you* reacted. Respects all the access rules above.
-- ---------------------------------------------------------------------

create view public.club_feed
with (security_invoker = true) as
select
  p.id, p.club_id, p.quote_text, p.page_ref, p.commentary,
  p.created_at, p.edited_at, p.is_hidden,
  p.author_id, pr.username as author_username, pr.display_name as author_display_name,
  pr.avatar_url as author_avatar_url,
  p.book_id, b.title as book_title, b.author as book_author, b.cover_url as book_cover_url,
  (select count(*) from public.comments c where c.post_id = p.id)   as comment_count,
  (select count(*) from public.reactions r where r.post_id = p.id)  as reaction_count,
  exists (select 1 from public.reactions r
          where r.post_id = p.id and r.user_id = auth.uid())        as reacted_by_me
from public.posts p
join public.profiles pr on pr.id = p.author_id
left join public.books b on b.id = p.book_id;

revoke all on public.club_feed from anon;
grant select on public.club_feed to authenticated;
