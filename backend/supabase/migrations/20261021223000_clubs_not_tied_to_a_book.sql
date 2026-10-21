-- =====================================================================
-- Clubs aren't tied to a single book.
--
-- A club can be about one book, an author, a genre, a character,
-- anything; its name and description say what. Books are still
-- recorded per post (posts.book_id), where each quote comes from.
-- =====================================================================

alter table public.book_clubs drop column current_book_id;
