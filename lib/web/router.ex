defmodule Web.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/elixir" do
    send_resp(conn, 200, "I <3 ELixir")
  end

  match do
    send_resp(conn, 404, "This is not the page you are looking for.")
  end
end
