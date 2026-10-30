const HEADERS = { "Content-Type": "application/json", "X-Upgrade-Editor": "1" };

async function request(method, path, body) {
  const response = await fetch(path, {
    method,
    headers: method === "GET" ? undefined : HEADERS,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const payload = await response.json();
  if (!response.ok) {
    const error = new Error(payload.error ?? "REQUEST");
    error.status = response.status;
    error.errors = payload.errors ?? [];
    throw error;
  }
  return payload;
}

export const api = {
  document: () => request("GET", "/api/document"),
  context: () => request("GET", "/api/context"),
  translations: () => request("GET", "/api/translations"),
  save: (document) => request("PUT", "/api/document", { document }),
  validate: (document) => request("POST", "/api/validate", { document }),
  diff: (document) => request("POST", "/api/diff", { document }),
  reset: () => request("POST", "/api/reset", {}),
};
