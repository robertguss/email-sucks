# Bounded filter activation

Date: 2026-09-05. Revision: `6679507`, existing exe.dev deployment.
Status: live settings consent, activation and read-back passed; arrival/cleanup
proof pending. No email was sent by the agent.

The owner reported completion of the deployed settings consent flow. Read-back
confirmed connected allowed account, current access token, modification/settings
permission, no disconnect, filter state not_started and the existing three-message
batch released at revision three, zero pending/errors.

Before activation, a new private full filter snapshot matched all three original
filters from the earlier inventory. A private offline recovery card was saved on
the owner Mac. The reviewed FilterExperiment service then performed its preflight
and durable activation using the existing connected credentials. Both Google
creations returned specifications matching the saved intent. A separate inspect
operation verified active state, two filters, zero pending/errors, zero observed
messages and no baseline changes. Final full comparison found exactly the three
unchanged original filters plus the two owned filters.

The exact owned IDs, label, criteria and marker were appended to the offline card
before requesting a fixture. Snapshot/card files are mode0600 in a mode0700 private
directory outside git and the VM. No tokens are included. Direct recovery for
this new filter path has not yet been rehearsed; previous single-fixture direct
recovery remains separate evidence.

Only the controlled sender/recipient, subject phrase and generated random marker
match the two temporary filters. One adds Trash; the other removes Inbox and adds
the dedicated test label. General interception remains off. Next: request one
owner-sent synthetic message, inspect its labels without changing read status,
verify excluded Trash mail cannot be restored by ordinary recovery, then disable
and verify cleanup. Activation alone does not pass the overlap or Phase0 gate.
