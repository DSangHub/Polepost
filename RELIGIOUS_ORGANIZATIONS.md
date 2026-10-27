# Religious Organizations

A dedicated landing-page column invites religious organizations to post ads
at no charge after verification, and publish a Call to Prayer for visitors to
listen to. It appears above the Forum in the community sidebar and stacks on
mobile. Labels and controls support English and Spanish; authored prayer text
is preserved in its original language.

## Verification and privacy

Signed-in representatives submit the organization name, location, official
website/public organization page, representative name, contact email and an
explanation of how their authorization can be confirmed. One pending request
per account is allowed. Requests and review notes are readable only by the
request owner and administrators. No representative contact details are copied
into the public organization profile.

Approval is manual. No organization is approved automatically, and no verified
organizations were created by this implementation. The organization approval
badge confirms administrative review of identity/representation, not endorsement.

Administrative workflow in the Supabase SQL editor, using the trusted database
administrator role (never grant this capability to frontend users):

```sql
select id, name, area, website, representative, contact_email, evidence, created_at
from public.pp_religious_requests
where status = 'pending' order by created_at;

-- Independently confirm the organization's existence and the representative's
-- authorization using its official public contact information. Then approve
-- or reject the exact request; record what was checked in the review note.
select public.pp_review_religious_request(
  '<request UUID>', true, 'Document the completed verification here'
);

-- To reject, pass false and an explanatory review note. To revoke an existing
-- organization, set verified=false on its pp_religious_orgs row. Revocation
-- hides its ads and prayers and blocks further publication immediately.
```

The approval function is callable only by service_role or the database
administrator. Clients cannot create approved organizations, update requests
to approved, or change verification fields.

## Free ads and prayers

Approved owners select their verified organization and post an ad or a Call to
Prayer, with an 80-character title and up to 2,000 characters of content. There
is no Stripe checkout, posting fee or automatic charge in this flow. Owners can
remove their own posts. Public entries load 20 at a time.

“Listen to Prayer” reads the written title, organization name and prayer using
the existing device speech player. The author selects English or Spanish for
the voice; pause/resume/stop are shared with the existing post reader. Playback
starts only after a visitor clicks. This is text-to-speech, not an uploaded
recording. Unsupported browsers disable listening. Actual voice availability
and behavior depend on the visitor's device.

## Backend and validation

`religious-schema.sql` is already applied to `nwwkiljmxbtzoxafsesq`. Three
separate tables protect requests, public organization records, and publications.
RLS enforces verified organization ownership on every publication, and hides
posts if verification is revoked. Tests in `religious-rls-test.sql` run in a
rolled-back transaction: signed-in request submission, blocked self-approval,
blocked status spoofing, approved-owner ads/prayers, private request isolation,
cross-owner write/delete rejection, and verification revocation all passed.
Security advisors returned no religious-feature findings. Page and localization
JavaScript syntax checks, translation regression checks, and prayer narration
content checks passed. Real-device audio and browser layout need live testing
after the hosting deployment.
