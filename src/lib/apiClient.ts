/**
 * The browser's side of the API contract in `src/server/api/respond.ts`.
 *
 * Every route answers `{ ok: true, data }` or `{ ok: false, error }`, so this
 * unwraps the envelope once and throws a typed error the forms can read. A
 * screen therefore never inspects `response.status` or reaches into an error
 * body: it catches `ApiError` and asks it for `fields`.
 */

export interface ApiErrorBody {
  message: string;
  code: string;
  fields?: Record<string, string>;
}

export class ApiError extends Error {
  readonly code: string;
  readonly status: number;
  readonly fields: Record<string, string>;

  constructor(body: ApiErrorBody, status: number) {
    super(body.message);
    this.name = "ApiError";
    this.code = body.code;
    this.status = status;
    this.fields = body.fields ?? {};
  }
}

async function unwrap<T>(response: Response): Promise<T> {
  let payload: unknown;

  try {
    payload = await response.json();
  } catch {
    throw new ApiError(
      { message: "The server sent a response this page could not read.", code: "unreadable" },
      response.status,
    );
  }

  const body = payload as { ok?: boolean; data?: T; error?: ApiErrorBody };

  if (!body.ok) {
    throw new ApiError(
      body.error ?? { message: "Something went wrong.", code: "unknown" },
      response.status,
    );
  }

  return body.data as T;
}

async function send<T>(method: string, path: string, body?: unknown): Promise<T> {
  const response = await fetch(path, {
    method,
    headers: body === undefined ? undefined : { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
    /* Same-origin session cookie; never cache an admin read, or two editors
       see different truths. */
    cache: "no-store",
  });

  return unwrap<T>(response);
}

export const api = {
  get: <T>(path: string) => send<T>("GET", path),
  post: <T>(path: string, body?: unknown) => send<T>("POST", path, body),
  put: <T>(path: string, body?: unknown) => send<T>("PUT", path, body),
  patch: <T>(path: string, body?: unknown) => send<T>("PATCH", path, body),
  del: <T>(path: string) => send<T>("DELETE", path),

  /** Uploads go as multipart, so they bypass the JSON body helper. */
  upload: async <T>(path: string, form: FormData): Promise<T> => {
    const response = await fetch(path, { method: "POST", body: form, cache: "no-store" });
    return unwrap<T>(response);
  },
};
