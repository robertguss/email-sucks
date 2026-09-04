import { Head, Link } from '@inertiajs/react';

export default function PhaseZero({ gmail_connected }: { gmail_connected: boolean }) {
  return (
    <main>
      <Head title="Phase 0 · Deliberate email" />
      <p className="eyebrow">Deliberate email / Phase 0</p>
      <h1>Prove the postman.</h1>
      <p className="intro">Before a quieter inbox, a delivery system you can trust.</p>
      <section aria-labelledby="connection-heading">
        <h2 id="connection-heading">{gmail_connected ? 'Gmail account connected' : 'No Gmail account connected'}</h2>
        <p>This prototype cannot intercept, release, or send email. Real Gmail experiments have not started.</p>
      </section>
      <ol>
        <li><strong>Define the contract.</strong> Keep each delivery finite and every unresolved message visible.</li>
        <li><strong>Test the failures.</strong> Interrupt jobs, retry work, and verify the recorded outcome.</li>
        <li><strong>Rehearse recovery.</strong> Restore ordinary Gmail delivery even when the app is unavailable.</li>
      </ol>
      <Link href="/phase-0/contract">Read the delivery contract <span aria-hidden="true">→</span></Link>
    </main>
  );
}
