defmodule Reoxt.Repo.Migrations.CreateTransactionInputs do
  use Ecto.Migration

  def change do
    create table(:transaction_inputs) do
      add :txid, :string
      add :vout, :integer
      add :script_sig, :text
      add :sequence, :integer
      add :value, :integer
      add :transaction_id, references(:transactions, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:transaction_inputs, [:transaction_id])
  end
end
