import { Head, Link } from '@inertiajs/react';
import { useCallback, useEffect, useRef, useState } from 'react';

import TrialControls, { type TrialSummary } from '../components/TrialControls';

type MessageStatus = 'available' | 'pending' | 'unavailable';
type Content = { id: string; subject: string; sender: string; preview: string; received_at: string | null; status: MessageStatus };
type Item = { id: string; contents: Content[]; messages: number; reviewed: boolean; status: MessageStatus };
export type BatchViewData = { revision: number | null; run_id?: string | null; state: 'empty' | 'ready' | 'pending'; items: Item[]; total: number; remaining: number; pending: number; unavailable: number };

export default function BatchView({ csrf_token }: { csrf_token: string }) {
  const [trial, setTrial] = useState<TrialSummary | null>(null);
  const onTrialChange = useCallback((summary: TrialSummary | null) => setTrial(summary), []);
  const trialMode = trial !== null && trial.state !== 'not_started';
  const [batch, setBatch] = useState<BatchViewData | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const request = useRef<AbortController | null>(null);

  async function send(item?: Item) {
    request.current?.abort();
    const controller = new AbortController();
    request.current = controller;
    setBusy(true);
    setError(null);
    if (!item) setBatch(null);
    try {
      const response = await fetch(trialMode ? item ? '/gmail/trial/review' : '/gmail/trial/view' : item ? '/gmail/batch-view/review' : '/gmail/batch-view', {
        method: item ? 'POST' : 'GET', cache: 'no-store', signal: controller.signal,
        ...(item ? { headers: { 'content-type': 'application/json', 'x-csrf-token': csrf_token }, body: JSON.stringify({ ...(trialMode ? { run_id: batch?.run_id } : {}), revision: batch?.revision, item_id: item.id, reviewed: !item.reviewed }) } : {}),
      });
      if (!response.ok) {
        setError(response.status === 401 ? 'Your connection needs attention. Return to connection setup to continue.' : response.status === 409 ? 'This delivery changed or is busy. Refresh the delivery before continuing.' : 'We couldn’t confirm the latest state. Refresh the delivery to try again.');
        return;
      }
      setBatch(await response.json() as BatchViewData);
    } catch {
      if (!controller.signal.aborted) setError('We couldn’t confirm the latest state. Refresh the delivery to try again.');
    } finally {
      if (!controller.signal.aborted) setBusy(false);
    }
  }

  useEffect(() => {
    if (trial) void send();
    else { request.current?.abort(); setBatch(null); setBusy(false); }
    return () => request.current?.abort();
  }, [trial?.state, trial?.latest_run_id, trial?.running, trial?.error]);
  const caughtUp = trial && !trial.error && !trial.running && batch && batch.total > 0 && batch.remaining === 0 && batch.pending === 0 && batch.unavailable === 0 && !error;
  return (
    <main className="preview delivery-view">
      <Head title="Your delivery · Deliberate email" />
      <header className="preview-header">
        <p><Link href="/" aria-label="Homepage">Deliberate email</Link></p>
        <nav aria-label="Desktop navigation" className="delivery-desktop-nav"><Link href="/">Connection &amp; test controls</Link></nav>
        <details className="delivery-mobile-nav"><summary>Menu</summary><nav aria-label="Mobile navigation"><Link href="/">Connection &amp; test controls</Link></nav></details>
      </header>
      <div className="preview-title">
        <p className="eyebrow">A little room for your email.</p>
        <h1>{caughtUp ? 'You’re caught up' : batch && (batch.pending > 0 || batch.unavailable > 0) && batch.remaining === 0 ? 'Delivery needs attention' : 'Your delivery'}</h1>
        <p>{caughtUp ? 'Everything in this batch has been reviewed. You can leave it here.' : 'A finite batch. Take it one conversation at a time.'}</p>
      </div>
      <TrialControls csrf_token={csrf_token} onChange={onTrialChange} />
      <section className="delivery-content" aria-label="Batch conversations" aria-busy={busy}>
        <div className="mail-toolbar">
          <p className="list-status" role="status">{!batch ? busy ? 'Loading your delivery…' : 'Delivery not loaded.' : batch.total === 0 ? 'No saved delivery yet.' : `${batch.remaining} ${batch.remaining === 1 ? 'conversation' : 'conversations'} left to review.`}</p>
          <button type="button" disabled={busy || !trial} onClick={() => void send()}>Refresh delivery</button>
        </div>
        {error && <p className="feedback" role="alert">{error} <Link href="/">Connection setup</Link></p>}
        {!!batch?.pending && <p className="feedback">{batch.pending} {batch.pending === 1 ? 'conversation needs' : 'conversations need'} attention before this batch is complete. Check the recovery controls, then refresh.</p>}
        {!!batch?.unavailable && <p className="feedback">{batch.unavailable} {batch.unavailable === 1 ? 'conversation contains' : 'conversations contain'} saved mail that cannot be reviewed here. Check Gmail for the unavailable messages. This batch remains incomplete.</p>}
        {batch?.state === 'empty' && <p className="detail">{trialMode ? 'Your first test delivery will appear here once it has been confirmed.' : <>Your saved test batch will appear here after it has been prepared. <Link href="/">Open test controls</Link>.</>}</p>}
        <ul className="delivery-list" role="list">
          {batch?.items.map(item => (
            <li key={item.id}>
              <article className="delivery-letter" aria-label={item.contents[0]?.subject || 'Untitled conversation'}>
                <p className="detail">{item.status === 'unavailable' ? 'Unavailable' : item.status === 'pending' ? 'Delivery pending' : item.reviewed ? 'Reviewed' : 'To review'}</p>
                {item.contents.map(message => (
                  <section key={message.id} aria-label={message.subject || 'Untitled message'}>
                    <div className="message-meta"><p>{message.sender || 'Sender unavailable'}</p><p>{message.status === 'available' ? 'Available' : message.status === 'pending' ? 'Delivery pending' : 'Unavailable'}</p></div>
                    <h2>{message.subject || 'Untitled message'}</h2>
                    {message.status === 'available' ? <p className="letter-preview">{message.preview || 'No preview text is available for this message.'}</p> : <p className="detail">{message.status === 'pending' ? 'Delivery has not been confirmed yet.' : 'This saved message cannot currently be reviewed.'}</p>}
                    {message.received_at && <p className="detail"><time dateTime={message.received_at}>{new Date(message.received_at).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}</time></p>}
                  </section>
                ))}
                <div className="letter-footer">
                  <p className="detail">{item.messages} {item.messages === 1 ? 'message' : 'messages'}</p>
                  {item.status === 'available' && <button type="button" disabled={busy || !!error} onClick={() => void send(item)}>{item.reviewed ? 'Mark unreviewed' : 'Mark reviewed'}</button>}
                </div>
              </article>
            </li>
          ))}
        </ul>
      </section>
      <footer className="preview-footer"><p>Reviewing is just for this batch. Gmail unread status stays unchanged.</p><p>This controlled trial uses matching test mail. Each delivery keeps its saved membership.</p></footer>
    </main>
  );
}
