defmodule EmailSucks.PhaseZero.WorkItem do
  @moduledoc """
  Executable work-state contract; not yet persisted or connected to the UI.
  Dates must already be converted to the commitment's local calendar by the caller.
  Delivery/review records remain separate; this model does not mark intake reviewed.
  """
  @enforce_keys [:status]
  defstruct [:status, :horizon, :due_on, :waiting_since]

  def open(horizon, %Date{} = local_date) when horizon in [:today, :this_week, :whenever] do
    due_on =
      case horizon do
        :today -> local_date
        :this_week -> Date.add(local_date, rem(5 - Date.day_of_week(local_date) + 7, 7))
        :whenever -> nil
      end

    %__MODULE__{status: :open, horizon: horizon, due_on: due_on}
  end

  def wait(%__MODULE__{status: :open}, %Date{} = local_date) do
    %__MODULE__{status: :waiting, waiting_since: local_date}
  end

  def overdue?(%__MODULE__{status: :open, due_on: %Date{} = due_on}, %Date{} = local_date),
    do: Date.compare(local_date, due_on) == :gt

  def overdue?(%__MODULE__{}, %Date{}), do: false

  def reply(%__MODULE__{} = item, delivery, kind, %Date{} = local_date)
      when delivery in [:held, :released, :bypassed] and kind in [:human, :automated] do
    if item.status == :waiting and delivery != :held and kind == :human do
      open(:this_week, local_date)
    else
      item
    end
  end

  def after_send(%__MODULE__{} = item, outcome, disposition, %Date{} = local_date)
      when outcome in [:confirmed, :pending, :failed, :unknown] and
             disposition in [:done, :waiting, :keep_open] do
    if outcome == :confirmed do
      next =
        case disposition do
          :done -> %__MODULE__{status: :resolved}
          :waiting -> %__MODULE__{status: :waiting, waiting_since: local_date}
          :keep_open -> if item.status == :open, do: item, else: open(:this_week, local_date)
        end

      {:ok, next}
    else
      {:error, :send_not_confirmed}
    end
  end
end
