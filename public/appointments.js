// Booking UI on top of /api/appointments. All dates are IST calendar dates.
const API = "/api/appointments";
const TZ = "Asia/Kolkata";
const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri"];

// --- dates -----------------------------------------------------------------
// Days are handled as "YYYY-MM-DD" strings; arithmetic goes through UTC noon to dodge DST.
const toDay = (date) => date.toISOString().slice(0, 10);
const addDays = (day, n) => toDay(new Date(Date.parse(`${day}T12:00:00Z`) + n * 86_400_000));
const todayInIST = () => new Intl.DateTimeFormat("en-CA", { timeZone: TZ }).format(new Date());
const weekdayOf = (day) => new Date(`${day}T12:00:00Z`).getUTCDay(); // 0 = Sun
const mondayOf = (day) => addDays(day, weekdayOf(day) === 0 ? -6 : 1 - weekdayOf(day));
const isWeekend = (day) => [0, 6].includes(weekdayOf(day));

const fmtDate = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, day: "numeric", month: "short", year: "numeric" });
const fmtSlot = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, weekday: "short", day: "numeric", month: "short", hour: "numeric", minute: "2-digit" });
const fmtTime = new Intl.DateTimeFormat("en-US", { timeZone: TZ, hour: "numeric", minute: "2-digit" });
const dateLabel = (day) => fmtDate.format(new Date(`${day}T12:00:00Z`));

// --- api -------------------------------------------------------------------
async function api(path, options = {}) {
  const response = await fetch(path, { headers: { "Content-Type": "application/json", Accept: "application/json" }, ...options });
  const body = response.status === 204 ? null : await response.json().catch(() => null);
  if (!response.ok) throw new Error(body?.message || `Request failed (${response.status})`);
  return body;
}

// --- state -----------------------------------------------------------------
// Start on this week, or next week when today is a weekend (this week's slots have all passed).
let monday = mondayOf(todayInIST());
if (isWeekend(todayInIST())) monday = addDays(monday, 7);
let selectedSlot = null;
let nextCursor = null;
let listScope = "upcoming"; // or "all" (includes past bookings)

const $ = (id) => document.getElementById(id);

// --- flash / errors --------------------------------------------------------
function flash(message, kind = "notice") {
  const el = $("flash");
  el.textContent = message;
  el.className = `flash flash--${kind}`;
  el.hidden = false;
  clearTimeout(flash.timer);
  flash.timer = setTimeout(() => (el.hidden = true), 5000);
}

function formError(message) {
  const el = $("form-error");
  el.textContent = message || "";
  el.hidden = !message;
}

// --- slot grid -------------------------------------------------------------
async function renderGrid() {
  const friday = addDays(monday, 4);
  $("week-label").textContent = `${dateLabel(monday)} – ${dateLabel(friday)}`;

  const today = todayInIST();
  $("grid-days").innerHTML = WEEKDAYS.map((name, i) => {
    const day = addDays(monday, i);
    return `<th scope="col" class="${day === today ? "grid__today" : ""}">${name} ${Number(day.slice(8))}</th>`;
  }).join("");

  $("grid-body").innerHTML = `<tr><td colspan="5" class="muted">Loading…</td></tr>`;

  const { slots } = await api(`${API}/available?start=${monday}&end=${friday}`);
  const byDay = Object.groupBy(slots, (slot) => slot.start_time.slice(0, 10));
  const rows = byDay[monday]?.length ?? 16;
  const now = Date.now();

  $("grid-body").innerHTML = Array.from({ length: rows }, (_, row) =>
    `<tr>${WEEKDAYS.map((_, i) => {
      const slot = byDay[addDays(monday, i)]?.[row];
      if (!slot) return "<td></td>";
      const time = fmtTime.format(new Date(slot.start_time));
      if (slot.available) {
        const checked = slot.start_time === selectedSlot ? "checked" : "";
        return `<td><label class="slot slot--open"><input type="radio" name="start_at" value="${slot.start_time}" ${checked} required>${time}</label></td>`;
      }
      if (Date.parse(slot.start_time) < now) return `<td><span class="slot slot--past">${time}</span></td>`;
      return `<td><span class="slot slot--booked">${time}<small>Booked</small></span></td>`;
    }).join("")}</tr>`
  ).join("");
}

