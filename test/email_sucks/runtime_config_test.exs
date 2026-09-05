defmodule EmailSucks.RuntimeConfigTest do
  use ExUnit.Case, async: false

  @variables ~w(APP_ROLE RESTORE_MODE PHX_SERVER PHX_HOST RENDER_EXTERNAL_HOSTNAME DATABASE_URL SECRET_KEY_BASE GMAIL_OAUTH_FILE GMAIL_KEYS_FILE)

  setup do
    previous = Map.new(@variables, &{&1, System.get_env(&1)})
    Enum.each(@variables, &System.delete_env/1)

    System.put_env("DATABASE_URL", "ecto://fixture:fixture@localhost/fixture")
    System.put_env("SECRET_KEY_BASE", String.duplicate("s", 64))

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)

    :ok
  end

  defp config do
    Config.Reader.read!("config/runtime.exs", env: :prod)
    |> Keyword.fetch!(:email_sucks)
  end

  test "hosted web uses Render hostname while explicit custom host wins" do
    System.put_env("RENDER_EXTERNAL_HOSTNAME", "fixture.onrender.com")
    assert config()[EmailSucksWeb.Endpoint][:url][:host] == "fixture.onrender.com"
    System.put_env("PHX_HOST", "mail.example.test")
    assert config()[EmailSucksWeb.Endpoint][:url][:host] == "mail.example.test"
  end

  test "restore mode blocks worker queues and does not read mounted Gmail secrets" do
    System.put_env("APP_ROLE", "worker")
    System.put_env("RESTORE_MODE", "true")
    System.put_env("GMAIL_OAUTH_FILE", "/nonexistent/restore-must-not-read-this.json")
    assert config()[:restore_mode]
    assert config()[Oban][:queues] == false
    assert config()[:gmail] == nil
  end

  test "invalid restore flag fails closed rather than starting a worker" do
    System.put_env("RESTORE_MODE", "tru")
    assert_raise RuntimeError, ~r/RESTORE_MODE/, fn -> config() end
  end

  test "short production cookie secrets fail before application startup" do
    System.put_env("SECRET_KEY_BASE", String.duplicate("s", 44))
    assert_raise RuntimeError, ~r/SECRET_KEY_BASE/, fn -> config() end
  end

  test "ordinary worker still executes only the synthetic queue" do
    System.put_env("APP_ROLE", "worker")
    assert config()[Oban][:queues] == [phase_zero: 5]
    refute config()[:restore_mode]
  end

  test "worker never reads Gmail secrets even if paths are accidentally provided" do
    System.put_env("APP_ROLE", "worker")
    System.put_env("GMAIL_OAUTH_FILE", "/nonexistent/worker-must-not-read.json")
    assert config()[Oban][:queues] == [phase_zero: 5]
    assert config()[:gmail] == nil
  end

  test "configured web owns delivery queue and conservative Lifeline, restore owns neither" do
    dir = Path.join(System.tmp_dir!(), "trial-runtime-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    oauth = Path.join(dir, "oauth.json")
    keys = Path.join(dir, "keys.json")

    File.write!(
      oauth,
      Jason.encode!(%{
        web: %{
          client_id: "test",
          client_secret: "test",
          redirect_uris: ["https://fixture.test/auth/google/callback"]
        }
      })
    )

    File.write!(
      keys,
      Jason.encode!(%{
        vault_key: String.duplicate("k", 64),
        session_secret: String.duplicate("s", 64),
        allowed_email: "owner@gmail.com"
      })
    )

    old_redirect = System.get_env("GMAIL_REDIRECT_URI")

    on_exit(fn ->
      if old_redirect,
        do: System.put_env("GMAIL_REDIRECT_URI", old_redirect),
        else: System.delete_env("GMAIL_REDIRECT_URI")
    end)

    System.put_env("GMAIL_OAUTH_FILE", oauth)
    System.put_env("GMAIL_KEYS_FILE", keys)
    System.put_env("GMAIL_REDIRECT_URI", "https://fixture.test/auth/google/callback")
    assert config()[Oban][:queues] == [gmail_delivery: 1]
    assert config()[Oban][:lifeline] == [rescue_after: {5, :minutes}]
    # The base config disables plugins; web runtime must override it for Lifeline leadership.
    oban =
      [repo: EmailSucks.Repo, plugins: false]
      |> Keyword.merge(config()[Oban])
      |> Oban.Config.new()

    assert {Oban.Lifeline, [rescue_after: {5, :minutes}]} in oban.plugins
    refute oban.peer == {Oban.Peers.Isolated, [leader?: false]}
    assert config()[:gmail][:allowed_email] == "owner@gmail.com"
    System.put_env("RESTORE_MODE", "true")
    assert config()[Oban][:queues] == false
    assert config()[:gmail] == nil
  end
end
