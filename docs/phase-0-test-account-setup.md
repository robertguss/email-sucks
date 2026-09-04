# Phase 0 test-account preparation

Status: Preparation only. The current application does not yet have OAuth routes or token storage. Do not activate any Gmail interception filter at this step.

## Account and Google project

Use a dedicated Gmail test mailbox containing synthetic mail. Keep direct Gmail sign-in and account recovery available. Record whether it is consumer Gmail or Workspace and which aliases/forwarding addresses actually exist.

In a separate development Google API project, enable Gmail API and configure the Google Auth Platform branding/audience. For an External app in Testing, list the dedicated mailbox as a test user. Create a **Web application** OAuth client. Store the downloaded secret in a password manager or another private location outside the repository; never paste it into a conversation. [Google OAuth web-server setup](https://developers.google.com/identity/protocols/oauth2/web-server), [Gmail project setup](https://developers.google.com/workspace/gmail/api/quickstart/python)

The proposed callback path is `/auth/google/callback`. Configure exact local and Render callback URLs only when the connection slice establishes the hostname and implements that endpoint. Google requires redirect URI matching; a placeholder URL is not an operational integration.

## Scope inventory to verify during connection work

| Capability | Candidate scopes / validation |
|---|---|
| Identify the signed-in user | `openid email`; validate stable Google identity and the configured account allowlist |
| Read/synchronize mail and modify labels | `https://www.googleapis.com/auth/gmail.modify` |
| Manage interception filters | `https://www.googleapis.com/auth/gmail.settings.basic` |
| Sending and sending identities | Inventory exact methods before compose; do not add broad scopes speculatively |

`gmail.modify` is powerful and includes capabilities beyond reading. Adding this scope does not mean sending is implemented or enabled. Validate actual granted scopes and endpoint requirements, including identity discovery, before activating interception. [Official Gmail scope reference](https://developers.google.com/workspace/gmail/api/auth/scopes)

Testing-mode token lifetime is unsuitable to assume indefinite authorization; the existing Phase 0 plan includes the seven-day refresh-token issue and a later dogfood authorization gate. Test revocation and reconnect explicitly.

## What the owner needs to provide

Provide the dedicated test account address and whether the OAuth client exists. Configure the client secret through the private environment/secret store when the OAuth implementation specifies the required keys. No secrets belong in tracked files, browser storage, logs, screenshots, or chat.

For Render, the next setup also needs the selected region, service/database plans, and independent alert destination. These choices will be documented before provisioning. Development and production will have separate credentials and databases.
