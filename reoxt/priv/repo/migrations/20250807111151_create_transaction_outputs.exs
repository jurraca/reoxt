defmodule Reoxt.Repo.Migrations.CreateTransactionOutputs do
  use Ecto.Migration

  def change do
    create table(:transaction_outputs) do
      add :value, :integer
      add :n, :integer
      add :script_pub_key, :text
      add :address, :string
      add :type, :string
      add :transaction_id, references(:transactions, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:transaction_outputs, [:transaction_id])
  end
end