// --- appointments list -----------------------------------------------------
function appointmentRow(a) {
  const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  return `<tr data-id="${a.id}">
    <td><a href="#" data-goto="${a.start_at.slice(0, 10)}">${fmtSlot.format(new Date(a.start_at))}</a></td>
    <td>${esc(a.name)}</td>
    <td><a href="mailto:${esc(a.email)}">${esc(a.email)}</a></td>
    <td>${esc(a.phone)}</td>
    <td>${esc(a.reason)}</td>
    <td><button type="button" class="button button--danger" data-cancel="${a.id}" data-label="${esc(a.name)}, ${fmtSlot.format(new Date(a.start_at))}">Cancel</button></td>
  </tr>`;
}

async function renderList(cursor = null) {
  const query = `limit=20${listScope === "upcoming" ? "&upcoming=true" : ""}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ""}`;
  const { appointments, next_cursor } = await api(`${API}?${query}`);
  if (!cursor) $("list-body").innerHTML = "";
  $("list-body").insertAdjacentHTML("beforeend", appointments.map(appointmentRow).join(""));
  nextCursor = next_cursor;

  const count = $("list-body").children.length;
  $("list").hidden = count === 0;
  $("list-empty").hidden = count > 0;
  $("list-count").textContent = count ? `(${count}${nextCursor ? "+" : ""})` : "";
  $("list-more").hidden = !nextCursor;
}

const refresh = () => Promise.all([renderGrid(), renderList()]);

// --- events ----------------------------------------------------------------
document.querySelector(".week-nav").addEventListener("click", (event) => {
  const step = event.target.dataset.week;
  if (step === undefined) return;
  monday = step === "0" ? mondayOf(todayInIST()) : addDays(monday, 7 * Number(step));
  renderGrid().catch((error) => flash(error.message, "error"));
});

$("grid-body").addEventListener("change", (event) => {
  if (event.target.name === "start_at") selectedSlot = event.target.value;
});

$("booking").addEventListener("submit", async (event) => {
  event.preventDefault();
  formError(null);
  const form = event.target;
  if (!selectedSlot) return formError("Pick a slot first.");

  const appointment = { start_at: selectedSlot, name: form.name.value, email: form.email.value, phone: form.phone.value, note: form.note.value };
  try {
    const booked = await api(API, { method: "POST", body: JSON.stringify({ appointment }) });
    flash(`Booked ${fmtSlot.format(new Date(booked.start_at))} for ${booked.name}.`);
    form.reset();
    selectedSlot = null;
    await refresh();
  } catch (error) {
    formError(error.message);
    renderGrid(); // the slot may have just been taken; show the latest state
  }
});

$("list-body").addEventListener("click", async (event) => {
  const goto = event.target.dataset.goto;
  if (goto) {
    event.preventDefault();
    monday = mondayOf(goto);
    renderGrid().catch((error) => flash(error.message, "error"));
    return;
  }

  const id = event.target.dataset.cancel;
  if (!id || !confirm(`Cancel the appointment for ${event.target.dataset.label}?`)) return;
  try {
    await api(`${API}/${id}`, { method: "DELETE" });
    flash("Appointment cancelled.");
    await refresh();
  } catch (error) {
    flash(error.message, "error");
  }
});

document.querySelector(".segmented").addEventListener("click", (event) => {
  const scope = event.target.dataset.scope;
  if (!scope || scope === listScope) return;
  listScope = scope;
  document.querySelectorAll(".segmented [data-scope]").forEach((b) => b.classList.toggle("is-active", b.dataset.scope === scope));
  renderList().catch((error) => flash(error.message, "error"));
});

$("list-more").addEventListener("click", () => renderList(nextCursor).catch((error) => flash(error.message, "error")));

refresh().catch((error) => flash(error.message, "error"));
