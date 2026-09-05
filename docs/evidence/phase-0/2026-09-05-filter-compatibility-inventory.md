# Existing-filter compatibility inventory

Date: 2026-09-05 UTC. Application release `ed8756f`. Read-only inspection; no filter or message mutations, sends, scope changes or deployment.

## Live observations

- At 12:47:51, verified the connected receiving profile before reading full filters and labels. Gmail returned three filters and 18 labels. All three filters have a single simple sender criterion, add `TRASH`, remove no labels and do not forward. None names the controlled sender literally. Private correspondents, filter IDs and label IDs are omitted.
- Saved the complete filter/label JSON on the owner's Mac outside Git at `~/.config/email-sucks/hosted-cougar-cedar/filter-inventory/2026-09-05-124751.json`. Verified JSON structure, three filters, 18 labels and mode 0600 inside a mode-0700 directory. This is a reference snapshot, not a tested Gmail-import artifact.
- At 12:48:55, a Gmail search for the five existing synthetic subjects from the controlled sender found five messages and included all three saved batch IDs. Searches combining each existing simple sender criterion with those subjects returned zero matches, including Spam/Trash. No query was paginated; no body or arbitrary correspondence was retrieved. No saved batch member matched any of the three filters.
- At 12:52:06, a fresh provider read was exactly equal to the original filter snapshot. The batch remained released at repeat revision three with zero pending/errors, account connected and no pending disconnect. Removed diagnostic files and temporary snapshots from VM/container; the private Mac copy remains. Readiness passed.

No application code changed and no automated suites were rerun; the last application baseline remains 138 backend and 23 browser tests.

This proves the current filters do not overlap these existing controlled fixtures under the inspected searches. It does not establish future arrival-time filter ordering, overlap behavior, general receiving coverage or automatic conflict detection in the application.

## Naturally expired access token

The first final read at 12:50:53 returned HTTP 401 because the diagnostic used the stored access token directly, outside the application's refresh boundary. At 12:51:25 its saved expiry was `1788612617`, earlier than the observed time `1788612685`; no expiry field was edited in this rehearsal.

The authenticated browser's ordinary **Check connection** action succeeded and showed connection verified. At 12:52:06 the account revision had advanced from 12 to 13, expiry was `1788616295` (future relative to `1788612726`), the refresh lease was zero, and the same filter GET succeeded. This adds live evidence for refresh after observed natural access-token expiry. It does not prove refresh-token rotation or survival beyond Google's Testing authorization lifetime.

## Compatibility consequence and next experiment

The relevant existing action is Trash routing. The supported boundary must preserve that choice: mail in Trash is excluded from intake and must not be resurrected by normal recovery. Current `Gmail.Projection` checks Trash/Spam/Draft before changing labels; source inspection is not live filter-arrival evidence.

The [bounded overlap experiment](../../phase-0-filter-compatibility.md) specifies the next fixture, expected exclusion and cleanup gates. It is prepared, not executed. No existing filter should be modified or treated as app-owned.

Google's [filter resource](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.filters) defines message-level criteria and label/forward actions. [Filters list](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.filters/list) supports the existing Gmail read/modify grants; filter creation/deletion needs separate settings access.
