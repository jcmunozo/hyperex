defmodule Hyperex do
  # `use Application` marks this module as the OTP application callback. When the
  # BEAM boots the `:hyperex` app (see `mod: {Hyperex, []}` in mix.exs), it calls
  # `start/2` below exactly once.
  use Application

  @impl true
  def start(_type, _args) do
    # The supervision tree. Each entry is a "child" the supervisor starts and,
    # crucially, *restarts* if it crashes. This is the heart of Elixir's fault
    # tolerance story.
    children = [
      # A plain module name uses that module's `child_spec/1` (Hyperex.Counter is a
      # GenServer, so it provides one for free). It holds in-memory state and is
      # supervised — kill it and the supervisor brings it back.
      Hyperex.Counter,

      # The HTTP listener. This is the Cowboy 2.x child-spec format: a `{module,
      # opts}` tuple. (The legacy Cowboy 1.x API was the positional
      # `Plug.Cowboy.child_spec(:http, Web.Router, [], port: 4001)` — no longer used.)
      {Plug.Cowboy, scheme: :http, plug: Web.Router, options: [port: 4001]}
    ]

    # `:one_for_one` => if a child dies, only that child is restarted, leaving its
    # siblings untouched. So crashing the Counter never takes down the web server.
    Supervisor.start_link(children, strategy: :one_for_one, name: Hyperex.Supervisor)
  end
end
