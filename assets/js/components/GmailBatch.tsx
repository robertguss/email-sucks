export type BatchStatus = { state: string; total: number; held: number; released: number; pending: number; errors: number };

export default function GmailBatch({ batch, csrfToken }: { batch: BatchStatus | null; csrfToken: string }) {
  const state = batch?.state ?? 'not_started';
  return (
    <section className="connect-prompt" aria-labelledby="batch-heading">
      <h2 id="batch-heading">Three-message batch test</h2>
      <p>Uses exactly three separate emails from robertguss@gmail.com to this account, with subjects phase0-batch-001, phase0-batch-002, and phase0-batch-003. All three must be in Inbox before starting.</p>
      <p>Hold saves this fixed set, then moves it under Postman/Controlled-batch. Release returns those same messages to Inbox. New arrivals stay outside this batch. Read status is preserved.</p>
      <p role="status">Batch: {state}. {batch?.total ?? 0} saved messages; {batch?.held ?? 0} last confirmed held, {batch?.released ?? 0} last confirmed released, {batch?.pending ?? 0} pending, {batch?.errors ?? 0} errors.</p>
      <p className="detail">An error means the latest check failed, even if an earlier result was confirmed. Recovery runs when you request it. Safe disconnect also restores this batch.</p>
      {state === 'not_started' ? (
        <form method="post" action="/gmail/batch/hold">
          <input type="hidden" name="_csrf_token" value={csrfToken} />
          <button type="submit">Hold the three test messages</button>
        </form>
      ) : (
        <>
          {state !== 'released' && <form method="post" action="/gmail/batch/release">
            <input type="hidden" name="_csrf_token" value={csrfToken} />
            <button type="submit">Release the batch to Inbox</button>
          </form>}
          <form method="post" action="/gmail/batch/recover">
            <input type="hidden" name="_csrf_token" value={csrfToken} />
            <button type="submit">Recover / verify batch</button>
          </form>
        </>
      )}
    </section>
  );
}
