# Community Forum

The Forum is a column beside the flyer board on desktop, and appears above
the flyer grid on narrower screens. Categories are Music Groups, Bands,
Local Businesses, and Religious Organizations.

Anyone can browse and filter community profiles. Signed-in representatives
create a profile with an organization name (80 characters), city/neighborhood
(100 characters), category, and short introduction (500 characters). Owners
can edit their own profiles. No email address or phone number is automatically
published with a Forum profile.

“Community feedback” opens the profile and its public feedback thread.
Signed-in members provide a public display name (64 characters) and feedback
(1,000 characters). Members can remove their own feedback. Organization owners
cannot edit or delete other members' feedback. Feedback is published immediately;
this version does not include automated moderation or an administrator review queue.
Text is inserted as plain DOM text, never interpreted as HTML.

Both lists load 20 entries at a time with “More” buttons. Requests are guarded
so a stale category or thread response cannot replace the current selection.

`forum-schema.sql` has been applied to Supabase `nwwkiljmxbtzoxafsesq`.
Both tables have RLS enabled, explicit grants, database-enforced field lengths,
and authenticated ownership checks. The rollback-only test in
`forum-rls-test.sql` passed against the live database: public reading, member
feedback, owner editing, rejected impersonation, rejected cross-owner profile
updates, and author-only feedback removal. Security advisors returned no
Forum findings. The complete page JavaScript syntax check also passed.

Browser/device layout and end-to-end UI testing remain pending. The source
includes the previous image, geolocation, and read-aloud changes. Confirm the
hosting deployment after publishing main.
