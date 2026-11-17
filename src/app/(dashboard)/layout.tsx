import { redirect } from "next/navigation";

import { ToastProvider } from "@/components/ui/Toast";
import { getSession } from "@/server/backend";

import DevBanner from "./DevBanner";
import Sidebar from "./Sidebar";
import Topbar from "./Topbar";
import styles from "./dashboard.module.css";

/**
 * Every dashboard screen is behind this layout, so the session check happens
 * once. A screen cannot forget it, and there is no route under this group
 * that renders for an anonymous visitor.
 *
 * The frame follows the Mosaic reference: sidebar beside a column that holds
 * a sticky bar above the scrolling content.
 */
export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { user, bypassed } = await getSession();

  if (!user) redirect("/login");

  const identity = { fullName: user.fullName, username: user.username, role: user.role };

  return (
    <ToastProvider>
      <div className={styles.shell}>
        <Sidebar />
        <div className={styles.main}>
          <Topbar user={identity} />
          <main className={styles.content}>
            {bypassed ? <DevBanner /> : null}
            {children}
          </main>
        </div>
      </div>
    </ToastProvider>
  );
}
