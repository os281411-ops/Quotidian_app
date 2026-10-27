-- =====================================================================
-- SCREENSHOT DEMO DATA: run in the QuotidianDev SQL Editor ONLY.
-- Never run this on the live project. (It isn't in /migrations, so a
-- push to GitHub never applies it anywhere.)
--
-- Adds five sample readers, three public clubs with conversations, and
-- some posts in today's Quote of the Day room, so screenshots look lived-in.
-- Change 'YOUR_USERNAME' on the line below to your dev username first.
-- Safe to run again: it removes the old sample data before adding it.
-- =====================================================================

do $$
declare
  me uuid := (select id from public.profiles where username = 'YOUR_USERNAME');
  r_eleanor uuid := '5eed0000-0000-4000-8000-000000000001';
  r_james   uuid := '5eed0000-0000-4000-8000-000000000002';
  r_priya   uuid := '5eed0000-0000-4000-8000-000000000003';
  r_tom     uuid := '5eed0000-0000-4000-8000-000000000004';
  r_maya    uuid := '5eed0000-0000-4000-8000-000000000005';
  c_classics uuid := '5eedc1b0-0000-4000-8000-000000000001';
  c_scifi    uuid := '5eedc1b0-0000-4000-8000-000000000002';
  c_poetry   uuid := '5eedc1b0-0000-4000-8000-000000000003';
  daily      uuid := '00000000-0000-4000-8000-000000000001';
  b_gatsby uuid; b_middlemarch uuid; b_1984 uuid; b_dune uuid; b_bookthief uuid; b_pride uuid;
