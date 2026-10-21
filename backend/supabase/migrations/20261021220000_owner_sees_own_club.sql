-- =====================================================================
-- Fix: creating a private club failed.
--
-- When a club is created, the app asks for the new row back. For a
-- private club, the visibility rule only allowed members to see it,
-- and at that instant the creator's membership (added by a trigger)
-- isn't visible yet, so the whole insert was rejected.
-- Owners can now always see their own clubs.
-- =====================================================================

drop policy "See public clubs and clubs you belong to" on public.book_clubs;

create policy "See public clubs and clubs you belong to"
  on public.book_clubs for select to authenticated
  using (
    not is_private
    or owner_id = auth.uid()
    or public.is_club_member(id)
  );

-- Keep the shared helper consistent with the rule above.
create or replace function public.can_view_club(p_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.book_clubs c
    where c.id = p_club
      and (not c.is_private or c.owner_id = auth.uid() or public.is_club_member(c.id))
  );
$$;
