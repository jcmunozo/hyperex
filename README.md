# Hyperex

This is a tiny Elixir web app (Plug + Cowboy, **no Phoenix**) built as a hands-on way to
learn the basics of Elixir and to *see* its two headline strengths — **massive
concurrency** and **fault tolerance** — in action. It serves HTTP on **port 4001**.

## Quick start

```sh
mix deps.get          # fetch dependencies
mix run --no-halt     # start the server (run from the repo root!)
```

Then open <http://localhost:4001/> for the guided index of demos.

Other useful commands:

```sh
iex -S mix            # interactive shell with the app running
mix test              # run tests + doctests
mix format            # format code
```

> The HTML files are loaded with paths relative to the project root, so always
> start the app from the repository root.

## The demos

Each route is backed by a small, heavily-commented module — open the page, then
read the source to see how it works.

| Route | What it teaches | Source |
|-------|-----------------|--------|
| `GET /` | Guided index linking to every demo | `lib/web/index.html` |
| `GET /demo/basics` | Pattern matching, guards, recursion, the pipe `\|>` | `lib/hyperex/basics.ex` |
| `GET /demo/concurrency` | Thousands of lightweight processes via `Task.async_stream/3` (try `?n=10000`) | `lib/web/router.ex` |
| `GET /demo/counter` | In-memory state held by a supervised `GenServer` | `lib/hyperex/counter.ex` |
| `GET /demo/crash` | "Let it crash" — the supervisor restarts the crashed worker | `lib/hyperex/counter.ex` |

### Why these show off Elixir

- **Concurrency** — `/demo/concurrency` spawns N independent processes that each
  "work" for 100 ms. Run sequentially that would take `N × 100 ms`; on the BEAM
  they run concurrently and the whole batch finishes in roughly 100 ms.
- **Fault tolerance** — `/demo/crash` deliberately raises inside the counter
  process. It dies, but the `:one_for_one` supervisor restarts it (new PID, state
  reset to 0) and the web server never blinks. Refresh `/demo/counter` to see it.

## Architecture

- `Hyperex` (`lib/hyperex.ex`) — the OTP `Application`. Its supervision tree holds
  the `Hyperex.Counter` GenServer and the Cowboy HTTP listener (port 4001).
- `Web.Router` (`lib/web/router.ex`) — a `Plug.Router` with the demo routes; the
  static index is served via `send_file`, dynamic pages are rendered inline.
- `Hyperex.Counter` / `Hyperex.Basics` — the demo modules.

Built on Plug 1.x and **Cowboy 2.x** (`plug_cowboy ~> 2.7`).
