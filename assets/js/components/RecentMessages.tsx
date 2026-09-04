import { useEffect, useRef, useState } from 'react';

type Message = { id: string; sender: string; subject: string; received_at: string; unread: boolean };

export default function RecentMessages() {
  const [messages, setMessages] = useState<Message[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const request = useRef<AbortController | null>(null);
  useEffect(() => () => request.current?.abort(), []);

  async function load() {
    request.current?.abort();
    const controller = new AbortController();
    request.current = controller;
    setMessages(null);
    setError(null);
    setLoading(true);
    try {
      const response = await fetch('/gmail/messages', { cache: 'no-store', signal: controller.signal });
      if (!response.ok) {
        setError(response.status === 401 ? 'reconnect' : 'unavailable');
        return;
      }
      const data = await response.json() as { messages: Message[] };
      setMessages(data.messages);
    } catch {
      if (!controller.signal.aborted) setError('unavailable');
    } finally {
      if (!controller.signal.aborted) setLoading(false);
    }
  }

  return (
    <section className="mail-preview" aria-labelledby="recent-heading" aria-busy={loading}>
      <div className="mail-toolbar">
        <h2 id="recent-heading">Recent Inbox messages</h2>
        <button className="primary-action" type="button" onClick={() => void load()} disabled={loading}>{loading ? 'Loading messages…' : 'Load recent messages'}</button>
      </div>
      <p className="detail">Up to five messages. Nothing is opened or marked as read.</p>
      <div className="list-status" role="status" aria-live="polite">
        {loading && <p>Reading your Inbox…</p>}
        {messages && <p>{messages.length ? `Loaded ${messages.length} ${messages.length === 1 ? 'message' : 'messages'}.` : 'No Inbox messages to show.'}</p>}
      </div>
      {error && <p className="feedback" role="alert">{error === 'reconnect' ? <>Your session or Google access has expired. <a href="/">Return to connection setup</a> to reconnect.</> : 'Could not load messages. Please try again.'}</p>}
      {messages && messages.length > 0 && (
        <>
          <ul className="message-list" role="list">
            {messages.map(message => (
              <li key={message.id} className={message.unread ? 'message-unread' : undefined}>
                <p className="message-meta"><time dateTime={message.received_at}>{new Date(message.received_at).toLocaleString(undefined, { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })}</time>{message.unread && <span>Unread</span>}</p>
                <p className="message-sender">{message.sender}</p>
                <h3>{message.subject}</h3>
              </li>
            ))}
          </ul>
          <button type="button" onClick={() => setMessages(null)}>Hide messages</button>
        </>
      )}
    </section>
  );
}
