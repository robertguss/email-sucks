# Email Client — Product Spec & MVP

Working title: TBD (internal names: "the postman" for the delivery mechanism, "the room" for the UI)
Status: ideation complete, moving to POC/MVP — September 2026
Scope: web only, Gmail only, single user (me) first

---

## 1. Thesis

Email became a taskmaster because it removed the postman. Mail used to arrive once a day; you sat down, dealt with it, and were done. Email made arrival continuous, made every message look equally urgent, and turned the inbox into an unbounded list with no finish line.

This app restores the postman. Mail is delivered at times **I** set. I sit down to it deliberately, in a minimal room built for that purpose, work it to a real end, and leave. Email is correspondence again, and it is in submission to me rather than the other way around.

Two components that must be designed together:

- **The postman** — a backend mechanism that holds incoming mail out of the Gmail inbox and releases it at scheduled windows. Because it acts on Gmail itself, the Gmail app on my phone is also empty between windows.
- **The room** — a minimal, typography-led web client with five places and a small verb set, where the mind enters "email mode" and leaves when finished.

## 2. Problems being solved

1. **Too much mail, almost all of it noise.** Very few messages need a reply or action. Those should be surfaced; everything else compartmentalized.
2. **No finish line.** The list grows while you work it. "Done" never happens.
3. **Every item is an unmade decision.** Inbox of 40 = 40 small "what do I do with this?" questions.
4. **Invisible open loops.** Things sent and awaited, things promised — buried in Sent and memory.
5. **Arrival = demand.** Mail lands whenever the sender likes and the client presents it as urgent. The unread badge is a scoreboard of failure.
6. **Bad habits.** Checking the phone constantly; treating everything as needing an ASAP reply.
7. **Ugly, confusing clients.** HEY has the right taxonomy and awful execution — too many places, you can't find anything.

## 3. Principles

- **User is always in control.** No autonomous sending or deleting. Every screen is enterable directly; the guided flow is optional.
- **Deterministic first.** Routing uses rules and headers, not a model. AI is layered on later as a suggester, never the router.
- **Hard routing.** Only action mail is shown by default. Missing junk-like mail is acceptable, like physical junk mail.
- **Learns by accumulation.** Each sender decision is made once and becomes a rule. "Smarter over time" means the rule set grows.
- **Fewer places than fingers.** Five screens, always know where you are. No folders, labels, sidebar, tabs, or unread counts.
- **Flow, not navigation.** Screens are full-width, one thing each, one key apart.
- **Default to "not urgent."** New action items default to This Week, not Today. Things get promoted, not demoted.
- **Craft, not gamification.** Steal what games do well (legible state, immediate physical feedback, marked completion, session rhythm). No points, streaks, or badges.
- **Typography carries the design.** Black and white, one typeface, generous space, one accent color meaning exactly one thing.

## 4. Mail model

### 4.1 Two kinds of mail

| Kind | Meaning | Where it lives | Verbs |
|---|---|---|---|
| **Needs you** (action) | Requires a reply or an action from me | The desk | reply, done, move horizon |
| **Aware** (awareness) | Things I should know about; never replied to | The pile | next, keep, later |

Plus a third lane during the learning period:

| **Unsure** | Rules could not place it | A short row above the desk | sort to Needs you / Aware, which writes a sender rule |

### 4.2 Horizons (replaces snooze)

Action items carry a horizon, not a date. The item stays visible, grouped under its horizon; the horizon *is* the commitment.

- **Today**
- **This week** — default for all new action items
- **Whenever**
- **Waiting** — I sent something and expect a reply. Shows elapsed time. Closes itself when a reply arrives in the thread.

Snooze hides and then re-delivers as new, which recreates the interruption. Horizons don't hide anything.

Monday's first session shows This Week as a plan ("here's what you owe by Friday"), not a backlog.

### 4.3 Deterministic routing rules (v1)

Run at release time on the whole batch, in order. First match wins.

**→ Aware**
1. Sender has a per-sender rule → Aware
2. `List-Unsubscribe` header present
3. `Precedence: bulk` or `list` header present
4. `List-Id` header present
5. Sender local part matches `noreply`, `no-reply`, `donotreply`, `notifications`, `newsletter`, `mailer`, `alerts`
6. Gmail category is Promotions, Social, Updates, or Forums (via API `CATEGORY_*` labels)
7. I'm in Cc/Bcc only (not To)

**→ Needs you**
8. Sender has a per-sender rule → Needs you
9. I have previously sent mail to this address (query Sent)
10. Sender is in contacts

**→ Unsure**
11. Everything else

