defmodule EmailSucks.Release do
  @moduledoc "Database migration entry point for releases; does not start application workers."

  def migrate do
    {:ok, _} = Application.ensure_all_started(:ssl)
    :ok = Application.ensure_loaded(:email_sucks)

    for repo <- Application.fetch_env!(:email_sucks, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    :ok
  end
end
