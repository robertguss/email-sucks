# Phase 0 experiment inventory

Date: 2026-09-04. Status: prepared; live interception/device experiments not run. This is an execution checklist, not evidence of passes. Follow the [proof plan](phase-0-gmail-reliability-proof.md) and use the [offline recovery card](phase-0-offline-recovery-card.md) before activation.

## Environment record

Record these privately, then publish only a sanitized evidence summary:

- Environment name, git revision, Render web/worker/database IDs, actual runtime/database versions.
- Allowed test identity, primary and send-as identities, other receiving aliases, plus-addresses and forwarding paths. Distinguish verified, unavailable and untested identities.
- Exported existing filters and identified conflicts; Gmail categories, conversation-view setting and current app-owned label/filter IDs. Gmail filter configuration can contain private correspondents; keep the export outside git.
- Google OAuth client mode, granted scope names, consent time and direct Gmail access verification. No client secrets or tokens in evidence.
- Actual device model, OS, Gmail/browser version, account notification setting, OS notification permission, badges/sounds and battery/background restrictions.
- Controlled external sender(s), recipient authorization, agreed synthetic contents and fixture IDs. The agent must not send messages without explicit recipient authorization.

## Method/scope inventory

Verified against Google's current [Gmail scope reference](https://developers.google.com/workspace/gmail/api/auth/scopes) and the method authorization lists on 2026-09-04. Entries choose a sufficient scope for this phase; they are not a request to grant it now.

| Operation | Scope for this plan | Current status |
|---|---|---|
| OIDC identity + verified email | `openid`, `email` | Implemented |
| Profile, messages list/get | `gmail.readonly` | Implemented; live proof exists |
| Filters list, send-as list, labels list | `gmail.readonly` | Internal read-only inventory implemented and fixture-tested; live discovery pending |
| History list | `gmail.readonly` | Sync implementation pending |
| Labels create | `gmail.modify` (also supports narrower `gmail.labels`) | Planned alongside message release |
| Exact message label modification / restore | `gmail.modify` | Not requested or implemented |
| Filters create/delete | `gmail.settings.basic` | Not requested or implemented; `gmail.modify` alone cannot disable interception filters |
| Message send | Later compose phase | Not implemented; no test sends authorized by this checklist |

The mutation experiment would require `gmail.modify` plus `gmail.settings.basic` in addition to identity scopes. `gmail.modify` includes sending capabilities even when the app exposes only label changes; it is not a label-only grant. Do not request `mail.google.com` or administrative `gmail.settings.sharing`. Maintain separate application capability/activation guards when adding broad provider scopes. [Message modification](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/modify), [filter creation](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.filters/create), [filter deletion](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.filters/delete)

External Testing authorization remains suitable for short read-only experiments. Before the two-week dogfood, choose a publishing/reauthorization strategy and rehearse expiry while interception exists; do not assume refresh tokens remain valid for the whole trial. Natural expiry and refresh-token rotation remain separate from the simulated local-expiry proof. [Google token expiration](https://developers.google.com/identity/protocols/oauth2#expiration)

## Controlled fixtures

Use unique synthetic tokens such as `phase0-primary-001`, never actual bank codes or private correspondence. Record Gmail message IDs privately for exact comparisons. Send one fixture at a time initially; concurrency is a separate experiment.

| Fixture | Preconditions / observation | Status |
|---|---|---|
| Primary address | Baseline ordinary delivery, then controlled interception and recovery | Ordinary Inbox arrival owner-confirmed ([evidence](evidence/phase-0/2026-09-04-primary-arrival-baseline.md)); interception and recovery not run |
| Plus-address | Account-supported plus receiving identity | Not run |
| Alias / send-as | Verify actual receiving and sending identity separately | Not run |
| Forwarded mail | Owner-controlled forwarding source and known filter chain | Not run |
| Bcc | Controlled sender; account absent from visible To/Cc | Not run |
| Mailing list | Controlled list identity/headers; no arbitrary forged human message | Not run |
| Automated reply / bounce | Synthetic/controlled automation; Waiting must remain intact | Not run |
| Calendar invitation | Controlled event; no RSVP actions | Not run |
| Authentication-code-like | Synthetic code text only; emergency peek must not release | Not run |
| Attachment | Harmless text file; metadata/body boundaries observed | Not run |
| Existing thread | Older released message plus new held reply; inspect exact message labels | Not run |
| Filter conflict | Known user filter overlap, then documented supported configuration | Not run |
| Concurrent arrival | Freeze A/B, then receive C during retry; C remains outside batch | Not run |
| Spam/Trash exclusion | Controlled existing fixture moved by owner; no automatic resurrection | Not run |
| Explicit bypass | Each claimed rule tested at arrival, including conversation mechanism | Not run |

For unsupported identities or account features, record Not applicable with a reason rather than passing them. Run native notification/badge observations for held arrival, bypass, single/multiple release and release-time arrival on every actual device in scope.

## Execution order

1. Hosted anonymous/synthetic smoke checks; separate worker and migration evidence.
2. Hosted read-only connection and private identity/filter inventory.
3. Prepare exact controlled filter proposal, rollback and filled offline recovery card. Obtain the required owner consent/account action for additional scopes and test activation.
4. One-message intercept → direct Gmail discovery → disable filter → restore → new arrival. Record provider state before extending scope.
5. Broader identity/filter and device matrix, then finite-release/recovery faults from the proof plan.
6. Independent alert receipt and isolated Render/R2 restore rehearsals. No full Room or personal dogfood until exit review.
