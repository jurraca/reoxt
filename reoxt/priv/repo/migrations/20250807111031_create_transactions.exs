defmodule Reoxt.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :txid, :string
      add :block_height, :integer
      add :timestamp, :naive_datetime
      add :fee, :integer
      add :size, :integer
      add :version, :integer
      add :locktime, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:transactions, [:txid])
  end
end
