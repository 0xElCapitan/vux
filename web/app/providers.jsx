'use client';

// Client-only provider tree. Both providers are the accepted pinned packages:
// wagmi needs a react-query client, which is why `@tanstack/react-query` is in
// the accepted census. Nothing here runs on a server — the export stays static.

import { useState } from 'react';
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { wagmiConfig } from '../lib/wagmi';

export default function Providers({ children }) {
  const [queryClient] = useState(() => new QueryClient());
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  );
}
