defmodule Reoxt.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :txid, :string
    field :block_height, :integer
    field :timestamp, :naive_datetime
    field :fee, :integer
    field :size, :integer
    field :version, :integer
    field :locktime, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:txid, :block_height, :timestamp, :fee, :size, :version, :locktime])
    |> validate_required([:txid, :block_height, :timestamp, :fee, :size, :version, :locktime])
    |> unique_constraint(:txid)
  end
end