Every manual sort in Unsure (and any correction elsewhere) writes a per-sender rule. Rules are viewable and deletable in settings.

Note: rule 7 (Cc-only) may be too aggressive for some workflows; make it a toggle.

## 5. The postman (delivery mechanism)

### 5.1 Mechanism

1. **Intercept at delivery.** The app creates a Gmail filter via the API matching all mail (e.g. `deliveredto:me@example.com`) with actions: skip inbox, apply label `Held`. Gmail runs filters at delivery, before push notifications fire, so mail never touches INBOX and the phone never buzzes.
2. **Release at windows.** A scheduled job runs at each delivery window: find threads with `Held`, run routing rules, apply `NeedsYou` or `Aware` label, remove `Held`, and add `INBOX` to Needs-you threads (and optionally Aware threads, see 5.3).
3. **Safety net.** If the server dies, mail accumulates safely under `Held` where it is visible in Gmail. Nothing is ever deleted or moved to spam by the app.

### 5.2 Windows

- User-defined times, e.g. 9:00, 13:00, 17:00. **Default: once a day.** More windows are opt-in.
- Manual "check now" always available (user is in control), but it's a deliberate act, not a refresh.
- Between windows the app and Gmail both show an empty inbox.

### 5.3 What the Gmail app shows

Decision needed: at release, add INBOX to Needs-you threads only, or to Aware threads too? Needs-you-only keeps the phone inbox tiny and reinforces the model; both gives full fallback parity. Start with Needs-you-only; Aware stays labeled and reachable in Gmail via label.

### 5.4 The delivery event

