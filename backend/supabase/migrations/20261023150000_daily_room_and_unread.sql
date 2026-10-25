-- =====================================================================
-- Quote of the Day room (checklist A1) and unread badges (A10)
--
-- A1: one shared, public "Quote of the Day" club that everyone can talk
--     in. Each message belongs to a day (room_day), so the app shows a
--     fresh conversation every day about that day's quote. The app joins
--     people automatically and keeps this club out of club lists.
--
-- A10: each membership remembers when you last read the club, and
--      my_unread_counts() tells the app how many new messages each of
--      your clubs has (not counting your own, hidden or blocked ones).
-- =====================================================================

-- ---------------------------------------------------------------------
-- A1. QUOTE OF THE DAY ROOM
-- ---------------------------------------------------------------------

alter table public.book_clubs
  add column is_daily boolean not null default false;

-- Only ever one daily room.
create unique index book_clubs_one_daily_room on public.book_clubs (is_daily) where is_daily;

alter table public.messages
  add column room_day date;

create index messages_club_day_recent_idx on public.messages (club_id, room_day, created_at desc);

-- The room itself (fixed ID so the app can find it). No owner, so no
-- one but app admins can moderate it, and no one can edit or delete it.
insert into public.book_clubs (id, name, description, is_private, owner_id, is_daily)
values (
  '00000000-0000-4000-8000-000000000001',
  'Quote of the Day',
  'One conversation a day about the day''s quote.',
  false,
  null,
  true
)
on conflict (id) do nothing;

-- Messages in the daily room must say which day they're about (today,
-- give or take a day for time zones). Other clubs never have a day.
create function public.check_room_day()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  daily boolean;
begin
  select c.is_daily into daily from public.book_clubs c where c.id = new.club_id;

  if coalesce(daily, false) then
    if new.room_day is null
       or new.room_day not between current_date - 1 and current_date + 1 then
      raise exception 'Messages here need to be about today''s quote.'
        using errcode = 'P0001', hint = 'room_day';
    end if;
  else
    new.room_day := null;
  end if;
  return new;
end;
$$;

create trigger check_room_day before insert on public.messages
  for each row execute function public.check_room_day();

-- ---------------------------------------------------------------------
-- A10. UNREAD BADGES
-- ---------------------------------------------------------------------

-- Existing members start with nothing unread.
alter table public.club_members
  add column last_read_at timestamptz not null default now();

-- "I've read this club up to now."
create function public.mark_club_read(p_club_id uuid)
returns void language sql security definer set search_path = '' as $$
  update public.club_members
     set last_read_at = now()
   where club_id = p_club_id and user_id = auth.uid();
$$;

-- New messages in each of your clubs since you last read it (capped at
-- 100 to keep it quick; the app shows "99+").
create function public.my_unread_counts()
returns table (club_id uuid, unread int)
language sql stable security definer set search_path = '' as $$
  select m.club_id,
         (select count(*)::int from (
            select 1
              from public.messages x
             where x.club_id = m.club_id
               and x.created_at > m.last_read_at
               and x.author_id <> auth.uid()
               and not x.is_hidden
               and not public.i_blocked(x.author_id)
             limit 100
          ) recent) as unread
    from public.club_members m
    join public.book_clubs c on c.id = m.club_id
   where m.user_id = auth.uid()
     and not c.is_daily;
$$;

revoke execute on function public.mark_club_read(uuid) from public, anon;
revoke execute on function public.my_unread_counts()   from public, anon;
grant execute on function public.mark_club_read(uuid) to authenticated;
grant execute on function public.my_unread_counts()   to authenticated;
