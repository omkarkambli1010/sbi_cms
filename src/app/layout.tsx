import type { Metadata } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "SBI Securities CMS",
    template: "%s · SBI Securities CMS",
  },
  description: "Manage the SBI Securities home page.",
  robots: "noindex, nofollow",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        {/* Poppins and Inter are the marketing site's own pairing. Linked
            rather than bundled so a build with no network still succeeds and
            the dashboard falls back to Segoe UI instead of failing. */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        {/* The rule wants fonts in pages/_document, which the App Router does
            not have; a stylesheet in the root layout does apply to every
            page, so the warning does not hold here. */}
        {/* eslint-disable-next-line @next/next/no-page-custom-font */}
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Poppins:wght@500;600&display=swap"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
