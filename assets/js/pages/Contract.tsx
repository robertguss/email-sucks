import { Head, Link } from '@inertiajs/react';

export default function Contract() {
  return (
    <main>
      <Head title="Delivery contract · Deliberate email" />
      <p className="eyebrow">Phase 0 / Safety contract</p>
      <h1>The delivery contract</h1>
      <p className="intro">These are requirements to prove, not claims that Gmail testing has passed.</p>
      <ol>
        <li>Freeze exact message IDs before release. Later arrivals wait for another batch.</li>
        <li>Serialize releases for each account. A retry resumes the same work.</li>
        <li>Record progress per message. Uncertain outcomes remain unresolved until reconciled.</li>
        <li>Disable future interception before restoring held mail.</li>
        <li>Never resend automatically after an ambiguous send result.</li>
        <li>Detect overdue delivery through an independent alert channel.</li>
      </ol>
      <Link href="/">← Back to Phase 0</Link>
    </main>
  );
}
