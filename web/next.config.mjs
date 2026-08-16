/**
 * Static export — the architecture the accepted SDD selected Next.js for:
 * "Static-exportable read-only UI; no server-side custody of anything"
 * (sdd.md:L449), "read-only truth surfaces plus transaction builders; none holds
 * keys or custody" (sdd.md:L453), "no server-side session state" (sprint.md:L450).
 *
 * This is also the accepted refreeze's §5.5 binding obligation, made mechanical.
 * `output: 'export'` produces a directory of static files with NO Node server,
 * and therefore no React Server Components endpoint and no Server Function
 * endpoint — the precise scope condition under which the React advisory says an
 * application is unaffected by CVE-2025-55182.
 *
 * `scripts/verify-static-export.mjs` asserts the built output actually has that
 * shape, because a config value is a statement of intent and the build output is
 * the fact.
 *
 * @type {import('next').NextConfig}
 */
const nextConfig = {
  output: 'export',
  // Static export cannot run the image optimizer (it is a server route).
  images: { unoptimized: true },
  // Fail the build on a lint error rather than shipping a truth surface that
  // only mostly passed.
  eslint: { ignoreDuringBuilds: false },
  reactStrictMode: true,
};

export default nextConfig;
