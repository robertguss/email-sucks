import { createInertiaApp } from '@inertiajs/react';
import { createRoot } from 'react-dom/client';
import PhaseZero from './pages/PhaseZero';
import Contract from './pages/Contract';

const pages = { PhaseZero, Contract };

void createInertiaApp({
  resolve: name => {
    if (!(name in pages)) throw new Error('Unknown application page');
    return pages[name as keyof typeof pages];
  },
  setup({ el, App, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
