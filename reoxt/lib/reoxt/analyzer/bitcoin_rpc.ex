defmodule Reoxt.Analyzer.BitcoinRpc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bitcoin_rpc_configs" do
    field :host, :string
    field :port, :integer
    field :username, :string
    field :password, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bitcoin_rpc, attrs) do
    bitcoin_rpc
    |> cast(attrs, [:host, :port, :username, :password])
    |> validate_required([:host, :port, :username, :password])
  end
end
