defmodule Reoxt.Repo.Migrations.CreateBitcoinRpcConfigs do
  use Ecto.Migration

  def change do
    create table(:bitcoin_rpc_configs) do
      add :host, :string
      add :port, :integer
      add :username, :string
      add :password, :string

      timestamps(type: :utc_datetime)
    end
  end
end
