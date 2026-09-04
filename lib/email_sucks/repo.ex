defmodule EmailSucks.Repo do
  use AshPostgres.Repo, otp_app: :email_sucks

  @impl true
  def installed_extensions, do: ["ash-functions"]

  @impl true
  def min_pg_version, do: %Version{major: 18, minor: 0, patch: 0}
end
