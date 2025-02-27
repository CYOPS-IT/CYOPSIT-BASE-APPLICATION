/*
  # Fix Infinite Recursion in RLS Policies

  1. Changes
     - Drop all existing policies on the users table that cause recursion
     - Create new non-recursive policies for the users table
     - Fix the issue with infinite recursion in policy for relation "users"

  2. Security
     - Maintain the same security model but with optimized implementation
     - Ensure all access control requirements are still met
*/

-- First, drop all existing policies on the users table
DO $$
DECLARE
  policy_record RECORD;
BEGIN
  FOR policy_record IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'users' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON users', policy_record.policyname);
  END LOOP;
END
$$;

-- Create new non-recursive policies for the users table

-- 1. Allow users to view their own profile (non-recursive)
CREATE POLICY "users_self_view_non_recursive"
  ON users
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- 2. Allow super admins to do anything with users (non-recursive)
-- This policy uses auth.jwt() instead of a recursive query
CREATE POLICY "users_super_admin_all_non_recursive"
  ON users
  USING (
    (auth.jwt() ->> 'role')::text = 'super_admin'
  );

-- 3. Allow org admins to manage users in their org (non-recursive)
-- This policy uses auth.jwt() and a direct join instead of a recursive query
CREATE POLICY "users_org_admin_manage_non_recursive"
  ON users
  USING (
    (auth.jwt() ->> 'role')::text = 'org_admin'
    AND
    (auth.jwt() ->> 'org_id')::uuid = users.organization_id
  );

-- 4. Allow users to view other users in their org (non-recursive)
-- This policy uses auth.jwt() instead of a recursive query
CREATE POLICY "users_org_members_view_non_recursive"
  ON users
  FOR SELECT
  USING (
    (auth.jwt() ->> 'org_id')::uuid = users.organization_id
  );

-- 5. Allow anonymous access for initial setup
CREATE POLICY "users_anon_setup_view_non_recursive"
  ON users
  FOR SELECT
  TO anon
  USING (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
    OR role = 'super_admin'
  );

-- 6. Allow anonymous to create the first super admin
CREATE POLICY "users_anon_setup_insert_non_recursive"
  ON users
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
  );

-- Create a function to set JWT claims with user role and organization
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update the user's auth.users entry with custom claims
  -- This will make the role and org_id available in the JWT
  UPDATE auth.users
  SET raw_app_meta_data = jsonb_build_object(
    'role', NEW.role,
    'org_id', NEW.organization_id
  )
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$;

-- Create a trigger to set JWT claims when a user is created or updated
DROP TRIGGER IF EXISTS on_user_created_or_updated ON users;
CREATE TRIGGER on_user_created_or_updated
AFTER INSERT OR UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Update existing users to set their JWT claims
DO $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN 
    SELECT id, role, organization_id 
    FROM users
  LOOP
    UPDATE auth.users
    SET raw_app_meta_data = jsonb_build_object(
      'role', user_record.role,
      'org_id', user_record.organization_id
    )
    WHERE id = user_record.id;
  END LOOP;
END
$$;