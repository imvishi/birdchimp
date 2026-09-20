# Birdchimp — appointment booking

A Rails JSON API for booking 30-minute appointments on one shared calendar
(Monday–Friday, 9:00 AM–4:30 PM IST), with a small page on top to exercise it.

**Live demo:** https://birdchimp.onrender.com/

> Hosted on Render's free tier, which puts the app to sleep when idle. The first request
> can take up to a minute while it wakes up; everything after that is normal speed.

## Stack

Ruby 3.4.7 · Rails 8.1 (API-only) · PostgreSQL · RSpec · static HTML/JS page in `public/` · Docker

## Setup and run

```bash
bundle install
bin/rails db:prepare      # needs a local PostgreSQL
bin/rails server          # http://localhost:3000
```

### Using Docker

Copy the `.env` file (shared separately, not committed) into the project root, then:

```bash
docker compose up --build # http://localhost:3000
```

## Test

```bash
bundle exec rspec
```

Using Docker (no local Ruby or Postgres needed):

```bash
docker compose run --rm test
```

## API

All timestamps are ISO 8601 with the IST offset, e.g. `2026-09-21T09:30:00+05:30`.

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/appointments` | Active bookings, chronological. `?upcoming=true` hides past ones. Cursor-paginated: `?limit=20&cursor=…`. |
| `GET` | `/api/appointments/available?start=YYYY-MM-DD&end=YYYY-MM-DD` | Slots in the range (IST dates, inclusive) with `available: true/false`. Defaults to the current week. |
| `POST` | `/api/appointments` | Book a slot. Body: `{ "appointment": { "start_at", "name", "email", "phone", "note" } }` |
| `DELETE` | `/api/appointments/:id` | Cancel (soft delete via `cancelled_at`; the slot frees up). |


Errors are `{ "error": "<code>", "message": "…" }`: **400** bad date range · **404** unknown id ·
**409** slot already booked · **422** validation failed.

**Double-booking** is closed by a partial unique index on `start_at WHERE cancelled_at IS NULL`;
the API rescues `RecordNotUnique` into a 409. There is no uniqueness validation, so it's one
`INSERT` and the database is the only judge. Tested at both layers (DB error + 409 request spec).

**Timezone:** business hours are hard-coded to `Asia/Kolkata` via `config.time_zone`; Postgres
stores UTC and ActiveRecord converts, so all rules run on the IST clock.

## Decisions and tradeoffs

- **API-only Rails + a static page.** I used AI to generate the frontend page. I could have used
  React, Rails views or Hotwire, but the priority of this task is the backend and a JSON API,
  so a static page that consumes the API was the fastest way to exercise it.
- **Cursor pagination.** Stable under inserts and cheap at depth. I also considered
  offset-based pagination, which gives better control for moving between numbered pages;
  for a list that only grows and is browsed forward, cursors fit better.
- **Soft delete** for cancellations, so the unique index can be partial and history is kept.
