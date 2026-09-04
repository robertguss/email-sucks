# Desk-inspired read-only preview

Date: 2026-09-04

Status: Implemented and verified locally. This is the visual foundation for the existing diagnostic preview, not the full Desk or Room. Gmail authorization, retrieval, refresh, and mutation permissions have not changed.

## Design references and choices

References: [Desk mockup](../../../design/claude-design-mockups/03-desk.dc.html), [dark Desk mockup](../../../design/claude-design-mockups/07-desk-dark-mode.dc.html), and the owner's `design` skill.

- A 600px desktop reading column, Newsreader typography, whitespace-separated message rows, restrained text controls, white/light and near-black/dark surfaces, and teal/warm accent treatments follow the mockups.
- Mobile uses a fluid single column, wrapping metadata, larger supporting text and expanded touch targets. Long subjects and addresses wrap instead of overflowing.
- Secondary text has stronger contrast than the source mockups. Real unread state is labeled in words as well as marked visually. No fictional horizons, shortcuts, triage actions, snippets or delivery states have been added.
- Existing connection/check/sign-out actions remain available in an accessible native disclosure. Disconnected/reconnect prompts remain prominent. Loading, empty-list and error feedback remain visible and distinguishable.
- The system color-scheme preference selects the theme. No manual preference or extra storage was introduced.
- Newsreader is bundled and served locally, with its OFL license in `assets/fonts/OFL.txt`; opening the app does not contact a font CDN. The font was obtained from the Google Fonts stylesheet referenced by the mockups and the license from the Google Fonts repository on this date.
- Used the project's existing CSS/esbuild pattern; no Tailwind migration or new JavaScript dependency was needed. The owner's explicit Newsreader/mockup direction takes precedence over the skill's generic Inter default.

Loaded design guidance: general, typography, colors, custom fonts, dark mode, surfaces, buttons, interactivity, responsive design, flexbox, section layout, navigation, headers, footers, copywriting, border radius, form controls, badges, login pages and heading groups. A single footer link needs no separate collapsed mobile navigation system.

## Verification

- 47 backend tests pass; no backend logic changed.
- Seven Chromium tests pass, including navigation, explicit loading, HTML-like subjects as literal text, non-persistence, hiding, empty/error/reconnect states, and four desktop/mobile light/dark layout checks.
- Layout tests verify the local font loads, horizontal overflow is absent, the connection disclosure exposes its controls, and actual keyboard navigation receives a visible focus outline.
- TypeScript checking, asset build, formatting and git whitespace checks pass.
- Inspected desktop light and mobile dark screenshots, plus empty and error-state captures. Screenshots use only synthetic fixture mail; no personal email data is saved here.

## Visual evidence

| Desktop | Mobile |
|---|---|
| [Light](desk-preview/desktop-light.png) | [Light](desk-preview/mobile-light.png) |
| [Dark](desk-preview/desktop-dark.png) | [Dark](desk-preview/mobile-dark.png) |

The first focus test used programmatic focus after a mouse click, which correctly did not trigger `:focus-visible`. It was corrected to use the Tab key and assert keyboard focus and an outline; the application focus styling passed.

## Next action

Review the updated preview, then work through the Phase 0 state/transition contract, starting with the existing-Inbox onboarding policy. Full Room development remains behind the Phase 0 safety gates. See [PROGRESS.md](../../../PROGRESS.md) for the current queue.
