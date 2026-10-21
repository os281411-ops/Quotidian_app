# Quotidian Community — Build Checklist

Book clubs where people share quotes and discuss books.
Backend: **Supabase** (database, sign-in, access rules, server functions).

Tick items by changing `[ ]` to `[x]`.

---

## Phase 1 — Backend foundations

- [x] **1. Write the database schema and access rules**
  `backend/supabase/migrations/0001_community_schema.sql`
  Tables: profiles, books, book_clubs, club_members, posts, comments, reactions, reports, blocks, blocked_terms. Includes access rules, word filter, spam limit, auto-hide after 3 reports, and a `club_feed` view. Tested against Postgres 16.
- [x] **2. Create a Supabase project** *(you)*
  supabase.com → New project → name `quotidian` → region **London (eu-west-2)** → save the database password in your password manager.
  Then Project Settings → API: copy the **Project URL** and **anon public key**.
- [x] **3. Run the schema**
  Applied, and recorded under Database → Migrations as `0001 · community_schema`.
  From now on, add new database changes as new files in `backend/supabase/migrations/` and push to main; the GitHub integration applies them. Don't paste migration files into the SQL Editor.
- [x] **4. Add words to the filter**
  Table Editor → `blocked_terms` → add slurs and other terms you want blocked (lowercase, one per row).
- [x] **5. Turn on Sign in with Apple**
  - Xcode → Quotidian target → Signing & Capabilities → **+ Sign in with Apple**.
  - Supabase → Authentication → Sign In / Providers → Apple → enable → add your app's **bundle ID** under Client IDs. (A native-only iOS app doesn't need a Services ID or key file.)
- [x] **6. Add the Supabase Swift package**
  Xcode → File → Add Package Dependencies → `https://github.com/supabase/supabase-swift` → add the `Supabase` library to the Quotidian target.
  Put the URL and anon key in a `SupabaseConfig.swift` (the anon key is safe in the app; the access rules protect the data). **Never** put the service-role key in the app.

## Phase 2 — Accounts in the app

- [x] **7. Sign-in screen** with the Sign in with Apple button; keep the user signed in between launches.
- [x] **8. Pick a username** after first sign-in (3–20 chars, lowercase letters, numbers, `_`).
- [x] **9. Community guidelines screen**: user must tap "I agree" before posting (sets `accepted_guidelines_at`). Guidelines are shown in-app (`CommunityGuidelinesView`).
- [x] **10. Delete account** (Apple requirement). Community tab → Account → Delete Account. Uses the `delete_my_account()` database function (migration `20261021200000_delete_account.sql`); everything else is removed automatically.

## Phase 3 — Clubs

- [ ] **11. Community tab** in `CustomTabBar`: "My clubs" and "Discover" (public clubs).
- [ ] **12. Create a club**: name, description, public/private. No book selection.
- [ ] **13. Join and leave** public clubs; members list.
- [ ] **14. Book search** via the Open Library API, used to attach books in chat and to set Currently Reading (with a Bookshop.org link through `BookshopAffiliate`). Clubs aren't tied to one book: a club can be about a book, an author, a genre or a character.
- [ ] **15. Private club invites** (invite code or link). *Can wait until after launch.*

## Phase 4 — Club chat and profiles

Clubs are chat rooms (the `messages` table replaced posts/comments/reactions). The Community tab is called **Bookclub** in the app.

- [ ] **16. Live club chat**: messages appear instantly (Supabase Realtime); load earlier messages; pull to refresh.
- [ ] **17. Send messages**: plain text, a quoted passage (quote mode), or both.
- [ ] **18. Attach a book**: search Open Library, attach a book card with a Bookshop.org affiliate button.
- [ ] **19. Currently Reading** on profiles: set it in Account; shown in members lists and on member profiles.
- [ ] **20. Member profiles**: tap a name in chat or the members list.
- [ ] **21. Delete** your own messages; owners/moderators can delete any in their club.
- [ ] **21b. Share to a club** from a saved quote in the Library or the daily quote. *(not built yet)*
- [ ] **21c. Edit** your own messages. *(database supports it; no button yet)*

## Phase 5 — Safety (required for App Store approval)

- [ ] **22. Report**: messages can be reported from the long-press menu (built). Still to do: report a person from their profile.
- [ ] **23. Block user** from their profile or a post; add an unblock list in Settings.
- [ ] **24. Show friendly errors** for the word filter and spam limit (the server returns hints `word_filter` and `rate_limit`).
- [ ] **25. Review reports**: check the `reports` table in the dashboard regularly. Set `status`, and un-hide content that was wrongly reported. Apple expects you to act within 24 hours.
- [ ] **26. Contact info** for reporting problems shown in the app (your support page).

## Phase 6 — Notifications

- [ ] **27. APNs key** from the Apple Developer portal; store device tokens in a new `device_tokens` table.
- [ ] **28. Edge Function** that sends a push when someone comments on your post or replies to you.
- [ ] **29. Notification settings** so users can turn these off.

## Phase 7 — Before release

- [ ] **30. Update the privacy policy** (accounts, user posts, Apple ID email) and App Store privacy labels; update `PrivacyInfo.xcprivacy`.
- [ ] **30b. Revoke Sign in with Apple on account deletion** (Apple asks for this). Needs a Sign in with Apple key from the Apple Developer portal and a Supabase Edge Function that calls Apple's token-revoke endpoint.
- [ ] **31. Decide what's premium** (e.g. creating clubs). If gated, check subscriptions on the server, not just in the app.
- [ ] **32. TestFlight** with at least 3 accounts: posting, reporting, blocking, deleting an account.
- [ ] **33. App Review notes**: explain the community feature, the moderation tools, and give Apple a **demo account** they can sign in with.
