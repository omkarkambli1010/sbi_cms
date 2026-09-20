import { redirect } from "next/navigation";

/**
 * This app is the dashboard. It serves no public page of its own — the
 * marketing site does that, reading /api/public/pages/home — so the root
 * sends an editor where they were going anyway.
 */
export default function Root() {
  redirect("/dashboard");
}
