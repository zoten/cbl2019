# Just a copy of dev.exs since I may need to rebuild
# with an offline copy :)

use Mix.Config

config :cbl_2019, Cbl2019.Provision.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "cbl2019_dev",
  username: "cbl2019_dev",
  password: "cbl2019_dev",
  hostname: "localhost",
  port: "5432"
