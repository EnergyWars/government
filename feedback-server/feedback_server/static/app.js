"use strict";

const strings = JSON.parse(document.getElementById("i18n").textContent);
const ACTIVE = new Set(["queued", "route", "agent", "build"]);
const FAST_POLL_MS = 4000;
const SLOW_POLL_MS = 15000;
const DRAFT_KEY = "feedback-draft";
const openLogs = new Set();
const summaryState = new Map();
let pollTimer = null;

const t = (key, values = {}) =>
  (strings[key] ?? key).replace(/\{(\w+)\}/g, (_, name) => String(values[name] ?? ""));

const errorText = (code) => t(strings[`error_${code}`] ? `error_${code}` : "error_request_failed");

async function api(path, options = {}) {
  const response = await fetch(path, {
    credentials: "same-origin",
    ...options,
    headers: { "Content-Type": "application/json", ...(options.headers ?? {}) },
  });
  if (response.status === 401) {
    window.location.reload();
    throw new Error("unauthorized");
  }
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error ?? "request_failed");
  }
  return data;
}

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function readDraft() {
  try {
    return window.localStorage.getItem(DRAFT_KEY) ?? "";
  } catch {
    return "";
  }
}

function writeDraft(value) {
  try {
    if (value) window.localStorage.setItem(DRAFT_KEY, value);
    else window.localStorage.removeItem(DRAFT_KEY);
  } catch {
    return;
  }
}

function formatTime(seconds) {
  return new Date(seconds * 1000).toLocaleString(document.documentElement.lang, {
    dateStyle: "short",
    timeStyle: "short",
  });
}

function renderLatest(latestId) {
  const link = document.getElementById("latest-apk");
  const empty = document.getElementById("no-apk");
  link.hidden = latestId === null;
  empty.hidden = latestId !== null;
  if (latestId !== null) link.textContent = t("download_latest", { id: latestId });
}

function renderJob(job) {
  const item = element("li", "card job stack");
  const head = element("div", "row");
  head.append(element("span", "title", `#${job.id} · ${t(`kind_${job.kind}`)}`));
  head.append(element("span", `pill status-${job.status}`, t(`status_${job.status}`)));
  item.append(head);

  const meta = [t("created_at", { time: formatTime(job.created_at) })];
  if (job.started_at && job.finished_at) {
    meta.push(t("duration", { minutes: Math.max(1, Math.round((job.finished_at - job.started_at) / 60)) }));
  }
  item.append(element("p", "meta", meta.join(" · ")));
  if (job.model) {
    const route = element("p", "route");
    route.append(element("span", "pill status-route", t("route_info", { model: job.model, effort: job.effort })));
    route.append(element("span", "meta", job.route_reason ?? t("route_fallback")));
    item.append(route);
  }
  if (job.feedback) item.append(element("p", "feedback", job.feedback));
  if (job.summary) {
    const summary = element("details", "summary");
    summary.append(element("summary", "", t("summary_title")));
    summary.append(element("p", "summary-text", job.summary));
    summary.open = summaryState.get(job.id) ?? job.status === "done";
    summary.addEventListener("toggle", () => summaryState.set(job.id, summary.open));
    item.append(summary);
  }
  if (job.error) item.append(element("p", "error", errorText(job.error)));

  const actions = element("div", "actions");
  if (job.has_apk) {
    const download = element("a", "btn tonal", t("download"));
    download.href = `/apk/${job.id}`;
    actions.append(download);
  }
  if (ACTIVE.has(job.status)) {
    const cancel = element("button", "btn error-tonal", t("cancel"));
    cancel.type = "button";
    cancel.addEventListener("click", () => cancelJob(job.id));
    actions.append(cancel);
  }
  const toggle = element("button", "btn text", t(openLogs.has(job.id) ? "hide_log" : "show_log"));
  toggle.type = "button";
  actions.append(toggle);
  item.append(actions);

  const log = element("pre", "log");
  log.hidden = !openLogs.has(job.id);
  item.append(log);
  toggle.addEventListener("click", () => {
    if (openLogs.has(job.id)) openLogs.delete(job.id);
    else openLogs.add(job.id);
    log.hidden = !openLogs.has(job.id);
    toggle.textContent = t(openLogs.has(job.id) ? "hide_log" : "show_log");
    if (!log.hidden) loadLog(job.id, log);
  });
  if (!log.hidden) loadLog(job.id, log);
  return item;
}

async function loadLog(jobId, target) {
  try {
    const detail = await api(`/api/jobs/${jobId}`);
    const atBottom = target.scrollTop + target.clientHeight >= target.scrollHeight - 8;
    target.textContent = detail.log || t("log_empty");
    if (atBottom) target.scrollTop = target.scrollHeight;
  } catch (error) {
    target.textContent = errorText(error.message);
  }
}

async function refresh() {
  window.clearTimeout(pollTimer);
  let active = false;
  try {
    const data = await api("/api/jobs");
    renderLatest(data.latest_apk);
    const list = document.getElementById("jobs");
    list.replaceChildren(...data.jobs.map(renderJob));
    document.getElementById("jobs-empty").hidden = data.jobs.length > 0;
    active = data.jobs.some((job) => ACTIVE.has(job.status));
  } catch (error) {
    showMessage(errorText(error.message), true);
  }
  pollTimer = window.setTimeout(refresh, active ? FAST_POLL_MS : SLOW_POLL_MS);
}

function showMessage(text, isError = false) {
  const message = document.getElementById("form-message");
  message.textContent = text;
  message.classList.toggle("error", isError);
}

async function submit(path, body, button) {
  button.disabled = true;
  showMessage(t("sending"));
  try {
    const job = await api(path, { method: "POST", body: JSON.stringify(body) });
    showMessage(t("sent", { id: job.id }));
    return true;
  } catch (error) {
    showMessage(errorText(error.message), true);
    return false;
  } finally {
    button.disabled = false;
    refresh();
  }
}

async function cancelJob(jobId) {
  if (!window.confirm(t("cancel_confirm", { id: jobId }))) return;
  try {
    await api(`/api/jobs/${jobId}/cancel`, { method: "POST", body: "{}" });
  } catch (error) {
    showMessage(errorText(error.message), true);
  }
  refresh();
}

function init() {
  const form = document.getElementById("feedback-form");
  const textarea = document.getElementById("feedback");
  const resume = document.getElementById("resume");
  textarea.value = readDraft();
  textarea.addEventListener("input", () => writeDraft(textarea.value));
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const sent = await submit(
      "/api/feedback",
      { feedback: textarea.value, resume: resume.checked },
      document.getElementById("send"),
    );
    if (sent) {
      textarea.value = "";
      writeDraft("");
    }
  });
  const buildButton = document.getElementById("build-only");
  buildButton.addEventListener("click", () => submit("/api/build", {}, buildButton));
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") refresh();
  });
  refresh();
}

init();
