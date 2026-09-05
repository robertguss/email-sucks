import { useEffect, useRef, useState } from 'react';

export type TrialSummary = {
  state: 'not_started' | 'starting' | 'active' | 'stopping' | 'stopped';
  next_due: string | null; error: string | null; latest_run_id: string | null; running: boolean;
  instructions: null | { sender: string; recipient: string; subject: string; marker: string };
};

const pendingRequestKey = 'delivery-trial-pending-request';

export default function TrialControls({ csrf_token, onChange }: { csrf_token: string; onChange: (summary: TrialSummary | null) => void }) {
  const [trial, setTrial] = useState<TrialSummary | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const request = useRef<AbortController | null>(null);
  const mounted = useRef(true);

  async function load(action?: 'start' | 'check-now' | 'stop') {
    if (request.current) return;
    const controller = new AbortController();
    request.current = controller;
    setBusy(true);
    try {
      let requestId: string | undefined;
      if (action === 'check-now') {
        requestId = sessionStorage.getItem(pendingRequestKey) ?? crypto.randomUUID();
        sessionStorage.setItem(pendingRequestKey, requestId);
      }
      const response = await fetch(`/gmail/trial${action ? `/${action}` : ''}`, {
        method: action ? 'POST' : 'GET', cache: 'no-store', signal: controller.signal,
        ...(action ? { headers: { 'content-type': 'application/json', 'x-csrf-token': csrf_token }, body: JSON.stringify(action === 'check-now' ? { request_id: requestId } : {}) } : {}),
      });
      if (!response.ok) throw new Error(response.status === 401 ? 'Reconnect your Gmail account to continue.' : 'We couldn’t confirm the trial state. Refresh status or retry the action.');
      const next = await response.json() as TrialSummary;
      if (!mounted.current) return;
      setTrial(next); setError(null); onChange(next);
      if (action === 'check-now') { sessionStorage.removeItem(pendingRequestKey); setNotice('Check requested. Your next scheduled delivery stays in place.'); }
      if (action === 'stop') setNotice(null);
    } catch (failure) {
      if (!controller.signal.aborted && mounted.current) {
        setError(failure instanceof Error ? failure.message : 'Trial status is unavailable.');
        onChange(null);
      }
    } finally {
      request.current = null;
      if (mounted.current) setBusy(false);
    }
  }

  useEffect(() => {
    mounted.current = true;
    void load();
    return () => { mounted.current = false; request.current?.abort(); };
  }, []);
  useEffect(() => {
    if (!trial || trial.state === 'not_started' || trial.state === 'stopped') return;
    const timer = window.setInterval(() => void load(), 5000);
    return () => window.clearInterval(timer);
  }, [trial?.state]);

  const due = trial?.next_due ? new Date(trial.next_due) : null;
  const overdue = due && due.getTime() <= Date.now();
  return <section className="trial-controls" aria-label="Delivery trial">
    <h2>{trial?.state === 'stopped' ? 'Trial stopped' : 'Try a quieter delivery rhythm'}</h2>
    {!trial && !error && <p className="detail">Loading trial status…</p>}
    {trial?.state === 'not_started' && <p className="detail">Start a controlled trial with test mail. Matching messages wait outside Inbox and arrive together every five minutes.</p>}
    {trial?.state === 'starting' && <p className="detail">Setup has not been confirmed. Retry setup before sending any test mail.</p>}
    {trial?.state === 'active' && <>
      <p className="detail" role="status">{trial.running ? 'Checking and delivering saved test mail…' : overdue ? 'Delivery is overdue. Waiting for confirmation.' : 'Test mail is held until the next delivery.'}</p>
      {due && <p className="detail">Next delivery: <time dateTime={trial.next_due!}>{due.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit', second: '2-digit', timeZoneName: 'short' })}</time></p>}
      {trial.instructions && !error && !trial.error && <details className="trial-instructions"><summary>Send a test message</summary><p>Use these exact details. Include the marker in the message body. Only matching test mail enters this trial.</p><dl>{Object.entries(trial.instructions).map(([key, value]) => <div key={key}><dt>{key === 'marker' ? 'Body marker' : key}</dt><dd>{value}</dd></div>)}</dl></details>}
    </>}
    {trial?.state === 'stopping' && <p className="detail">New delivery jobs are stopped. Cleanup still needs confirmation; retry Stop &amp; restore.</p>}
    {trial?.state === 'stopped' && <p className="detail">The trial filter is removed and eligible held test mail is restored. Saved delivery history remains available.</p>}
    {trial?.error && <p className="feedback" role="alert">The last operation needs attention. Delivery is not confirmed. Retry Check Now or Stop &amp; restore.</p>}
    {error && <p className="feedback" role="alert">{error}</p>}
    {notice && <p className="detail" role="status">{notice}</p>}
    <div className="trial-actions">
      {(trial?.state === 'not_started' || trial?.state === 'starting') && <button type="button" disabled={busy || !!error} onClick={() => void load('start')}>{trial.state === 'starting' ? 'Retry setup' : 'Start delivery trial'}</button>}
      {trial?.state === 'active' && <button type="button" disabled={busy || !!error} onClick={() => void load('check-now')}>Check Now</button>}
      {trial && ['starting', 'active', 'stopping'].includes(trial.state) && <button type="button" disabled={busy} onClick={() => void load('stop')}>Stop &amp; restore</button>}
      <button type="button" disabled={busy} onClick={() => void load()}>Refresh status</button>
    </div>
  </section>;
}
