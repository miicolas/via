import {
  connect,
  type ClientHttp2Session,
  type IncomingHttpHeaders,
} from "node:http2";

type HTTP2RequestInit = Pick<
  RequestInit,
  "method" | "headers" | "body" | "signal"
>;

export type APNsHTTP2Client = {
  request(input: string | URL, init: HTTP2RequestInit): Promise<Response>;
  close(): void;
};

/**
 * Bun's fetch can reject an otherwise valid APNs HTTP/2 response as
 * `Malformed_HTTP_Response`. Keep APNs on Node's HTTP/2 client instead of
 * falling back to HTTP/1.1, which APNs does not support for provider requests.
 */
export function createAPNsHTTP2Client(): APNsHTTP2Client {
  const sessions = new Map<string, ClientHttp2Session>();

  function sessionFor(origin: string): ClientHttp2Session {
    const existing = sessions.get(origin);
    if (existing && !existing.destroyed && !existing.closed) return existing;

    const session = connect(origin);
    // A busy alert cycle can have more than ten simultaneous device streams.
    // The per-request error listeners are removed as soon as their stream ends.
    session.setMaxListeners(0);
    const remove = () => {
      if (sessions.get(origin) === session) sessions.delete(origin);
    };
    session.once("close", remove);
    session.once("error", remove);
    session.once("goaway", remove);
    sessions.set(origin, session);
    return session;
  }

  function discard(origin: string, session: ClientHttp2Session) {
    if (sessions.get(origin) === session) sessions.delete(origin);
    if (!session.destroyed) session.destroy();
  }

  async function request(
    input: string | URL,
    init: HTTP2RequestInit,
  ): Promise<Response> {
    if (
      init.body !== undefined &&
      init.body !== null &&
      typeof init.body !== "string"
    ) {
      throw new TypeError("The APNs HTTP/2 client only accepts string bodies.");
    }

    const url = new URL(String(input));
    const origin = url.origin;
    let lastError: unknown;

    // A GOAWAY or a connection reset can race the first stream. Reopen once;
    // APNs responses with an HTTP status are returned normally and are never
    // retried here.
    for (let attempt = 0; attempt < 2; attempt += 1) {
      let session: ClientHttp2Session | undefined;
      try {
        session = sessionFor(origin);
        return await requestOnSession(session, url, init);
      } catch (error) {
        lastError = error;
        if (session) discard(origin, session);
        if (init.signal?.aborted || attempt === 1) throw error;
      }
    }

    throw lastError ?? new Error("APNs HTTP/2 request failed.");
  }

  return {
    request,
    close() {
      for (const session of sessions.values()) {
        if (!session.destroyed) session.destroy();
      }
      sessions.clear();
    },
  };
}

function requestOnSession(
  session: ClientHttp2Session,
  url: URL,
  init: HTTP2RequestInit,
): Promise<Response> {
  const signal = init.signal ?? undefined;
  const requestHeaders = new Headers(init.headers);
  const headers: Record<string, string> = {};
  requestHeaders.forEach((value, key) => {
    headers[key] = value;
  });

  return new Promise((resolve, reject) => {
    let settled = false;
    let responseHeaders: IncomingHttpHeaders | undefined;
    let responseBody = "";
    let request: ReturnType<ClientHttp2Session["request"]> | undefined;

    const cleanup = () => {
      session.off("error", onSessionError);
      signal?.removeEventListener("abort", onAbort);
    };

    const fail = (error: unknown) => {
      if (settled) return;
      settled = true;
      cleanup();
      request?.destroy();
      reject(error);
    };

    const onSessionError = (error: Error) => fail(error);
    const onAbort = () =>
      fail(
        signal?.reason ??
          new DOMException("The APNs request was aborted.", "AbortError"),
      );

    session.on("error", onSessionError);
    if (signal) {
      if (signal.aborted) {
        onAbort();
        return;
      }
      signal.addEventListener("abort", onAbort, { once: true });
    }

    try {
      request = session.request({
        ":method": init.method ?? "GET",
        ":path": `${url.pathname}${url.search}`,
        ...headers,
      });
      request.setEncoding("utf8");
      request.on("response", (headers) => {
        responseHeaders = headers;
      });
      request.on("data", (chunk: string) => {
        responseBody += chunk;
      });
      request.once("end", () => {
        const headers = responseHeaders;
        const status = headers?.[":status"];
        if (!headers || typeof status !== "number") {
          fail(new Error("APNs returned no HTTP/2 status."));
          return;
        }

        settled = true;
        cleanup();
        resolve(
          new Response(responseBody, {
            status,
            headers: responseHeadersForFetch(headers),
          }),
        );
      });
      request.once("error", fail);
      request.end(init.body ?? undefined);
    } catch (error) {
      fail(error);
    }
  });
}

function responseHeadersForFetch(headers: IncomingHttpHeaders): Headers {
  const result = new Headers();
  for (const [name, value] of Object.entries(headers)) {
    if (name.startsWith(":") || value === undefined) continue;
    result.set(name, Array.isArray(value) ? value.join(", ") : value);
  }
  return result;
}
