import { Head, Link } from '@inertiajs/react';
import RecentMessages from '../components/RecentMessages';

type Props = {
  gmail_configured: boolean;
  gmail_connected: boolean;
  gmail_email: string | null;
  gmail_reconnect: boolean;
  gmail_checked: boolean;
  csrf_token: string;
  notice: string | null;
};

export default function PhaseZero({ gmail_configured, gmail_connected, gmail_email, gmail_reconnect, gmail_checked, csrf_token, notice }: Props) {
  return (
    <main className="preview">
      <Head title="Inbox preview · Deliberate email" />
      <header className="preview-header">
        <p><Link href="/" aria-label="Homepage">Deliberate email</Link></p>
        <p className="quiet-label">Phase 0 · Read-only</p>
      </header>
      <div className="preview-title">
        <h1>Inbox preview</h1>
        <p>A few recent messages, with room to breathe.</p>
      </div>
      {notice && <p className="feedback" role="status">{notice}</p>}
      {gmail_connected ? <RecentMessages /> : (
        <section className="connect-prompt" aria-labelledby="connection-heading">
          <h2 id="connection-heading">{gmail_reconnect ? 'Reconnect your Gmail account' : 'No Gmail account connected'}</h2>
          <p>{gmail_reconnect ? 'Your Google access has expired or been revoked. Reconnect to continue.' : 'Connect Gmail to preview five recent Inbox messages. Your mail stays just as it is.'}</p>
          {gmail_configured ? (
            <form method="post" action="/auth/google">
              <input type="hidden" name="_csrf_token" value={csrf_token} />
              <button className="primary-action" type="submit">{gmail_reconnect ? 'Reconnect Gmail' : 'Connect Gmail'}</button>
            </form>
          ) : <p className="detail">Google connection setup is not configured on this server.</p>}
        </section>
      )}
      {gmail_email && (
        <details className="connection-details">
          <summary>Connection <span className="connection-state">{gmail_reconnect ? 'Reconnect required' : gmail_checked ? 'Verified' : 'Connected'}</span></summary>
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
        <p>Your mail is unchanged. Interception and sending are not enabled.</p>
        <Link href="/phase-0/contract">Read the delivery contract</Link>
      </footer>
    </main>
  );
}
