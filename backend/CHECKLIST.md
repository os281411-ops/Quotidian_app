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

- [x] **11. Community tab** in `CustomTabBar`: "My clubs" and "Discover" (public clubs).
- [x] **12. Create a club**: name, description, public/private. No book selection.
- [x] **13. Join and leave** public clubs; members list.
- [x] **14. Book search** via the Open Library API, used to attach books in chat and to set Currently Reading (with a Bookshop.org link through `BookshopAffiliate`). Clubs aren't tied to one book: a club can be about a book, an author, a genre or a character.
- [x] **15. Invite codes**: owners/moderators get an 8-character code in Club Info (Share, New Code); anyone can use + → Join with Invite Code.

## Phase 4 — Club chat and profiles

Clubs are chat rooms (the `messages` table replaced posts/comments/reactions). The Community tab is called **Bookclub** in the app.

- [x] **16. Live club chat**: messages appear instantly (Supabase Realtime); load earlier messages; pull to refresh.
- [x] **17. Send messages**: plain text, a quoted passage (quote mode), or both.
- [x] **18. Attach a book**: search Open Library, attach a book card with a Bookshop.org affiliate button.
- [x] **19. Currently Reading** on profiles: set it in Account; shown in members lists and on member profiles.
- [x] **20. Member profiles**: tap a name in chat or the members list.
- [x] **21. Delete** your own messages; owners/moderators can delete any in their club.
- [x] **21b. Share to a club**: Today → Club button, or the club icon on a Library card. Pick a club, add a thought, send; the book is attached with its Bookshop.org link.
- [ ] **21c. Edit** your own messages. *(database supports it; no button yet)*

## Phase 4b — More Bookclub features

