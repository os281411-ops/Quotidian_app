-- =====================================================================
-- "Now Reading" for clubs (checklist A6)
--
-- Owners and moderators can tag what the club is currently reading:
--   * an optional book (clubs can still be about authors, genres, etc.)
--   * free text for the section, e.g. "Chapters 1–5", "Part Two", "pp. 1–120"
--   * an optional "finish by" date
-- Shown as a banner in the chat, in Club Info and under the club in lists.
-- Editing is covered by the existing rule "Owners and moderators edit club
-- details"; this adds the columns and lets the word filter check the text.
-- =====================================================================

alter table public.book_clubs
  add column reading_book_id     uuid references public.books (id) on delete set null,
  add column reading_progress    text check (char_length(reading_progress) between 1 and 80),
  add column reading_until       date,
  add column reading_updated_at  timestamptz;

grant update (reading_book_id, reading_progress, reading_until, reading_updated_at)
  on public.book_clubs to authenticated;

-- Word filter now also checks the reading text.
create or replace function public.enforce_word_filter()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  content text;
  r jsonb := to_jsonb(new);
begin
  content := lower(concat_ws(' ',
    r->>'quote_text', r->>'commentary', r->>'body',
    r->>'name', r->>'description', r->>'username', r->>'display_name',
    r->>'reading_progress'));

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
