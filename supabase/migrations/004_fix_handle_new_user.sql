-- ================================================================
-- 004 FIX HANDLE_NEW_USER TRIGGER
-- The trigger was blocking all new user creation because an exception
-- inside it rolls back the entire INSERT on auth.users.
-- Fix: wrap the profile insert in an EXCEPTION block so trigger
-- failure never prevents the auth user from being created.
-- Also adds SET search_path for security best practice.
-- ================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Profile creation failed (e.g. permission issue) — don't block user creation
  RETURN NEW;
END;
$$;

-- Ensure the function is owned by postgres so SECURITY DEFINER has full rights
ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

-- Re-grant execute so the trigger can fire
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;
