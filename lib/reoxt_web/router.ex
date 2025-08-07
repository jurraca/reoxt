
defmodule ReoxtWeb.Router do
  use ReoxtWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ReoxtWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ReoxtWeb do
    pipe_through :browser

    live "/", TransactionAnalyzerLive, :index
    live "/transaction/:txid", TransactionAnalyzerLive, :show
  end

  if Application.compile_env(:reoxt, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ReoxtWeb.Telemetry
    end
  end
end
