# Ordinary arrival deployment and activation

Date: 2026-09-05, approximately 16:48 UTC. Revision: `75f7f0e`.
Result: deployment, provider activation/readback and operational health passed.
The owner fixture and arrival/recovery proof are pending.

After the owner unlocked the existing 1Password SSH agent, the reviewed image
was built and deployed to the existing exe.dev web and worker. No migration or
ownership reset occurred. Both containers are healthy and readiness returned ok.
The authenticated browser's Check connection completed successfully.

Before activation, the primary journal was disabled and the ordinary journal was
not_started. The three original Gmail filters matched the private baseline;
the controlled batch remained released at revision four with zero pending/errors.
A private offline recovery card and complete before snapshot were saved on the
owner Mac under `~/.config/email-sucks/hosted-cougar-cedar/ordinary-arrival/`.

Activation used the deployed authenticated browser form. Independent tracked
inspection then verified one active owned Hold-only filter, zero pending/errors,
zero observed fixtures and no baseline drift. Exact criteria, ownership ID and
fresh marker were appended to the private recovery card. Primary and batch
summaries remain equal to their pre-activation snapshots; all original filters
remain unchanged. The hosted monitor check-only result is healthy.

Next: one owner-sent message with the exact subject/body displayed in the ordinary
arrival panel, then message-level inspection, tracked filter removal/restoration,
and repeat cleanup verification. Do not send from the agent or reuse the completed
Trash fixture. General interception, scheduled Gmail delivery and sending remain
disabled. This record does not claim arrival or native-device proof.
