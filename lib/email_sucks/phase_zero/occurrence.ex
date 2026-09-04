defmodule EmailSucks.PhaseZero.Occurrence do
  @moduledoc """
  Resolve a local delivery window using bundled IANA data. No scheduling or I/O.
  Persist the returned UTC instant with its identity before claiming a delivery;
  a retry must reuse that record rather than resolve against a newer database.
  """

  def resolve(account_key, revision, %Date{} = date, %Time{} = time, zone)
      when is_binary(account_key) and is_integer(revision) and revision > 0 and is_binary(zone) do
    if time.second != 0 or elem(time.microsecond, 0) != 0 do
      {:error, :invalid_window_time}
    else
      time = Time.truncate(time, :second)

      case DateTime.new(date, time, zone, Tz.TimeZoneDatabase) do
        {:ok, local} ->
          resolved(account_key, revision, date, time, zone, local, :none)

        {:ambiguous, earlier, _later} ->
          resolved(account_key, revision, date, time, zone, earlier, :overlap)

        {:gap, _before, after_gap} ->
          resolved(account_key, revision, date, time, zone, after_gap, :gap)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc false
  def identity(account_key, revision, date, time, zone) do
    canonical =
      Jason.encode!([
        account_key,
        revision,
        Date.to_iso8601(date),
        Time.to_iso8601(Time.truncate(time, :second)),
        zone
      ])

    :crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower)
  end

  defp resolved(account_key, revision, date, time, zone, local, adjustment) do
    if DateTime.to_date(local) != date do
      {:error, :skipped_local_date}
    else
      {:ok,
       %{
         id: identity(account_key, revision, date, time, zone),
         requested_date: date,
         requested_time: time,
         time_zone: zone,
         local_at: local,
         scheduled_at: DateTime.shift_zone!(local, "Etc/UTC"),
         adjustment: adjustment,
         iana_version: Tz.iana_version()
       }}
    end
  end
end