begin
  if me is null then
    raise exception 'Change YOUR_USERNAME at the top to your dev username.';
  end if;

  -- Clear any earlier run.
  delete from public.book_clubs where id in (c_classics, c_scifi, c_poetry);
  delete from auth.users where id in (r_eleanor, r_james, r_priya, r_tom, r_maya);

  -- Sample readers (profiles are created automatically).
  insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'sample-' || right(u::text, 2) || '@example.invalid', '{}'::jsonb, '{}'::jsonb, now(), now()
  from unnest(array[r_eleanor, r_james, r_priya, r_tom, r_maya]) as u;

  -- Books used in the chats.
  insert into public.books (title, author, isbn13, cover_url) values
    ('The Great Gatsby', 'F. Scott Fitzgerald', '9780743273565', 'https://covers.openlibrary.org/b/isbn/9780743273565-M.jpg'),
    ('Middlemarch', 'George Eliot', '9780141439549', 'https://covers.openlibrary.org/b/isbn/9780141439549-M.jpg'),
    ('1984', 'George Orwell', '9780451524935', 'https://covers.openlibrary.org/b/isbn/9780451524935-M.jpg'),
    ('Dune', 'Frank Herbert', '9780441172719', 'https://covers.openlibrary.org/b/isbn/9780441172719-M.jpg'),
    ('The Book Thief', 'Markus Zusak', '9780375842207', 'https://covers.openlibrary.org/b/isbn/9780375842207-M.jpg'),
    ('Pride and Prejudice', 'Jane Austen', '9780143138730', 'https://covers.openlibrary.org/b/isbn/9780143138730-M.jpg')
  on conflict (isbn13) do nothing;
  select id into b_gatsby     from public.books where isbn13 = '9780743273565';
  select id into b_middlemarch from public.books where isbn13 = '9780141439549';
  select id into b_1984       from public.books where isbn13 = '9780451524935';
  select id into b_dune       from public.books where isbn13 = '9780441172719';
  select id into b_bookthief  from public.books where isbn13 = '9780375842207';
  select id into b_pride      from public.books where isbn13 = '9780143138730';

  update public.profiles p set
    username = v.username, display_name = v.display_name,
    accepted_guidelines_at = now(), currently_reading_book_id = v.book
  from (values
    (r_eleanor, 'eleanor_reads', 'Eleanor', b_middlemarch),
    (r_james,   'jamesbooks',    'James',   b_gatsby),
    (r_priya,   'priya_pages',   'Priya',   b_bookthief),
    (r_tom,     'tom_turns',     'Tom',     b_dune),
    (r_maya,    'maya_m',        'Maya',    b_pride)
  ) as v(id, username, display_name, book)
  where p.id = v.id;

  -- Clubs (Eleanor, James and Tom own them; you're a member of all three).
  insert into public.book_clubs (id, name, description, is_private, owner_id,
                                 reading_book_id, reading_progress, reading_until, reading_updated_at)
  values
    (c_classics, 'The Classics Society', 'Old books, new conversations. One classic a month.', false, r_eleanor,
       b_gatsby, 'Chapters 1–5', current_date + 4, now()),
    (c_scifi, 'Sci-Fi & Dystopia', 'Big ideas, bleak futures, brilliant books.', false, r_tom,
       b_dune, 'Book One', current_date + 10, now()),
    (c_poetry, 'Poetry Corner', 'Share a poem that moved you this week.', false, r_james,
       null, null, null, null);

  insert into public.club_members (club_id, user_id, role, joined_at, last_read_at)
  select c, u, 'member', now() - interval '20 days', now() - interval '20 days'
  from unnest(array[c_classics, c_scifi, c_poetry]) as c,
       unnest(array[r_eleanor, r_james, r_priya, r_tom, r_maya, me]) as u
  on conflict (club_id, user_id) do nothing;

  -- You've read the Classics chat, so the other two show unread badges.
  update public.club_members set last_read_at = now()
  where club_id = c_classics and user_id = me;
  insert into public.club_members (club_id, user_id, role)
  select daily, u, 'member' from unnest(array[r_eleanor, r_james, r_priya, r_tom, r_maya]) as u
  on conflict (club_id, user_id) do nothing;

  -- The Classics Society chat.
  insert into public.messages (club_id, author_id, body, quote_text, book_id, is_spoiler, spoiler_label, created_at) values
    (c_classics, r_eleanor, 'Welcome to Gatsby month! We''re reading chapters 1–5 by Friday.', null, b_gatsby, false, null, now() - interval '52 minutes'),
    (c_classics, r_james, null, 'In my younger and more vulnerable years my father gave me some advice that I''ve been turning over in my mind ever since.', null, false, null, now() - interval '47 minutes'),
    (c_classics, r_james, 'What an opening line. Nick is already telling us not to trust him.', null, null, false, null, now() - interval '46 minutes'),
    (c_classics, r_priya, 'The green light at the end of Daisy''s dock! I had to stop and reread that page.', null, null, false, null, now() - interval '31 minutes'),
    (c_classics, r_tom, 'Gatsby planned that whole party just so Daisy might wander in. Heartbreaking.', null, null, true, 'Ch. 4', now() - interval '22 minutes'),
    (c_classics, r_maya, 'Loving this. Anyone fancy Middlemarch next month?', null, b_middlemarch, false, null, now() - interval '9 minutes'),
    (c_classics, me, 'Yes please! I''ve had it on my shelf for years.', null, null, false, null, now() - interval '4 minutes');

  -- Sci-Fi & Dystopia (newer messages = unread).
  insert into public.messages (club_id, author_id, body, quote_text, book_id, created_at) values
    (c_scifi, r_tom, 'Book One done. The spice must flow!', null, b_dune, now() - interval '3 hours'),
    (c_scifi, r_priya, null, 'Fear is the mind-killer.', null, now() - interval '25 minutes'),
    (c_scifi, r_maya, 'Rereading 1984 alongside this. Very different futures.', null, b_1984, now() - interval '12 minutes');

  -- Poetry Corner.
  insert into public.messages (club_id, author_id, body, quote_text, created_at) values
    (c_poetry, r_james, null, 'I wandered lonely as a cloud / That floats on high o''er vales and hills', now() - interval '2 hours'),
    (c_poetry, r_eleanor, 'Wordsworth on a grey Tuesday is exactly what I needed.', null, now() - interval '40 minutes');

  -- Today's Quote of the Day discussion.
  delete from public.messages where club_id = daily and author_id in (r_eleanor, r_james, r_priya, r_tom, r_maya);
  insert into public.messages (club_id, author_id, body, room_day, created_at) values
    (daily, r_priya, 'This one stopped me on the way to work this morning.', current_date, now() - interval '3 hours'),
    (daily, r_tom, 'I read it twice. It means something different the second time.', current_date, now() - interval '2 hours'),
    (daily, r_eleanor, 'Has anyone read the whole book? I''m tempted now.', current_date, now() - interval '70 minutes'),
    (daily, r_maya, 'Yes! Start it this weekend, you won''t regret it.', current_date, now() - interval '55 minutes'),
    (daily, r_james, 'Saving this one to my Library.', current_date, now() - interval '18 minutes');
end $$;

-- To remove the sample data later:
-- delete from public.book_clubs where id::text like '5eedc1b0-%';
-- delete from auth.users where id::text like '5eed0000-%';