One notification per window, never per message: *"Mail's here. 3 need you, 14 to look over."* This is the only notification the app sends. (Web MVP: the doorstep screen itself; the Gmail app's own notification for the released Needs-you threads serves as the phone signal.)

### 5.5 Gmail state as source of truth

Gmail remains the system of record. All app state is expressed as Gmail labels so nothing is lost if the app disappears and Gmail remains a usable fallback:

- `Held`, `NeedsYou`, `Aware`, `Unsure`
- `Horizon/Today`, `Horizon/Week`, `Horizon/Whenever`, `Horizon/Waiting`
- `Keep` (pinned awareness items)

Local DB caches metadata, rules, windows, and session state only.

## 6. The room (UI)

### 6.1 Five places

| # | Place | What it is | Verbs |
|---|---|---|---|
| 1 | **Doorstep** | Home. Between windows: "Nothing needs you. Next mail at 1:00." At a window: "Mail's here. 3 need you, 14 to look over." Shows the day as a quiet line with delivery marks. Shortcut list lives here. | step in / start session |
| 2 | **Pile** | Awareness stack. One message at a time, already open, rendered as clean text (reader-mode for HTML/newsletters, marketing images collapsed, "show original" escape). | next, keep, later |
| 3 | **Desk** | Needs-you, grouped by horizon: Today / This week / Whenever / Waiting. The only list in the app. Unsure row appears above it when non-empty. | reply, done, move horizon, sort (Unsure) |
| 4 | **Page** | Compose. Full screen, plain text, markdown-aware, one typeface, no toolbar. To/Cc/Subject revealed when reached for. Sending returns you to where you were. | send, discard |
| 5 | **Drawer** | Search and archive. Everything ever. Receipts live here, found by search, never browsed. | search, open |

Plus one non-place: **Caught up.** Shown when the desk is empty at the end of a session. States it plainly and shows the next delivery time. Then you leave.

### 6.2 Two ways to use it

- **Direct:** any place is one keystroke away at all times.
- **Session:** optional guided flow from the doorstep: pile → desk → caught up. Escape hatch to the desk at any point.

### 6.3 What is deliberately absent

Folders, labels, sidebar, three-pane layout, tabs, unread counts, per-message notifications, sounds, ambient audio, avatars, badges, streaks.

The only numbers in the app: "N need you", "N to look over", elapsed days on Waiting items.

### 6.4 Visual language

- Black on white (and white on black for dark). Grayscale for all metadata.
- One typeface family, one or two sizes. Serif or humanist sans; decide by feel.
- One accent color used for exactly one thing: marking Needs-you. Chosen only after the grayscale version already feels right.
- Comfortable reading measure (~65–75 characters). Air everywhere.
- Sender, subject, time rendered as quiet metadata, not table columns.
- Motion is reserved for meaning: mail arriving, a card leaving the pile, a loop closing.

### 6.5 Keyboard

Keyboard-first with roughly six verbs, not eighty shortcuts. Suggested: `j/k` or `space` next, `r` reply, `e` done, `h` horizon, `k` keep, `/` search, `1–5` places.

## 7. Small delights (cheap, keep)

- Waiting item closes with a quiet "Sarah replied" at the next delivery.
- Monday's desk shows This Week as a plan.
- The delivery is an *arrival* — a small animation of mail landing.
- Caught-up screen is a real state with its own screen, not an empty list.
- Compose is a room you go to, not a panel that pops over the inbox.

## 8. Captured for later (not MVP)

- **Person-centric desk.** Desk as a short list of *people* you owe a letter, with the whole correspondence as one continuous conversation and a note field per person. Waiting becomes "people who owe you a letter." Fits the correspondence thesis; unproven for all workflows.
- **Reflection, not score.** End of session/week: 3 replies, 14 read, 2 loops closed, 40 minutes. Facts, not a number to beat. Evidence over months that you are on top of things.
- **Card physics** in the pile — cards with weight; "next" as a sweep.
- **Day line** on the doorstep with delivery marks and the next delivery approaching.
- **Brief**: a Cora-style summary of unacknowledged Aware items at each window (needs AI).
- **AI layer** (all deferred): suggested routing for Unsure; drafts in my voice; thread summaries; plain-language rules ("put investment pitches in one place").
- **Bundling** dominating senders into one pile card (HEY Bundles).
- **Rename subject** locally without breaking the thread (HEY).
- **Contact notes** (HEY) — folds into person-centric desk.
- **Clips / attachment library** (HEY) — low priority, drawer search may suffice.
- **Plain-text-first sending** with optional markdown → HTML.
- Desktop and mobile apps; Outlook/IMAP; multiple accounts; product/billing.

## 9. MVP scope (build this)

Goal: live in it for two weeks and find out whether the postman + room changes how email feels. Ugly-but-correct beats pretty-but-incomplete, except that the four screens should already have the typographic bones right.

**Postman**
- [ ] Gmail OAuth; create labels; create the intercept filter
- [ ] Windows setting (default once/day) + scheduled release job
- [ ] Routing rules 1–11; per-sender rules table; corrections write rules
- [ ] Add INBOX to Needs-you on release; leave Aware labeled only
- [ ] "Check now" manual release

**Room**
- [ ] Doorstep (two states + next delivery time)
- [ ] Pile (one at a time, reader-mode rendering, next/keep/later)
- [ ] Desk (grouped by horizon, Unsure row, reply/done/move horizon)
- [ ] Page (full-screen plain-text compose + reply, To/Cc/Subject on reach, send via Gmail API)
- [ ] Drawer (Gmail search passthrough, open a thread)
- [ ] Caught-up screen
- [ ] Keyboard: places 1–5, six verbs
- [ ] Session flow: doorstep → pile → desk → caught up, with escape hatch

**Explicitly not in MVP:** Waiting auto-close (v1.1 — easy via thread reply detection, but not needed to test the thesis), person-centric desk, reflection, animations beyond the arrival, AI, notifications beyond Gmail's own.

## 10. Open questions

- Add INBOX to Aware threads at release or not? (5.3)
- Is Cc-only → Aware too aggressive? (routing rule 7)
- Serif or sans? Decide in mockups.
- One window or two by default for *me*? Start with one; observe.
- What does "later" on a pile item do: stays in pile until next window (simplest), or one-time re-surface at a chosen window?
- What does "keep" hold — a Keep pile reachable from the pile, or a section of the drawer?

## 11. Reference apps

- **HEY** — Screener, Imbox / Feed / Paper Trail taxonomy, Reply Later + Focus & Reply, Bubble Up, Bundles, New-vs-Seen grouping, contact notes, rename subject. Right ideas, poor execution: too many places, dated UI.
- **Cora** — twice-daily brief, only reply-required human mail reaches inbox, archives into a "Next Brief" label, drafts in your voice, cannot send/delete, prompt-your-inbox rules. An overlay, not a client.
- **Swizero** — "email has no finish line" critique; imposes structural limits.
- **Superhuman** — keyboard-first speed; now $33/mo in Grammarly bundle (acquired 2025).
- **Shortwave, Inbox Zero (open source, Gmail), Zero / 0.email (open source, Next.js + Postgres)** — useful code references for Gmail API handling.
- **Notion Mail** — shutting down Sept 22, 2026 (market churn signal).
- **iA Writer, OmmWriter** — distraction-free writing; the "room" concept. No sounds.
- **Things 3, Clear** — craft/physicality references for "game-like without gamification."

## 12. Suggested stack (TypeScript)

Not decided; a reasonable default: Next.js or Remix app, Postgres, Gmail API (REST) with OAuth, a scheduler (cron or a queue) for release jobs, optional Gmail Pub/Sub watch later. Self-hostable.
