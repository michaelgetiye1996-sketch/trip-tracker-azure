"""Trip Tracker - FastAPI app backed by Azure Database for PostgreSQL (private)."""
import os
from contextlib import asynccontextmanager
from datetime import date

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool
from pydantic import BaseModel, Field

# 12-factor config: all settings come from environment variables, nothing hard-coded.
# In AKS the password will be injected from Key Vault - it never lives in code or Git.
pool = ConnectionPool(
    open=False,
    min_size=1,
    max_size=5,
    kwargs={
        "host": os.environ["DB_HOST"],
        "port": os.environ.get("DB_PORT", "5432"),
        "dbname": os.environ.get("DB_NAME", "tripdb"),
        "user": os.environ["DB_USER"],
        "password": os.environ["DB_PASSWORD"],
        "sslmode": os.environ.get("DB_SSLMODE", "require"),
    },
)

SCHEMA = """
CREATE TABLE IF NOT EXISTS trips (
    id          SERIAL PRIMARY KEY,
    destination VARCHAR(100) NOT NULL,

    start_date  DATE NOT NULL,
    end_date    DATE,
    notes       VARCHAR(500),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
)
"""


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Fail fast: if the database is unreachable at startup, crash so Kubernetes restarts the pod
    pool.open(wait=True, timeout=30)
    with pool.connection() as conn:
        conn.execute(SCHEMA)
    yield
    pool.close()


app = FastAPI(title="Trip Tracker", version="1.0.0", lifespan=lifespan)


class TripIn(BaseModel):
    destination: str = Field(min_length=1, max_length=100)
    start_date: date
    end_date: date | None = None
    notes: str | None = Field(default=None, max_length=500)


@app.get("/healthz")
def healthz():
    """Liveness probe: is the process alive? (no database call)"""
    return {"status": "ok"}



@app.get("/readyz")
def readyz():
    """Readiness probe: can this pod serve traffic? (checks the database)"""
    try:
        with pool.connection(timeout=5) as conn:
            conn.execute("SELECT 1")
        return {"status": "ready"}
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")


@app.get("/api/trips")
def list_trips():
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            "SELECT id, destination, start_date, end_date, notes, created_at "
            "FROM trips ORDER BY start_date DESC, id DESC"
        )
        return cur.fetchall()


@app.post("/api/trips", status_code=201)
def create_trip(trip: TripIn):
    if trip.end_date and trip.end_date < trip.start_date:
        raise HTTPException(status_code=422, detail="end_date is before start_date")
    with pool.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            "INSERT INTO trips (destination, start_date, end_date, notes) "
            "VALUES (%s, %s, %s, %s) "
            "RETURNING id, destination, start_date, end_date, notes, created_at",

            (trip.destination, trip.start_date, trip.end_date, trip.notes),
        )
        return cur.fetchone()


@app.delete("/api/trips/{trip_id}", status_code=204)
def delete_trip(trip_id: int):
    with pool.connection() as conn:
        cur = conn.execute("DELETE FROM trips WHERE id = %s", (trip_id,))
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="trip not found")


PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>Trip Tracker</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:system-ui,sans-serif;max-width:720px;margin:2rem auto;padding:0 1rem}
form{display:grid;gap:.5rem;margin-bottom:1.5rem}
input,button{padding:.5rem;font-size:1rem}
li{margin:.4rem 0} small{color:#666}
</style></head><body>
<h1>Trip Tracker</h1>
<p><small>FastAPI on AKS &middot; private Azure Database for PostgreSQL &middot; <a href="/docs">API docs</a></small></p>
<form id="f">
  <input name="destination" placeholder="Destination" required maxlength="100">
  <label>Start <input type="date" name="start_date" required></label>
  <label>End <input type="date" name="end_date"></label>
  <input name="notes" placeholder="Notes (optional)" maxlength="500">
  <button>Add trip</button>
</form>
<ul id="trips"></ul>

<script>
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
async function load() {
  const trips = await (await fetch("/api/trips")).json();
  document.getElementById("trips").innerHTML = trips.map(t =>
    `<li><b>${esc(t.destination)}</b> ${esc(t.start_date)}${t.end_date ? " to " + esc(t.end_date) : ""}
     <small>${esc(t.notes)}</small> <button onclick="del(${t.id})">x</button></li>`).join("") || "<li>No trips yet.</li>";
}
async function del(id) { await fetch("/api/trips/" + id, {method: "DELETE"}); load(); }
document.getElementById("f").onsubmit = async e => {
  e.preventDefault();
  const d = Object.fromEntries(new FormData(e.target));
  for (const k of ["end_date", "notes"]) if (!d[k]) delete d[k];
  const r = await fetch("/api/trips", {method: "POST",
    headers: {"Content-Type": "application/json"}, body: JSON.stringify(d)});
  if (r.ok) { e.target.reset(); load(); } else alert("Could not save trip");
};
load();
</script></body></html>"""


@app.get("/", response_class=HTMLResponse)
def index():
    return PAGE
