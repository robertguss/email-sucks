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
    <main>
      <Head title="Phase 0 · Deliberate email" />
      <p className="eyebrow">Deliberate email / Phase 0</p>
      <h1>Prove the postman.</h1>
      <p className="intro">Before a quieter inbox, a delivery system you can trust.</p>
      {notice && <p role="status">{notice}</p>}
      <section aria-labelledby="connection-heading">
        <h2 id="connection-heading">{gmail_connected ? 'Gmail account connected' : 'No Gmail account connected'}</h2>
        <p>This prototype cannot intercept, release, or send email.</p>
        {gmail_email && <p>{gmail_email} · {gmail_reconnect ? 'Reconnect required' : 'Read-only access'}</p>}
        {gmail_connected && <p>{gmail_checked ? 'The Gmail connection has been checked successfully.' : 'Connected. Check that Gmail is reachable next.'}</p>}
        {gmail_configured && !gmail_connected && (
          <form method="post" action="/auth/google">
            <input type="hidden" name="_csrf_token" value={csrf_token} />
            <button type="submit">{gmail_reconnect ? 'Reconnect Gmail' : 'Connect Gmail'}</button>
          </form>
        )}
        {gmail_connected && (
          <form method="post" action="/gmail/check">
            <input type="hidden" name="_csrf_token" value={csrf_token} />
            <button type="submit">Check connection</button>
            <p className="detail">Reads the account profile only. No messages are downloaded or changed.</p>
          </form>
        )}
        {gmail_email && (
          <form method="post" action="/auth/logout">
            <input type="hidden" name="_csrf_token" value={csrf_token} />
            <button type="submit">Sign out of this app</button>
            <p className="detail">Ends this browser session. Saved Google access remains on this server.</p>
          </form>
        )}
        {!gmail_configured && <p>Google connection setup is not configured on this server.</p>}
      </section>
      {gmail_connected && <RecentMessages />}
      <ol>
        <li><strong>Define the contract.</strong> Keep each delivery finite and every unresolved message visible.</li>
        <li><strong>Test the failures.</strong> Interrupt jobs, retry work, and verify the recorded outcome.</li>
        <li><strong>Rehearse recovery.</strong> Restore ordinary Gmail delivery even when the app is unavailable.</li>
      </ol>
      <Link href="/phase-0/contract">Read the delivery contract <span aria-hidden="true">→</span></Link>
    </main>
  );
}
