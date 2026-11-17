import { redirect } from "next/navigation";

import { getSessionUser } from "@/server/backend";

import LoginForm from "./LoginForm";
import styles from "./login.module.css";

export const metadata = { title: "Sign in" };

export default async function LoginPage() {
  /* Already signed in: go straight through rather than showing a form that
     would sign the same person in again. */
  if (await getSessionUser()) redirect("/dashboard");

  return (
    <main className={styles.page}>
      <div className={styles.card}>
        <p className={styles.brand}>SBI Securities</p>
        <h1 className={styles.title}>Content management</h1>
        <p className={styles.lede}>
          Sign in with your staff username to edit the home page. Changes go live as soon as you
          save them.
        </p>

        <LoginForm />
      </div>
    </main>
  );
}
