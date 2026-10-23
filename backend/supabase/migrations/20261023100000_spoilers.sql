-- =====================================================================
-- Spoiler tags on messages (checklist A4)
--
-- A message can be marked as a spoiler, with an optional label such as
-- "Ch. 12". The app blurs it for everyone except the author until they
-- tap to reveal. The word filter also checks the label.
-- =====================================================================

alter table public.messages
  add column is_spoiler     boolean not null default false,
  add column spoiler_label  text check (char_length(spoiler_label) between 1 and 40);

-- Word filter now also checks spoiler labels (and still checks everything else).
create or replace function public.enforce_word_filter()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  content text;
  r jsonb := to_jsonb(new);
begin
  content := lower(concat_ws(' ',
    r->>'quote_text', r->>'commentary', r->>'body',
    r->>'name', r->>'description', r->>'username', r->>'display_name',
    r->>'reading_progress', r->>'spoiler_label'));

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
