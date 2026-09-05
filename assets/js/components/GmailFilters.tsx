export type FilterStatus = { state: string; baseline_changed?: boolean; error: string | null; marker: string | null; filters: number; pending: number; excluded: number; restored: number };

type Props = { experiment: FilterStatus | null; settingsAccess: boolean; email: string; csrfToken: string; arrival?: boolean; startAllowed?: boolean };

export default function GmailFilters({ experiment, settingsAccess, email, csrfToken, arrival = false, startAllowed = true }: Props) {
  const state = experiment?.state ?? 'not_started';
  const headingId = arrival ? 'arrival-filters-heading' : 'filters-heading';
  const path = arrival ? '/gmail/arrival-filters' : '/gmail/filters';
  const subject = arrival ? 'phase0-filter-arrival-001' : 'phase0-filter-trash-001';
  return (
    <section className="connect-prompt" aria-labelledby={headingId}>
      <h2 id={headingId}>{arrival ? 'Ordinary arrival hold test' : 'Bounded filter compatibility test'}</h2>
      <p>{arrival ? <>Creates one tracked temporary Gmail filter for test mail from robertguss@gmail.com to {email}. Matching future arrivals are held outside Inbox under a test label. This filter does not move mail to Trash.</> : <>Creates tracked temporary Gmail filters for test mail from robertguss@gmail.com to {email}. The two filters overlap: one holds matching mail outside Inbox under a test label; the other intentionally moves it to Trash.</>} Existing filters remain in place.</p>
      <p>The filters require the subject phrase {subject} and a generated marker. Do not send fixtures until the saved state is active and the instructions appear below. This app does not send test mail.</p>
      <p role="status">Filters: {state}. {experiment?.filters ?? 0} tracked filters; {experiment?.pending ?? 0} pending, {experiment?.excluded ?? 0} excluded messages, {experiment?.restored ?? 0} restored.</p>
      {experiment?.baseline_changed && <p role="alert">An original Gmail filter changed during this experiment. Cleanup preserves that change; review your Gmail filters before interpreting the test results.</p>}
      {experiment?.error && <p role="alert">The latest operation could not be verified. Saved work remains available for recovery or cleanup.</p>}
      {!settingsAccess && state !== 'disabled' && (startAllowed || state !== 'not_started') && <form method="post" action="/auth/google">
        <input type="hidden" name="_csrf_token" value={csrfToken} />
        <input type="hidden" name="purpose" value="filters" />
        <p>Opt in to Gmail filter settings permission for this experiment. Google grants broader settings access; the app limits this test to its tracked filters.</p>
        <button type="submit">Allow filter settings access</button>
      </form>}
      {!startAllowed && state === 'not_started' && <p>Complete cleanup of the Trash compatibility test above before starting this ordinary arrival test.</p>}
      {settingsAccess && startAllowed && state === 'not_started' && <details className="connection-details">
        <summary>{arrival ? 'Review and start the ordinary arrival test' : 'Review and start the filter test'}</summary>
        <p>Activation creates filters for future matching arrivals. Disabling first removes those filters, then restores eligible held test mail to Inbox while preserving its unread state. Trash, Spam, Drafts, and unexpected matches stay excluded for manual review.</p>
        <form method="post" action={`${path}/activate`}>
          <input type="hidden" name="_csrf_token" value={csrfToken} />
          <button type="submit">{arrival ? 'Activate ordinary arrival filter' : 'Activate temporary test filters'}</button>
        </form>
      </details>}
      {state === 'active' && experiment?.marker && <div className="connection-content">
        <h3>Active test marker</h3>
        <p className="account-address">{experiment.marker}</p>
        <p>Send exactly one test message from robertguss@gmail.com to {email}, with subject {subject} and the marker above in its body. {arrival ? 'Leave the message unopened and in place until inspection. Cleanup restores eligible held mail to Inbox while preserving its unread state.' : 'This message intentionally goes to Trash. Inspect before disabling; recovery leaves Trash untouched.'}</p>
      </div>}
      {['active', 'disabled'].includes(state) && <form method="post" action={`${path}/inspect`}>
        <input type="hidden" name="_csrf_token" value={csrfToken} />
        <button type="submit">Inspect filter test</button>
        <p className="detail">Reads Gmail and updates saved evidence without changing filters or messages.</p>
      </form>}
      {settingsAccess && ['preparing', 'disabling'].includes(state) && <form method="post" action={`${path}/recover`}>
        <input type="hidden" name="_csrf_token" value={csrfToken} />
        <button type="submit">Recover filter operation</button>
      </form>}
      {settingsAccess && ['preparing', 'active', 'disabling'].includes(state) && <form method="post" action={`${path}/disable`}>
        <input type="hidden" name="_csrf_token" value={csrfToken} />
        <button type="submit">Disable filters and restore eligible mail</button>
      </form>}
      {state === 'disabled' && <p>Cleanup is complete. The durable record remains saved; this experiment cannot be restarted.</p>}
    </section>
  );
}
