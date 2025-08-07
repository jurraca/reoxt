defmodule Reoxt.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :txid, :string
      add :hash, :string
      add :version, :integer
      add :size, :integer
      add :vsize, :integer
      add :weight, :integer
      add :locktime, :integer
      add :block_hash, :string
      add :block_height, :integer
      add :confirmations, :integer
      add :block_time, :utc_datetime
      add :raw_data, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:transactions, [:txid])
  end
end
