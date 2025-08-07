defmodule Reoxt.BitcoinAnalyzer.TransactionInput do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transaction_inputs" do
    field :input_index, :integer
    field :previous_txid, :string
    field :previous_vout, :integer
    field :raw_data, :map
    field :script_sig, :string
    field :sequence, :integer
    field :transaction_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction_input, attrs) do
    transaction_input
    |> cast(attrs, [:input_index, :previous_txid, :previous_vout, :script_sig, :sequence, :raw_data])
    |> validate_required([:input_index, :previous_txid, :previous_vout, :script_sig, :sequence])
  end
end
