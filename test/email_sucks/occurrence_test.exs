defmodule EmailSucks.OccurrenceTest do
  use ExUnit.Case, async: true
  alias EmailSucks.PhaseZero.Occurrence

  test "spring gap uses the first valid local instant, not an invented clock time" do
    assert {:ok, occurrence} =
             Occurrence.resolve("fixture", 1, ~D[2026-03-08], ~T[02:30:00], "America/New_York")

    assert occurrence.scheduled_at == ~U[2026-03-08 07:00:00Z]
    assert DateTime.to_time(occurrence.local_at) == ~T[03:00:00]
    assert occurrence.adjustment == :gap
    assert occurrence.requested_time == ~T[02:30:00]
  end

  test "fall overlap selects the earlier instant with one stable identity" do
    {:ok, occurrence} =
      Occurrence.resolve("fixture", 1, ~D[2026-11-01], ~T[01:30:00], "America/New_York")

    assert occurrence.scheduled_at == ~U[2026-11-01 05:30:00Z]
    assert occurrence.adjustment == :overlap

    assert {:ok, ^occurrence} =
             Occurrence.resolve("fixture", 1, ~D[2026-11-01], ~T[01:30:00], "America/New_York")

    {:ok, edited} =
      Occurrence.resolve("fixture", 2, ~D[2026-11-01], ~T[01:30:00], "America/New_York")

    refute occurrence.id == edited.id
  end

  test "normal windows preserve the user's clock across DST dates" do
    {:ok, winter} =
      Occurrence.resolve("fixture", 1, ~D[2026-03-07], ~T[09:00:00], "America/New_York")

    {:ok, summer} =
      Occurrence.resolve("fixture", 1, ~D[2026-03-08], ~T[09:00:00], "America/New_York")

    assert winter.scheduled_at == ~U[2026-03-07 14:00:00Z]
    assert summer.scheduled_at == ~U[2026-03-08 13:00:00Z]
    assert winter.adjustment == :none
    assert summer.adjustment == :none
    refute winter.id == summer.id
  end

  test "non-hour DST gap follows the timezone database" do
    {:ok, occurrence} =
      Occurrence.resolve("fixture", 1, ~D[2026-10-04], ~T[02:15:00], "Australia/Lord_Howe")

    assert occurrence.scheduled_at == ~U[2026-10-03 15:30:00Z]
    assert DateTime.to_time(occurrence.local_at) == ~T[02:30:00]
  end

  test "unknown zones and wholly skipped dates produce explicit exceptions" do
    assert {:error, :time_zone_not_found} =
             Occurrence.resolve("fixture", 1, ~D[2026-09-04], ~T[09:00:00], "Not/AZone")

    assert {:error, :skipped_local_date} =
             Occurrence.resolve("fixture", 1, ~D[2011-12-30], ~T[09:00:00], "Pacific/Apia")
  end

  test "minute windows normalize precision and reject sub-minute configuration" do
    {:ok, first} = Occurrence.resolve("fixture", 1, ~D[2026-09-04], ~T[09:00:00], "Etc/UTC")

    assert {:ok, ^first} =
             Occurrence.resolve("fixture", 1, ~D[2026-09-04], ~T[09:00:00.000000], "Etc/UTC")

    assert {:error, :invalid_window_time} =
             Occurrence.resolve("fixture", 1, ~D[2026-09-04], ~T[09:00:01], "Etc/UTC")
  end
end
