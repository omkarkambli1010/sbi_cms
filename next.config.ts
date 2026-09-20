import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  /* Public marketing content is rendered on the server, so nothing here needs
     to widen the client bundle. Any CMS/API origin belongs in a server-only
     environment variable — never in `env` or a NEXT_PUBLIC_* name, both of
     which are inlined into client JavaScript. */
};

export default nextConfig;
