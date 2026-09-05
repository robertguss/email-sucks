type Props = { phase: 'restoring' | 'revoking' | null; csrfToken: string };

export default function GmailDisconnect({ phase, csrfToken }: Props) {
  return (
    <details className="connection-details" open={phase !== null}>
      <summary>{phase ? 'Disconnect pending' : 'Disconnect Gmail safely'}</summary>
      <div className="connection-content">
        <h2>{phase ? 'Finish disconnecting' : 'Restore mail before removing access'}</h2>
        <p>Restores the controlled test message to Inbox and checks Gmail before requesting revocation. If recovery fails, access stays saved so you can retry.</p>
        <p>Google revocation removes all permissions granted to this Google project, including its other app clients. The recovery record stays saved. This prototype has no automatic interception filters to remove.</p>
        {phase && <p role="status">{phase === 'restoring' ? 'Recovery is unfinished. Mail operations are paused. Resume to restore and verify the controlled message.' : 'Mail recovery was verified. Revocation is unconfirmed; retry uses the saved token without changing mail again.'}</p>}
        <form method="post" action="/gmail/disconnect">
          <input type="hidden" name="_csrf_token" value={csrfToken} />
          <input type="hidden" name="confirm" value="disconnect" />
          <button type="submit">{phase ? 'Resume safe disconnect' : 'Restore test message and revoke access'}</button>
        </form>
        {phase === 'restoring' && <form method="post" action="/auth/google">
          <input type="hidden" name="_csrf_token" value={csrfToken} />
          <button type="submit">Reconnect for recovery</button>
          <p className="detail">Use if Google access has expired or been revoked. Your disconnect intent stays saved.</p>
        </form>}
      </div>
    </details>
  );
}
