defmodule EmailSucks.Repo.Migrations.FreezeProbeMembership do
  use Ecto.Migration

  def up do
    execute """
    CREATE FUNCTION phase_zero_keep_snapshot_membership() RETURNS trigger
    LANGUAGE plpgsql SET search_path = '' AS $$
    BEGIN
      IF NEW.account_key IS DISTINCT FROM OLD.account_key
         OR NEW.message_ids IS DISTINCT FROM OLD.message_ids THEN
        RAISE EXCEPTION 'snapshot membership is immutable'
          USING ERRCODE = '23514', CONSTRAINT = 'phase_zero_snapshot_immutable';
      END IF;
      RETURN NEW;
    END;
    $$;
    """

    execute """
    CREATE TRIGGER phase_zero_snapshot_immutable
    BEFORE UPDATE ON phase_zero_snapshots
    FOR EACH ROW EXECUTE FUNCTION phase_zero_keep_snapshot_membership();
    """
  end

  def down do
    execute "DROP TRIGGER phase_zero_snapshot_immutable ON phase_zero_snapshots"
    execute "DROP FUNCTION phase_zero_keep_snapshot_membership()"
  end
end
