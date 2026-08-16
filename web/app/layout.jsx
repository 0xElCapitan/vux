import Link from 'next/link';
import './globals.css';
import Providers from './providers';

export const metadata = {
  title: 'VUX',
  description: 'VUX — mine while you hold the throne. A truth surface, not a dashboard.',
};

const NAV = [
  { href: '/', label: 'Throne' },
  { href: '/redeem', label: 'Redeem' },
  { href: '/accounting', label: 'Accounting' },
  { href: '/treasury', label: 'Treasury' },
  { href: '/trust', label: 'Trust' },
];

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <header className="site-header">
          <Link href="/" className="brand">VUX</Link>
          <nav aria-label="Primary">
            {NAV.map((n) => (
              <Link key={n.href} href={n.href} data-testid={`nav-${n.label.toLowerCase()}`}>{n.label}</Link>
            ))}
          </nav>
        </header>
        <main className="site-main"><Providers>{children}</Providers></main>
        <footer className="site-footer">
          <p>
            Read-only. This interface holds no keys and no custody; it reads the chain and builds
            transactions your wallet signs.
          </p>
        </footer>
      </body>
    </html>
  );
}
