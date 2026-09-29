// Run: node server/feedback/check.mjs. No live GitHub requests or credentials.
import assert from "node:assert/strict";
import worker, { FeedbackInbox } from "./worker.mjs";

const entries = new Map();
const state = {
  storage: {
    get: async key => structuredClone(entries.get(key)),
    put: async (key, value) => {
      if (typeof key === "object") for (const [k, v] of Object.entries(key)) entries.set(k, structuredClone(v));
      else entries.set(key, structuredClone(value));
    },
    delete: async key => entries.delete(key),
  },
  queue: Promise.resolve(),
  blockConcurrencyWhile(action) {
    const task = this.queue.then(action);
    this.queue = task.catch(() => {});
    return task;
  },
};
const env = { GITHUB_TOKEN: "test-only", RATE_SALT: "test-only", RATE_LIMIT: { limit: async () => ({ success: true }) } };
const inbox = new FeedbackInbox(state, env);
env.INBOX = { idFromName: name => name, get: () => inbox };
const report = { id: "a".repeat(32), kind: "bug", text: "Кнопка не работает\n@someone <script> & test", version: "test", screen: "game", location: "", level: "home_01", viewport: "720x1280", os: "", model: "" };
const request = data => new Request("https://test/feedback", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(data) });
const url = "https://github.com/crownfall90-dot/mobile-game/issues/5#issuecomment-123";
let posts = 0;
const realFetch = globalThis.fetch;
globalThis.fetch = async (_url, options) => {
  assert.equal(options.method, "POST");
  const body = JSON.parse(options.body).body;
  assert(body.includes("&lt;script&gt;") && body.includes("&#64;someone"));
  assert(!body.includes("test-only") && !body.includes("Authorization"));
  posts++;
  return Response.json({ html_url: url }, { status: 201 });
};
try {
  assert.equal((await worker.fetch(new Request("https://test/health"), env)).status, 200);
  assert.equal((await worker.fetch(request(report), {})).status, 503);
  assert.equal((await worker.fetch(request({ ...report, text: "tiny" }), env)).status, 400);
  assert.equal((await worker.fetch(request({ ...report, text: "я".repeat(10000) }), env)).status, 400);
  assert.equal((await worker.fetch(request({ ...report, kind: "anything" }), env)).status, 400);
  assert.equal((await worker.fetch(new Request("https://test/feedback"), env)).status, 405);
  assert.equal((await worker.fetch(request({ ...report, diagnostics: "x".repeat(140000) }), env)).status, 413);
  assert.equal((await worker.fetch(request({ ...report, context: "x".repeat(12289) }), env)).status, 400);
  assert.equal((await worker.fetch(request({ ...report, automatic: true }), env)).status, 400);
  const replies = await Promise.all([worker.fetch(request(report), env), worker.fetch(request(report), env)]);
  assert.deepEqual(replies.map(r => r.status), [201, 200]);
  assert.equal(posts, 1);
  assert.equal((await worker.fetch(request({ ...report, text: "Different report" }), env)).status, 409);
  assert.equal((await worker.fetch(request(report), { ...env, RATE_LIMIT: { limit: async () => ({ success: false }) } })).status, 429);

  // GitHub accepted the POST but its reply was lost: retry reconciles the existing comment.
  const lost = { ...report, id: "b".repeat(32) };
  globalThis.fetch = async () => { posts++; throw new Error("lost response"); };
  assert.equal((await worker.fetch(request(lost), env)).status, 503);
  const before = posts;
  globalThis.fetch = async (target, options) => {
    assert.equal(options.method, undefined);
    assert(target.includes("since="));
    return Response.json([{ body: `<!-- vita-feedback:${lost.id} -->`, html_url: url }]);
  };
  assert.equal((await worker.fetch(request(lost), env)).status, 200);
  assert.equal(posts, before);

  const pending = { ...report, id: "c".repeat(32) };
  globalThis.fetch = async () => { throw new Error("timeout"); };
  assert.equal((await worker.fetch(request(pending), env)).status, 503);
  globalThis.fetch = async () => Response.json([]);
  assert.equal((await worker.fetch(request(pending), env)).status, 503);
  assert(entries.has("report:" + pending.id));

  const crash = { ...report, id: "e".repeat(32), kind: "crash", text: "", context: "Пролог @someone <script>", diagnostics: "GPU: test", automatic: true };
  const issueUrl = "https://github.com/crownfall90-dot/mobile-game/issues/123";
  let issuePosts = 0;
  globalThis.fetch = async (target, options) => {
    assert(target.endsWith("/issues"));
    assert.equal(options.method, "POST");
    const payload = JSON.parse(options.body);
    assert(payload.title.includes("Неожиданное закрытие"));
    assert(payload.body.includes("&lt;script&gt;") && payload.body.includes("&#64;someone"));
    issuePosts++;
    return Response.json({ html_url: issueUrl }, { status: 201 });
  };
  assert.equal((await worker.fetch(request(crash), env)).status, 201);
  assert.equal((await worker.fetch(request(crash), env)).status, 200);
  assert.equal(issuePosts, 1);
  const crashLost = { ...crash, id: "f".repeat(32) };
  globalThis.fetch = async () => { issuePosts++; throw new Error("lost reply"); };
  assert.equal((await worker.fetch(request(crashLost), env)).status, 503);
  globalThis.fetch = async (target, options) => {
    assert(target.includes("/issues?state=all&since="));
    assert.equal(options.method, undefined);
    return Response.json([{ body: `<!-- vita-feedback:${crashLost.id} -->`, html_url: issueUrl }]);
  };
  assert.equal((await worker.fetch(request(crashLost), env)).status, 200);
  assert.equal(issuePosts, 2);

  entries.set("daily", { date: new Date().toISOString().slice(0, 10), count: 200 });
  assert.equal((await worker.fetch(request({ ...report, id: "d".repeat(32) }), env)).status, 429);
  console.log("FEEDBACK SERVER CHECK OK: validation, rate limits, literal text, one POST, ID conflict, lost reply recovery, pending preservation");
} finally { globalThis.fetch = realFetch; }
