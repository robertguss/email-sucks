import { Head, Link } from '@inertiajs/react';
import RecentMessages from '../components/RecentMessages';
import GmailDisconnect from '../components/GmailDisconnect';

type Props = {
  gmail_configured: boolean;
  gmail_connected: boolean;
  gmail_email: string | null;
  gmail_reconnect: boolean;
  gmail_checked: boolean;
  gmail_disconnect_phase?: 'restoring' | 'revoking' | null;
  controlled?: { state: string; verified_at: number | null; repeat_revision?: number } | null;
  csrf_token: string;
  notice: string | null;
};

export default function PhaseZero({ gmail_configured, gmail_connected, gmail_email, gmail_reconnect, gmail_checked, gmail_disconnect_phase, controlled, csrf_token, notice }: Props) {
  return (
    <main className="preview">
      <Head title="Inbox preview · Deliberate email" />
      <header className="preview-header">
        <p><Link href="/" aria-label="Homepage">Deliberate email</Link></p>
        <p className="quiet-label">Phase 0 · Controlled test</p>
      </header>
      <div className="preview-title">
        <h1>Inbox preview</h1>
        <p>A few recent messages, with room to breathe.</p>
      </div>
      {notice && <p className="feedback" role="status">{notice}</p>}
      {gmail_connected ? <RecentMessages /> : !gmail_disconnect_phase && (
        <section className="connect-prompt" aria-labelledby="connection-heading">
          <h2 id="connection-heading">{gmail_reconnect ? 'Reconnect your Gmail account' : 'No Gmail account connected'}</h2>
          <p>{gmail_reconnect ? 'Your Google access has expired or been revoked. Reconnect to continue.' : 'Connect Gmail to preview five recent Inbox messages. The controlled test can also hold and release one fixture message.'}</p>
          {gmail_configured ? (
            <form method="post" action="/auth/google">
              <input type="hidden" name="_csrf_token" value={csrf_token} />
              <button className="primary-action" type="submit">{gmail_reconnect ? 'Reconnect Gmail' : 'Connect Gmail'}</button>
            </form>
          ) : <p className="detail">Google connection setup is not configured on this server.</p>}
        </section>
      )}
      {gmail_connected && (
        <section className="connect-prompt" aria-labelledby="controlled-heading">
          <h2 id="controlled-heading">Controlled hold and release</h2>
          <p>Only “phase0-primary-001” from robertguss@gmail.com to this account. Hold moves this one message out of Inbox under Postman/Controlled-primary-001. Release returns it to Inbox. Read status is preserved.</p>
          <p role="status">Saved state: {controlled?.state ?? 'not_started'}{controlled?.verified_at ? ` · Last verified ${new Date(controlled.verified_at * 1000).toLocaleString()}` : ' · Not yet verified'}</p>
          <p className="detail">Pending means the result is uncertain. Recover / verify checks Gmail and completes the saved intent. Recovery runs when you request it; this is not continuous sync.</p>
          {(controlled?.state ?? 'not_started') === 'not_started' && (
            <form method="post" action="/gmail/controlled/hold">
              <input type="hidden" name="_csrf_token" value={csrf_token} />
              <button type="submit">Hold test message</button>
            </form>
          )}
          {['hold_pending', 'held', 'release_pending'].includes(controlled?.state ?? '') && (
            <form method="post" action="/gmail/controlled/release">
              <input type="hidden" name="_csrf_token" value={csrf_token} />
              <button type="submit">Release to Inbox</button>
            </form>
          )}
          {controlled && controlled.state !== 'not_started' && (
            <form method="post" action="/gmail/controlled/recover">
              <input type="hidden" name="_csrf_token" value={csrf_token} />
              <button type="submit">Recover / verify</button>
            </form>
          )}
          {controlled?.state === 'released' && controlled.repeat_revision !== undefined && (
            <details className="connection-details">
              <summary>Repeat the recovery test</summary>
              <p>Hold the same saved fixture again, then use safe disconnect to test restoring it before access is revoked.</p>
              <form method="post" action="/gmail/controlled/repeat">
                <input type="hidden" name="_csrf_token" value={csrf_token} />
                <input type="hidden" name="repeat_revision" value={controlled.repeat_revision} />
                <button type="submit">Hold the same test message again</button>
              </form>
            </details>
          )}
          <form method="post" action="/auth/google">
            <input type="hidden" name="_csrf_token" value={csrf_token} />
            <button type="submit">Reconnect for Gmail modification access</button>
            <p className="detail">Google grants broader mailbox permission; this app limits changes to the controlled fixture.</p>
          </form>
        </section>
      )}
      {gmail_email && <GmailDisconnect phase={gmail_disconnect_phase ?? null} csrfToken={csrf_token} />}
      {gmail_email && (
        <details className="connection-details">
          <summary>Connection <span className="connection-state">{gmail_disconnect_phase ? 'Disconnect pending' : gmail_reconnect ? 'Reconnect required' : gmail_checked ? 'Verified' : 'Connected'}</span></summary>
          <div className="connection-content">
            <h2>{gmail_connected ? 'Gmail account connected' : 'Saved Google account'}</h2>
            <p className="account-address">{gmail_email}</p>
            {gmail_connected && (
              <form method="post" action="/gmail/check">
                <input type="hidden" name="_csrf_token" value={csrf_token} />
                <button type="submit">Check connection</button>
                <p className="detail">Reads your account profile only.</p>
              </form>
            )}
            <form method="post" action="/auth/logout">
              <input type="hidden" name="_csrf_token" value={csrf_token} />
              <button type="submit">Sign out of this app</button>
              <p className="detail">Ends this browser session. Saved Google access remains on this server.</p>
            </form>
          </div>
        </details>
      )}
      <footer className="preview-footer">
        <p>Only the controlled test can change a message. Automatic interception and sending are not enabled.</p>
        <Link href="/phase-0/contract">Read the delivery contract</Link>
      </footer>
    </main>
  );
}