*Tie Bookclub into the rest of the app*
- [x] **A1. Quote of the Day room**: one shared chat everyone can join to discuss each day's quote. Add a "Discuss today's quote" button under the quote on Today that opens it. *(built: migration `20261023150000_daily_room_and_unread.sql`; a fresh room each day, pinned card in Bookclub, button on Today)*
- [x] **A2. Save from chat to Library**: long-press a shared passage → Save to Library (free limit of 10 applies).
- [ ] **A14. "From the author" card** for the 100 book-less quotes: a 2–3 line note on who said it plus one recommended book by/about them with a Bookshop.org link (brings back About and the affiliate link on those days). Claude drafts notes + book picks and checks ISBNs; Oliver approves before it goes in.
- [x] **A15. Reflect** on Today: a round Reflect button (under Save on book quotes; in About's place on book-less quotes) opens a menu: six moods (Inspired, Moved, Calm, Thoughtful, Challenged, Not for me), Write a Thought…, Clear. Private, saved on the device only; shown on Library cards for saved quotes.
- [ ] **A3. Streak on profiles**: show a reader's streak next to their name and on their profile.

*Reading together*
- [x] **A4. Spoiler tags**: eye button in the message box, optional label (pre-filled from Now Reading); blurred for others until tapped.
- [ ] **A5. Club shelf**: automatic list of every book attached in a club's chat, each with a Bookshop.org button.
- [x] **A6. Now Reading**: owners/moderators tag the book (optional), section (e.g. "Chapters 1–5") and a finish-by date. Shown as a banner at the top of the chat, in Club Info, and under the club in lists.
- [ ] **A7. Replies**: reply to a specific message.
- [ ] **A8. Reactions**: a "resonated" reaction on messages.

*Finding and returning to clubs*
- [ ] **A9. Club tags**: Book, Author, Genre, Character; filter by tag in Discover.
- [x] **A10. Unread badges**: show which clubs have new messages since you last looked. *(built: same migration; counts on My Clubs rows and a dot on the Bookclub tab)*

*Premium*
- [x] **A11. Starting a club is Premium** (checked in the app; server check is step 31).
- [x] **A12. Private clubs are Premium**: creating needs Premium (A11); joining a private club by code needs Premium (checked in the app; server check is step 31).

*For you*
- [x] **A13. Moderation view**: Bookclub → Account → Review Reports (admins only). Remove / Keep per reported message. Make yourself admin once: SQL Editor → `insert into public.app_admins (user_id) values ('<your user id>');` (Developer Menu → Copy My User ID).

## Phase 5 — Safety (required for App Store approval)

- [x] **22. Report**: messages (long-press → Report) and people (their profile → Report).
- [x] **23. Block**: from a profile or long-press on a message; Account → Blocked Readers to unblock.
- [x] **23b. Ban** (admins): Review Reports → Ban, or Remove & Ban Author. Banned accounts can't post, start or join clubs; their messages are hidden.
- [x] **24. Show friendly errors** for the word filter and spam limit (the server returns hints `word_filter` and `rate_limit`).
- [ ] **25. Review reports** within 24 hours (Apple expects this) using the Review Reports screen (A13). Consider a daily reminder or, later, a push notification to admins when a report comes in.
- [x] **26. Contact info**: Profile → Help & Feedback (Email Support, Help & FAQ, Privacy Policy); Bookclub → Account → Report a Problem; email in the house rules.

## Phase 6 — Notifications

- [ ] **27. APNs key** from the Apple Developer portal; store device tokens in a new `device_tokens` table.
- [ ] **28. Edge Function** that sends a push when someone comments on your post or replies to you.
- [ ] **29. Notification settings** so users can turn these off.

## Phase 6b — Fixes from testing

- [x] **T1. Evening reminder wording**: "You haven't read today's quote yet" also goes to people who already have. If today's quote has been read, send a different evening message instead.
- [x] **T2. Compact Today screen**: "Discuss today's quote" should be visible without scrolling.
- [x] **T3. Edit your thought from the Library**: tap the thought (or mood) on a saved quote to change it.
- [x] **T4. Book search fails the first time**: the first search when attaching a book shows a connection error; the second works.
- [x] **T5. New club asks its owner to "Join to Chat"** (TestFlight feedback): the app now trusts that you own a club you just made, re-checks membership when a chat opens, treats "already in this club" as joined, and opens an empty club with the keyboard up.
- [x] **T6. Pull-to-refresh said "Couldn't load your clubs"** even though they loaded: SwiftUI was cancelling the refresh early; cancelled requests no longer count as errors.
- [x] **T7. Today fills the screen**: gaps grow on taller phones and shrink to fit iPhone 12 and up without scrolling.
- [x] **T8. Sent messages sometimes stayed in the box**: the box now empties as soon as you tap send (and puts the text back if sending fails).
- [x] **T9. Report button cut off on member profiles**: tighter layout and a slightly taller sheet.
- [x] **T10. Bookshop links on searched books gave 404s**: Open Library's first ISBN is often an edition Bookshop.org doesn't stock. New books now pick an edition Bookshop has a page for, and every Bookshop button checks first and falls back to a search for the title if the page is missing.
- [x] **T11. Tap anywhere to close the keyboard**, on every screen (taps on text boxes, and just above the keyboard where chat's message box is, are ignored).
- [x] **A16. Bookclub tour**: a private, scripted chat in My Clubs that explains messages, passages, books, spoilers, Now Reading, unread badges, long-press options and, last, the Quote of the Day button. Type "next" to move on; progress is saved on the phone.
- [x] **A17. Bookshelf tab**: scan a book's barcode (camera) or search to add it; covers four to a row; tap to flip (title, author, year), tap again for the full page (big cover, description, ISBN, Bookshop.org link, remove). Private, saved on the phone, free for everyone. *(Test scanning on a real iPhone; the Simulator has no camera.)*

## Phase 7 — Before release

- [ ] **30. Update the privacy policy** *(drafted: `docs/privacy-policy.html`, `docs/support.html`, and description / App Privacy answers / age rating / What's New in `Marketing/app-store-listing.md`. To do: Oliver reviews, pushes (pages go live via GitHub Pages), then updates App Store Connect when submitting.)*
  - The App Store description currently says Quotidian "doesn't collect any personal data, doesn't require an account, and doesn't track you". Rewrite that line: Bookclub is optional, but it uses an account and stores what people post.
- [ ] **30b. Revoke Sign in with Apple on account deletion** (Apple asks for this). Needs a Sign in with Apple key from the Apple Developer portal and a Supabase Edge Function that calls Apple's token-revoke endpoint.
  - [x] Code written: `supabase/functions/delete-account`, `AppleReauthenticator.swift`, delete flow confirms with Apple first (falls back to plain delete if the function isn't reachable).
  - [x] Sign in with Apple key made, secrets added, function deployed and tested on QuotidianDev.
  - [ ] Near release: add the same secrets to the live project (APPLE_CLIENT_ID = com.oliverscott.Quotidian), deploy `delete-account` there with JWT verification off.
- [ ] **31. Premium checks on the server** *(deferred until after launch: the check is in the app for now)* for A11/A12: verify subscriptions with Apple's App Store Server API (an Edge Function), so a modified app can't skip the paywall.
- [x] **31a. Remove the Archive** *(done in the app; still to do: "What's New" note and dropping `04-archive.png` with 31c)* (the tab where Premium users browse every quote, past and future). Seeing every quote at once goes against the point of a quote *a day*, and Bookclub now gives Premium more to offer. Includes:
  - remove the Archive tab and `ArchiveView`, and the `.archive` paywall reason;
  - take "The full quote archive" out of the paywall feature list (do this with 31b);
  - update the App Store description and drop the archive screenshot (`04-archive.png`) when redoing screenshots (31c);
  - existing subscribers lose a feature they paid for: mention the change in the update's "What's New" text and lead with the new Bookclub perks.
- [x] **31b. Update the Premium paywall**: leads with "Start your own book clubs" and "Join private clubs with an invite"; archive removed from the list and paywall wording.
- [x] **31d. All 160 quotes in the daily rotation** (book quotes spread evenly; never more than 2 days in a row without a book). App and widget both updated.
  - The day this update goes out, everyone's "today's quote" changes once (the cycle is now 160 days, not 60).
  - App Store description says every quote "links straight to that book on Bookshop.org" and "comes with a short note on the book": reword, since about 6 in 10 days now have no book.
- [ ] **31c. New App Store screenshots** that include Bookclub (club chat, a book card with the Bookshop.org button, Currently Reading) and the updated paywall. Add a subtle colour gradient behind the phone frames for more colour, keeping the app's sleek dark look; the existing designs are in `Marketing/App Store Screenshots`.
  - Gradient idea: a deep tone fading into black at the edges, so it stays dark and premium; a slightly different shade per screenshot so the set flows as a sequence.
  - Claude builds the frames from the existing designs and shows a few gradient options to pick from.
- [ ] **32. TestFlight** with at least 3 accounts: posting, reporting, blocking, deleting an account.
- [ ] **33. App Review notes**: explain the community feature, the moderation tools, and give Apple a **demo account** they can sign in with.
