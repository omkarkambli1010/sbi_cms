import { NextResponse, type NextRequest } from "next/server";

import { backendOrigin } from "@/server/backend";

/**
 * Every /api/* request is forwarded, unchanged, to the Go service.
 *
 * The browser keeps talking to this origin, so cookies, URLs and the response
 * envelope are exactly what the dashboard was written against. What moved is
 * who owns them: authentication, validation, uploads and every database call
 * now live in cms-backend, which reaches PostgreSQL only through stored
 * routines.
 *
 * This is deliberately dumb. It decides nothing about who may do what — the
 * backend does, and answers 401/403 itself — so there is no second copy of the
 * rules here to drift out of step.
 */

export const dynamic = "force-dynamic";

/* Hop-by-hop headers must not be forwarded, and the body length is the
   backend's to compute. */
const SKIP_REQUEST = new Set(["host", "connection", "content-length", "transfer-encoding", "accept-encoding"]);

async function forward(request: NextRequest): Promise<Response> {
  const target = `${backendOrigin()}${request.nextUrl.pathname}${request.nextUrl.search}`;

  const headers = new Headers();
  request.headers.forEach((value, key) => {
    if (!SKIP_REQUEST.has(key.toLowerCase())) headers.set(key, value);
  });

  const hasBody = request.method !== "GET" && request.method !== "HEAD";

  try {
    const upstream = await fetch(target, {
      method: request.method,
      headers,
      body: hasBody ? request.body : undefined,
      /* Required by undici when the body is a stream. */
      ...(hasBody ? { duplex: "half" } : {}),
      redirect: "manual",
      cache: "no-store",
    } as RequestInit);

    const responseHeaders = new Headers();
    const contentType = upstream.headers.get("content-type");
    if (contentType) responseHeaders.set("content-type", contentType);
    responseHeaders.set("cache-control", "no-store");

    /* Set-Cookie can repeat, so it is copied one value at a time; a plain
       header copy would collapse several cookies into one. */
    for (const cookie of upstream.headers.getSetCookie()) {
      responseHeaders.append("set-cookie", cookie);
    }

    return new Response(upstream.body, { status: upstream.status, headers: responseHeaders });
  } catch (error) {
    console.error("[api] backend unreachable:", (error as Error).message);

    return NextResponse.json(
      {
        ok: false,
        error: {
          message: "The content service is not responding. Nothing can be read or saved until it is.",
          code: "backend_unreachable",
        },
      },
      { status: 503 },
    );
  }
}

export const GET = forward;
export const POST = forward;
export const PUT = forward;
export const PATCH = forward;
export const DELETE = forward;
