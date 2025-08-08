defmodule ReoxtWeb.Router do
  use ReoxtWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :put_root_layout, html: {ReoxtWeb.Layouts, :root}
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ReoxtWeb do
    pipe_through :browser

    # Redirect root to graph page
    live "/", GraphLive, :index

    live "/graph", GraphLive, :index
    live "/graph/:txid", GraphLive, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", ReoxtWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:reoxt, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ReoxtWeb.Telemetry
    end
  end
end
