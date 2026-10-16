// All calls are relative: nginx (prod) or the Vite dev proxy forwards /api to the backend.
const BASE = "/api/expenses";

async function request(url, options = {}) {
  const res = await fetch(url, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    let detail = `${res.status} ${res.statusText}`;
    try {
      const body = await res.json();
      if (body.detail) {
        detail = typeof body.detail === "string"
          ? body.detail
          : body.detail.map((d) => `${d.loc.slice(-1)[0]}: ${d.msg}`).join("; ");
      }
    } catch {
      /* non-JSON error body */
    }
    throw new Error(detail);
  }
  return res.status === 204 ? null : res.json();
}

export const api = {
  list: (category) => request(category ? `${BASE}?category=${encodeURIComponent(category)}` : BASE),
  summary: () => request(`${BASE}/summary`),
  create: (expense) => request(BASE, { method: "POST", body: JSON.stringify(expense) }),
  remove: (id) => request(`${BASE}/${id}`, { method: "DELETE" }),
  version: () => request("/"),
};
