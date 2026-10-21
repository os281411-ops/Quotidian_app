-- =====================================================================
-- Delete account (App Store guideline 5.1.1(v))
--
-- Lets a signed-in person permanently delete their own account.
-- Deleting the auth user cascades through the schema: their profile,
-- posts, comments, reactions, memberships, reports and blocks are all
-- removed. Clubs they own stay up, with no owner.
--
-- The app calls it with: supabase.rpc("delete_my_account")
-- =====================================================================

create function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'You need to be signed in to delete your account.'
      using errcode = '28000';
  end if;

  -- Only ever the caller's own account: auth.uid() comes from their
  -- signed-in session and can't be supplied by the app.
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
