
defmodule Reoxt.Repo do
  use Ecto.Repo,
    otp_app: :reoxt,
    adapter: Ecto.Adapters.Postgres
end
