defmodule Web.Router do
  @moduledoc """
  HTTP routing for Hyperex, built on `Plug.Router`.

  The two plugs below form the request pipeline: `:match` finds the route whose
  pattern matches the request, then `:dispatch` runs that route's body. The
  catch-all `match _` at the bottom returns a 404.

  Static pages are read from disk (`lib/web/*.html`); the demo pages build their
  HTML dynamically so they can show live results (timings, counter values, PIDs).
  """
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  # ── Static index ──────────────────────────────────────────────────────────

  # The guided landing page. `send_file/3` streams a file straight from disk; the
  # path is relative to the project root, so run the app from the repo root.
  get "/" do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_file(200, "lib/web/index.html")
  end

  # Backwards-compatible alias for the original route.
  get "/elixir" do
    conn
    |> put_resp_header("location", "/")
    |> send_resp(302, "")
  end

  # ── Demo 1: functional basics ─────────────────────────────────────────────

  get "/demo/basics" do
    alias Hyperex.Basics

    rows =
      [
        {"classify(0)", Basics.classify(0)},
        {"classify(7)", Basics.classify(7)},
        {"classify(-3)", Basics.classify(-3)},
        {"fizzbuzz(15)", Basics.fizzbuzz(15)},
        {"sum([1, 2, 3, 4])", Basics.sum([1, 2, 3, 4])},
        {"shout(\"  hello world  \")", Basics.shout("  hello world  ")}
      ]
      |> Enum.map_join("\n", fn {call, result} ->
        "<tr><td><code>#{call}</code></td><td><code>#{inspect(result)}</code></td></tr>"
      end)

    body = """
    <p>These results come from <code>Hyperex.Basics</code>, which showcases pattern
    matching, guards, recursion, and the pipe operator <code>|&gt;</code>. The same
    examples are doctests, so <code>mix test</code> verifies them.</p>
    <table>
      <thead><tr><th>Call</th><th>Result</th></tr></thead>
      <tbody>#{rows}</tbody>
    </table>
    """

    html(conn, "Functional basics", body)
  end

  # ── Demo 2: concurrency with Tasks ────────────────────────────────────────

  get "/demo/concurrency" do
    conn = fetch_query_params(conn)
    n = clamp_n(conn.query_params["n"])
    job_ms = 100

    # Spawn `n` lightweight processes that each "work" for job_ms. With
    # Task.async_stream they run concurrently, so the whole batch finishes in
    # roughly job_ms — not n × job_ms.
    {elapsed_us, _results} =
      :timer.tc(fn ->
        1..n
        |> Task.async_stream(fn _ -> Process.sleep(job_ms) end,
          max_concurrency: n,
          timeout: :infinity
        )
        |> Enum.to_list()
      end)

    elapsed_ms = div(elapsed_us, 1000)
    sequential_ms = n * job_ms

    body = """
    <p>We launched <strong>#{n}</strong> independent processes, each sleeping for
    <strong>#{job_ms} ms</strong>, using <code>Task.async_stream/3</code>.</p>
    <table>
      <tbody>
        <tr><td>Processes spawned</td><td><code>#{n}</code></td></tr>
        <tr><td>If run one-by-one (sequential)</td><td><code>~#{sequential_ms} ms</code></td></tr>
        <tr><td>Actual wall-clock (concurrent)</td><td><code>#{elapsed_ms} ms</code></td></tr>
      </tbody>
    </table>
    <p>The batch finished in about the time of a <em>single</em> job: the BEAM ran
    all #{n} processes at once across its schedulers. Try a different count with
    <code>?n=…</code>, e.g. <a href="/demo/concurrency?n=10000">?n=10000</a>.</p>
    """

    html(conn, "Concurrency with Tasks", body)
  end

  # ── Demo 3 + 4: GenServer state and fault tolerance ───────────────────────

  get "/demo/counter" do
    body = """
    <p>The count lives inside a supervised <code>GenServer</code>
    (<code>Hyperex.Counter</code>). Its current state:</p>
    <table>
      <tbody>
        <tr><td>Count</td><td><code>#{Hyperex.Counter.value()}</code></td></tr>
        <tr><td>Server PID</td><td><code>#{inspect(Hyperex.Counter.who())}</code></td></tr>
      </tbody>
    </table>
    <p>
      <a class="btn" href="/demo/counter/increment">Increment</a>
      <a class="btn danger" href="/demo/crash">Crash the counter</a>
    </p>
    <p>Increment a few times, then crash it: when you come back the PID will be
    <strong>different</strong> and the count will be reset to <strong>0</strong> —
    the supervisor restarted the process from scratch.</p>
    """

    html(conn, "State with a GenServer", body)
  end

  get "/demo/counter/increment" do
    Hyperex.Counter.increment()

    conn
    |> put_resp_header("location", "/demo/counter")
    |> send_resp(302, "")
  end

  get "/demo/crash" do
    old_pid = Hyperex.Counter.who()
    # Tell the counter to crash. We don't crash here in the web process — only the
    # supervised worker dies, and its supervisor restarts it.
    Hyperex.Counter.boom()
    # Give the supervisor a moment to restart the child before we read the new PID.
    Process.sleep(50)
    new_pid = Hyperex.Counter.who()

    body = """
    <p>We just called <code>Hyperex.Counter.boom/0</code>, which raised an exception
    <em>inside</em> the counter process. It crashed — but the web server (and this
    page) kept serving requests.</p>
    <table>
      <tbody>
        <tr><td>PID before crash</td><td><code>#{inspect(old_pid)}</code></td></tr>
        <tr><td>PID after restart</td><td><code>#{inspect(new_pid)}</code></td></tr>
      </tbody>
    </table>
    <p>The supervisor (strategy <code>:one_for_one</code>) noticed the exit and
    started a fresh counter. Different PID, state reset to 0. That's the
    "let it crash" philosophy in action.</p>
    <p><a class="btn" href="/demo/counter">Back to the counter</a></p>
    """

    html(conn, "Fault tolerance: let it crash", body)
  end

  # ── Catch-all ─────────────────────────────────────────────────────────────

  match _ do
    send_resp(conn, 404, "This is not the page you are looking for.")
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  # Parses the `?n=` query param into a sane process count: defaults to 1000 and
  # is clamped to 1..50_000 so the demo can't be asked to do something silly.
  defp clamp_n(nil), do: 1000

  defp clamp_n(raw) do
    case Integer.parse(raw) do
      {n, _} -> n |> max(1) |> min(50_000)
      :error -> 1000
    end
  end

  # Wraps a demo body fragment in the shared page layout and sends it.
  defp html(conn, title, body) do
    page = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{title} · Hyperex</title>
      <style>
        body { font-family: system-ui, sans-serif; max-width: 720px; margin: 2.5rem auto; padding: 0 1rem; line-height: 1.55; color: #1a1a1a; }
        h1 { color: #6b3fa0; }
        a { color: #6b3fa0; }
        table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
        td, th { border: 1px solid #ddd; padding: 0.5rem 0.75rem; text-align: left; }
        th { background: #f4f0fa; }
        code { background: #f4f0fa; padding: 0.1rem 0.3rem; border-radius: 4px; }
        .btn { display: inline-block; background: #6b3fa0; color: #fff; padding: 0.5rem 1rem; border-radius: 6px; text-decoration: none; margin-right: 0.5rem; }
        .btn.danger { background: #c0392b; }
        .home { font-size: 0.9rem; }
      </style>
    </head>
    <body>
      <p class="home"><a href="/">← Back to all demos</a></p>
      <h1>#{title}</h1>
      #{body}
    </body>
    </html>
    """

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, page)
  end
end
