// No APK credentials: only this Worker can write to the fixed tester issue.
const REPO = "crownfall90-dot/mobile-game";
const ISSUE = 5;
const API = `https://api.github.com/repos/${REPO}/issues/${ISSUE}/comments`;
const MAX_BYTES = 65536;
const reply = (status, data) => Response.json(data, { status, headers: { "Cache-Control": "no-store" } });

async function readReport(request) {
  if (!request.headers.get("content-type")?.startsWith("application/json")) throw new Error("invalid");
  if (Number(request.headers.get("content-length")) > MAX_BYTES) throw new Error("large");
  const reader = request.body?.getReader();
  if (!reader) throw new Error("invalid");
  const chunks = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BYTES) { await reader.cancel(); throw new Error("large"); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  const data = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  if (!data || Array.isArray(data) || typeof data !== "object") throw new Error("invalid");
  if (typeof data.id !== "string" || !/^[a-f0-9]{32}$/.test(data.id) || !["bug", "crash", "idea"].includes(data.kind)) throw new Error("invalid");
  if (typeof data.text !== "string" || (data.text.trim().length < 10 && !data.context) || data.text.length > 1500) throw new Error("invalid");
  const out = { id: data.id, kind: data.kind, text: data.text.trim() };
  for (const key of ["version", "screen", "location", "level", "viewport", "os", "model"]) {
    if (typeof data[key] !== "string" || data[key].length > 100 || /[\x00-\x1f]/.test(data[key])) throw new Error("invalid");
    out[key] = data[key];
  }
  for (const [key, max] of [["context", 4096], ["diagnostics", 8000]]) {
    if (data[key] === undefined) continue; // Legacy packets keep their original hash on retry.
    if (typeof data[key] !== "string" || data[key].length > max || /[\x00-\x08\x0b\x0c\x0e-\x1f]/.test(data[key])) throw new Error("invalid");
    out[key] = data[key];
  }
  if (data.automatic !== undefined) {
    if (data.automatic !== true || data.kind !== "crash") throw new Error("invalid");
    out.automatic = true;
  }
  return out;
}

// Keep user content literal: no injected mentions, links, HTML or report markers.
const literal = value => value.replace(/[&<>@`]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "@": "&#64;", "`": "&#96;" }[c]));
const marker = id => `<!-- vita-feedback:${id} -->`;
function comment(report) {
  return `### ${({ bug: "Баг", crash: "Вылет", idea: "Улучшение" })[report.kind]} из Vita\n\n<pre>${literal(report.text || "Без дополнительного описания")}</pre>\n\n`
    + Object.entries(report).filter(([key, value]) => !["id", "kind", "text", "context", "diagnostics", "automatic"].includes(key) && value)
      .map(([key, value]) => `- ${key}: ${literal(value)}`).join("\n")
    + ["context", "diagnostics"].filter(key => report[key]).map(key =>
      `\n\n<details><summary>${key === "context" ? "Момент игры" : "Технические данные"}</summary>\n<pre>${literal(report[key])}</pre>\n</details>`).join("")
    + `\n\n${marker(report.id)}`;
}
async function digest(text) {
  return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text))), b => b.toString(16).padStart(2, "0")).join("");
}

export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname;
    const ready = !!(env.GITHUB_TOKEN && env.RATE_SALT && env.INBOX && env.RATE_LIMIT);
    if (path === "/health" && request.method === "GET") return reply(ready ? 200 : 503, { ready });
    if (path !== "/feedback") return reply(404, { error: "not_found" });
    if (request.method !== "POST") return reply(405, { error: "method" });
    if (!ready) return reply(503, { error: "not_ready" });
    const ip = request.headers.get("CF-Connecting-IP") || "local";
    const key = await digest(`${env.RATE_SALT}:${ip}`);
    if (!(await env.RATE_LIMIT.limit({ key })).success) return reply(429, { error: "rate_limit" });
    let report;
    try { report = await readReport(request); }
    catch (e) { return reply(e.message === "large" ? 413 : 400, { error: "invalid_report" }); }
    // ponytail: one serialized inbox suits a small APK test; split by report ID if traffic grows.
    const inbox = env.INBOX.get(env.INBOX.idFromName("vita-testers"));
    return inbox.fetch(new Request("https://inbox/", { method: "POST", body: JSON.stringify(report) }));
  },
};

export class FeedbackInbox {
  constructor(state, env) { this.state = state; this.env = env; }

  async github(url, options = {}) {
    return fetch(url, { ...options, signal: AbortSignal.timeout(6000), headers: {
      "Authorization": `Bearer ${this.env.GITHUB_TOKEN}`, "Accept": "application/vnd.github+json",
      "Content-Type": "application/json", "User-Agent": "Vita-test-feedback",
    } });
  }

  async fetch(request) {
    return this.state.blockConcurrencyWhile(async () => {
      try { return await this.deliver(await request.json()); }
      catch { return reply(503, { error: "retry" }); }
    });
  }

  async deliver(report) {
    const api = report.automatic ? `https://api.github.com/repos/${REPO}/issues` : API;
    const validUrl = value => report.automatic
      ? new RegExp(`^https://github.com/${REPO}/issues/[0-9]+$`).test(value || "")
      : value?.startsWith(`https://github.com/${REPO}/issues/${ISSUE}#issuecomment-`);
    const hash = await digest(JSON.stringify(report));
    const key = "report:" + report.id;
    const previous = await this.state.storage.get(key);
    if (previous && previous.hash !== hash) return reply(409, { error: "id_conflict" });
    if (previous?.url) return reply(200, { ok: true, url: previous.url });
    if (previous) {
      // A lost POST response is ambiguous: search for its marker, never blindly post twice.
      let url = `${api}?state=all&since=${encodeURIComponent(previous.since)}&per_page=100`;
      for (let page = 0; page < 3; page++) {
        const response = await this.github(url);
        if (!response.ok) return reply(503, { error: "retry" });
        const comments = await response.json();
        const found = comments.find(c => c.body?.includes(marker(report.id)));
        if (found && validUrl(found.html_url)) {
          await this.state.storage.put(key, { ...previous, url: found.html_url });
          return reply(200, { ok: true, url: found.html_url });
        }
        const next = response.headers.get("link")?.match(/<([^>]+)>; rel="next"/);
        if (!next) break;
        url = next[1];
      }
      return reply(503, { error: "pending" });
    }
    const today = new Date().toISOString().slice(0, 10);
    const daily = await this.state.storage.get("daily") || { date: today, count: 0 };
    if (daily.date !== today) { daily.date = today; daily.count = 0; }
    if (daily.count >= 200) return reply(429, { error: "daily_limit" });
    daily.count++;
    const pending = { hash, since: new Date(Date.now() - 60000).toISOString() };
    await this.state.storage.put({ [key]: pending, daily });
    const payload = { body: comment(report) };
    if (report.automatic) payload.title = `[Vita ${report.version}] Неожиданное закрытие: ${report.screen || "запуск"} / ${report.location || report.level || "неизвестно"}`;
    const response = await this.github(api, { method: "POST", body: JSON.stringify(payload) });
    if (!response.ok) {
      // An explicit rejection did not create a comment and can be retried safely.
      if (response.status >= 400 && response.status < 500) await this.state.storage.delete(key);
      return reply(503, { error: "github_unavailable" });
    }
    const created = await response.json();
    if (!validUrl(created.html_url)) return reply(503, { error: "retry" });
    await this.state.storage.put(key, { ...pending, url: created.html_url });
    return reply(201, { ok: true, url: created.html_url });
  }
}
