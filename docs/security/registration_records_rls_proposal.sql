-- Proposal only; this file is outside supabase/migrations and has not been run.
-- Based on the policy definitions reported by the project owner.
-- Review the live policy list and application behavior before applying manually.
-- This removes only the five reported policies targeting PUBLIC. It preserves
-- reg_insert, reg_manage, reg_read, and reg_update for authenticated users.

BEGIN;

DROP POLICY IF EXISTS registration_parent_insert ON public.registration_records;
DROP POLICY IF EXISTS registration_parent_update ON public.registration_records;
DROP POLICY IF EXISTS registration_parent_read ON public.registration_records;
DROP POLICY IF EXISTS registration_staff_read ON public.registration_records;
DROP POLICY IF EXISTS registration_manager_update ON public.registration_records;

COMMIT;

-- Rollback (run manually only if the exact original policies are to be restored):
-- BEGIN;
-- CREATE POLICY registration_parent_insert
--   ON public.registration_records AS PERMISSIVE FOR INSERT TO public
--   WITH CHECK (parent_id = auth.uid());
-- CREATE POLICY registration_parent_update
--   ON public.registration_records AS PERMISSIVE FOR UPDATE TO public
--   USING (parent_id = auth.uid())
--   WITH CHECK (parent_id = auth.uid());
-- CREATE POLICY registration_parent_read
--   ON public.registration_records AS PERMISSIVE FOR SELECT TO public
--   USING (parent_id = auth.uid());
-- CREATE POLICY registration_staff_read
--   ON public.registration_records AS PERMISSIVE FOR SELECT TO public
--   USING (app_is_staff());
-- CREATE POLICY registration_manager_update
--   ON public.registration_records AS PERMISSIVE FOR UPDATE TO public
--   USING (app_is_manager())
--   WITH CHECK (app_is_manager());
-- COMMIT;
