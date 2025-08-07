defmodule Reoxt.BitcoinAnalyzer.TransactionOutput do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transaction_outputs" do
    field :address, :string
    field :output_index, :integer
    field :raw_data, :map
    field :script_pubkey, :string
    field :value, :decimal
    field :transaction_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction_output, attrs) do
    transaction_output
    |> cast(attrs, [:output_index, :value, :script_pubkey, :address, :raw_data])
    |> validate_required([:output_index, :value, :script_pubkey, :address])
  end
end
