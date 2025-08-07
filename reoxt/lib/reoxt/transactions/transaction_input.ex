defmodule Reoxt.Transactions.TransactionInput do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__, :transaction]}
  schema "transaction_inputs" do
    field :txid, :string
    field :vout, :integer
    field :script_sig, :string
    field :sequence, :integer
    field :value, :integer

    belongs_to :transaction, Reoxt.Transactions.Transaction

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction_input, attrs) do
    transaction_input
    |> cast(attrs, [:txid, :vout, :script_sig, :sequence, :value, :transaction_id])
    |> validate_required([:txid, :vout, :script_sig, :sequence, :value, :transaction_id])
  end
end
