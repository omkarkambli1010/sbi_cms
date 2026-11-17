"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

// eslint-disable-next-line @typescript-eslint/no-unused-vars -- `api` is unused only while sign-in is bypassed
import { api, ApiError } from "@/lib/apiClient";

import styles from "./login.module.css";

export default function LoginForm() {
  const router = useRouter();

  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [problem, setProblem] = useState<string | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setProblem(null);
    setErrors({});
    setBusy(true);

    try {
      /* TEMPORARY: sign-in is skipped and the form goes straight to the
         dashboard. The session comes from cms-backend's CMS_DEV_BYPASS_AUTH.
         Restore the call below (and turn the bypass off) before release. */
      // await api.post("/api/auth/login", { username, password });

      /* refresh() as well as push(): the dashboard layout reads the session
         on the server, so the cache for it has to be thrown away or the
         first render after signing in still sees no user. */
      router.push("/dashboard");
      router.refresh();
    } catch (error) {
      if (error instanceof ApiError) {
        setErrors(error.fields);
        /* Only show the banner when no field owns the problem. Otherwise the
           form says "correct the highlighted fields" while highlighting
           nothing, which is what it did before. */
        setProblem(Object.keys(error.fields).length === 0 ? error.message : null);
      } else {
        setProblem("Could not reach the server. Check your connection and try again.");
      }
      setBusy(false);
    }
  }

  return (
    <form className={styles.form} onSubmit={submit} noValidate>
      <label className={styles.label} htmlFor="username">
        Username
      </label>
      <input
        id="username"
        className={styles.input}
        /* type="text" with a numeric inputMode rather than type="number":
           a number input allows e, +, - and a scroll wheel that silently
           changes the value, none of which belong in a staff code. */
        type="text"
        inputMode="numeric"
        autoComplete="username"
        maxLength={20}
        value={username}
        /* Non-digits are dropped as they are typed, so the field can only
           ever hold what the server will accept. */
        onChange={(event) => setUsername(event.target.value.replace(/\D/g, ""))}
        aria-invalid={errors.username ? true : undefined}
        aria-describedby={errors.username ? "username-error" : undefined}
        required
      />
      {errors.username ? (
        <p id="username-error" className={styles.fieldError}>
          {errors.username}
        </p>
      ) : null}

      <label className={styles.label} htmlFor="password">
        Password
      </label>
      <input
        id="password"
        className={styles.input}
        type="password"
        autoComplete="current-password"
        value={password}
        onChange={(event) => setPassword(event.target.value)}
        aria-invalid={errors.password ? true : undefined}
        aria-describedby={errors.password ? "password-error" : undefined}
        required
      />
      {errors.password ? (
        <p id="password-error" className={styles.fieldError}>
          {errors.password}
        </p>
      ) : null}

      {problem ? (
        <p className={styles.problem} role="alert">
          {problem}
        </p>
      ) : null}

      <button className={styles.submit} type="submit" disabled={busy}>
        {busy ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}
