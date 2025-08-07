defmodule Reoxt.Repo.Migrations.CreateTransactionOutputs do
  use Ecto.Migration

  def change do
    create table(:transaction_outputs) do
      add :output_index, :integer
      add :value, :decimal
      add :script_pubkey, :text
      add :address, :string
      add :raw_data, :map
      add :transaction_id, references(:transactions, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:transaction_outputs, [:transaction_id])
  end
end
