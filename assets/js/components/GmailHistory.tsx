export type HistoryStatus = {
  state: 'not_started' | 'pending' | 'ready';
  members: number;
  available: number;
  unavailable: number;
  revision: number;
  checked_at: number | null;
  mode: 'full' | 'incremental' | 'rescan' | 'expired_rescan' | null;
  error: string | null;
};

export default function GmailHistory({ history, csrfToken }: { history: HistoryStatus | null; csrfToken: string }) {
  const started = history && history.state !== 'not_started';
  return (
    <section className="connect-prompt" aria-labelledby="history-heading">
      <h2 id="history-heading">Saved message history</h2>
      <p>Checks label changes for the four messages already saved by the single-message and batch tests. No messages are opened, marked as read, or moved. New arrivals are outside this test.</p>
      <p role="status">{history?.checked_at
        ? `Last successful check: ${new Date(history.checked_at * 1000).toLocaleString()}. ${history.members} saved messages; ${history.available} available, ${history.unavailable} unavailable.`
        : 'No completed check yet. The same four messages will be used for every check.'}</p>
      {history?.error && <p className="feedback" role="alert">The latest check failed. Counts above describe the last successful check, if any. Retry to continue; the saved message set is unchanged.</p>}
      {history?.mode === 'expired_rescan' && <p className="detail">The last successful check recovered from expired history by rereading the saved messages.</p>}
      <form method="post" action="/gmail/history/sync">
        <input type="hidden" name="_csrf_token" value={csrfToken} />
        <button type="submit">Check saved message history</button>
      </form>
      {started && (
        <form method="post" action="/gmail/history/rescan">
          <input type="hidden" name="_csrf_token" value={csrfToken} />
          <button type="submit">Rescan saved messages</button>
          <p className="detail">Rereads every saved message and catches up on changes during the scan. This does not reset the batch or add new messages.</p>
        </form>
      )}
    </section>
  );
}
