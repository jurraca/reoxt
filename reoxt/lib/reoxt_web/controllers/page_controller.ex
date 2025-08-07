defmodule ReoxtWeb.PageController do
  use ReoxtWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
