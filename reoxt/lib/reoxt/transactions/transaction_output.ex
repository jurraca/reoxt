defmodule Reoxt.Transactions.TransactionOutput do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transaction_outputs" do
    field :value, :integer
    field :n, :integer
    field :script_pub_key, :string
    field :address, :string
    field :type, :string
    field :transaction_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction_output, attrs) do
    transaction_output
    |> cast(attrs, [:value, :n, :script_pub_key, :address, :type])
    |> validate_required([:value, :n, :script_pub_key, :address, :type])
  end
end
