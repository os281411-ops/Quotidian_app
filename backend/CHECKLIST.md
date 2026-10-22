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

## Phase 1b — Developer setup

- [x] **D1. Quotidian Dev app**: Xcode Run builds "Quotidian Dev" (own app ID, DEV icon, Developer Menu in Profile). Archive builds the real app.
- [x] **D2. Dev database**: separate "Quotidian Dev" Supabase project, built with `backend/supabase/dev_setup.sql`. The dev app uses it automatically once its URL and key are in `SupabaseConfig.swift`.
- [ ] **D3. Workflow for database changes**: run each new migration file in the DEV project's SQL Editor first and test with the dev app; push to main only when it works (main = live database).

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
- [x] **15. Invite codes**: owners/moderators get an 8-character code in Club Info (Share, New Code); anyone can use + → Join with Invite Code.

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

## Phase 4b — More Bookclub features

*Tie Bookclub into the rest of the app*
- [ ] **A1. Quote of the Day room**: one shared chat everyone can join to discuss each day's quote.
- [ ] **A2. Save from chat to Library**: long-press a shared passage → save it to your Library.
- [ ] **A3. Streak on profiles**: show a reader's streak next to their name and on their profile.

*Reading together*
- [ ] **A4. Spoiler tags**: mark a message as a spoiler with a chapter ("Spoiler · Ch. 12"); blurred until tapped.
- [ ] **A5. Club shelf**: automatic list of every book attached in a club's chat, each with a Bookshop.org button.
- [ ] **A6. Pinned message**: owners/moderators pin a reading plan to the top of the chat.
- [ ] **A7. Replies**: reply to a specific message.
- [ ] **A8. Reactions**: a "resonated" reaction on messages.

*Finding and returning to clubs*
- [ ] **A9. Club tags**: Book, Author, Genre, Character; filter by tag in Discover.
- [ ] **A10. Unread badges**: show which clubs have new messages since you last looked.

*Premium*
- [x] **A11. Starting a club is Premium** (checked in the app; server check is step 31).
- [x] **A12. Private clubs are Premium**: creating needs Premium (A11); joining a private club by code needs Premium (checked in the app; server check is step 31).

*For you*
- [x] **A13. Moderation view**: Bookclub → Account → Review Reports (admins only). Remove / Keep per reported message. Make yourself admin once: SQL Editor → `insert into public.app_admins (user_id) values ('<your user id>');` (Developer Menu → Copy My User ID).

## Phase 5 — Safety (required for App Store approval)

- [x] **22. Report**: messages (long-press → Report) and people (their profile → Report).
- [x] **23. Block**: from a profile or long-press on a message; Account → Blocked Readers to unblock.
- [x] **23b. Ban** (admins): Review Reports → Ban, or Remove & Ban Author. Banned accounts can't post, start or join clubs; their messages are hidden.
- [ ] **24. Show friendly errors** for the word filter and spam limit (the server returns hints `word_filter` and `rate_limit`).
- [ ] **25. Review reports** within 24 hours (Apple expects this) using the Review Reports screen (A13). Consider a daily reminder or, later, a push notification to admins when a report comes in.
- [ ] **26. Contact info** for reporting problems shown in the app (your support page).

## Phase 6 — Notifications

- [ ] **27. APNs key** from the Apple Developer portal; store device tokens in a new `device_tokens` table.
- [ ] **28. Edge Function** that sends a push when someone comments on your post or replies to you.
- [ ] **29. Notification settings** so users can turn these off.

## Phase 7 — Before release

- [ ] **30. Update the privacy policy** (accounts, user posts, Apple ID email) and App Store privacy labels; update `PrivacyInfo.xcprivacy`.
- [ ] **30b. Revoke Sign in with Apple on account deletion** (Apple asks for this). Needs a Sign in with Apple key from the Apple Developer portal and a Supabase Edge Function that calls Apple's token-revoke endpoint.
- [ ] **31. Premium checks on the server** for A11/A12: verify subscriptions with Apple's App Store Server API (an Edge Function), so a modified app can't skip the paywall.
- [ ] **31b. Update the Premium paywall** (`PaywallView` feature list): add the Bookclub perks (start your own clubs, join private clubs with an invite).
- [ ] **31c. New App Store screenshots** that include Bookclub (club chat, a book card with the Bookshop.org button, Currently Reading) and the updated paywall. Add a subtle colour gradient behind the phone frames for more colour, keeping the app's sleek dark look; the existing designs are in `Marketing/App Store Screenshots`.
  - Gradient idea: a deep tone fading into black at the edges, so it stays dark and premium; a slightly different shade per screenshot so the set flows as a sequence.
  - Claude builds the frames from the existing designs and shows a few gradient options to pick from.
- [ ] **32. TestFlight** with at least 3 accounts: posting, reporting, blocking, deleting an account.
- [ ] **33. App Review notes**: explain the community feature, the moderation tools, and give Apple a **demo account** they can sign in with.
