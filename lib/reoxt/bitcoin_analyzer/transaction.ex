defmodule Reoxt.BitcoinAnalyzer.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :block_hash, :string
    field :block_height, :integer
    field :block_time, :utc_datetime
    field :confirmations, :integer
    field :hash, :string
    field :locktime, :integer
    field :raw_data, :map
    field :size, :integer
    field :txid, :string
    field :version, :integer
    field :vsize, :integer
    field :weight, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:txid, :hash, :version, :size, :vsize, :weight, :locktime, :block_hash, :block_height, :confirmations, :block_time, :raw_data])
    |> validate_required([:txid, :hash, :version, :size, :vsize, :weight, :locktime, :block_hash, :block_height, :confirmations, :block_time])
    |> unique_constraint(:txid)
  end
end
