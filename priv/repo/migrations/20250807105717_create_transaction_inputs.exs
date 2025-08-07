defmodule Reoxt.Repo.Migrations.CreateTransactionInputs do
  use Ecto.Migration

  def change do
    create table(:transaction_inputs) do
      add :input_index, :integer
      add :previous_txid, :string
      add :previous_vout, :integer
      add :script_sig, :text
      add :sequence, :integer
      add :raw_data, :map
      add :transaction_id, references(:transactions, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:transaction_inputs, [:transaction_id])
  end
end
