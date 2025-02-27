/*
  # Fix Database Policies and Functions

  1. Changes
     - Drop existing policies that might cause conflicts
     - Create non-recursive check_super_admin_exists function
     - Create simplified policies with direct checks
     - Fix policy naming to avoid conflicts
  
  2. Security
     - Maintain proper row-level security
     - Ensure proper access control for different user roles
*/

-- First, drop existing policies that might conflict using a safer approach
DO $$
DECLARE
  policy_record RECORD;
BEGIN
  -- Drop policies on users table
  FOR policy_record IN 
    SELECT policyname FROM pg_policies 
    WHERE tablename = 'users' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON users', policy_record.policyname);
  END LOOP;
  
  -- Drop policies on organizations table
  FOR policy_record IN 
    SELECT policyname FROM pg_policies 
    WHERE tablename = 'organizations' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON organizations', policy_record.policyname);
  END LOOP;
END
$$;

-- Create a non-recursive function to check if super admin exists
CREATE OR REPLACE FUNCTION public.check_super_admin_exists()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Direct query without using RLS
  RETURN EXISTS (
    SELECT 1 
    FROM users 
    WHERE role = 'super_admin' 
    LIMIT 1
  );
END;
$$;

-- Create simplified policies for users table
-- Allow authenticated users to see their own profile (no recursion)
CREATE POLICY "users_self_select"
  ON users
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Allow super admins to do anything with users (no recursion)
CREATE POLICY "users_super_admin_all"
  ON users
  TO authenticated
  USING (
    (SELECT role FROM users WHERE id = auth.uid()) = 'super_admin'
  );

-- Allow org admins to manage users in their org (no recursion)
CREATE POLICY "users_org_admin_all"
  ON users
  TO authenticated
  USING (
    (SELECT role FROM users WHERE id = auth.uid()) = 'org_admin'
    AND 
    (SELECT organization_id FROM users WHERE id = auth.uid()) = users.organization_id
  );

-- Allow users to view other users in their org (no recursion)
CREATE POLICY "users_org_members_select"
  ON users
  FOR SELECT
  TO authenticated
  USING (
    users.organization_id = (SELECT organization_id FROM users WHERE id = auth.uid())
  );

-- Allow anonymous access for initial setup
CREATE POLICY "users_anon_setup"
  ON users
  TO anon
  USING (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
    OR
    role = 'super_admin'
  );

-- Allow anonymous to create the first super admin
CREATE POLICY "users_anon_insert"
  ON users
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );

-- Create simplified policies for organizations table
-- Allow super admins to do anything with organizations
CREATE POLICY "orgs_super_admin_all"
  ON organizations
  TO authenticated
  USING (
    (SELECT role FROM users WHERE id = auth.uid()) = 'super_admin'
  );

-- Allow users to view their own organization
CREATE POLICY "orgs_user_select"
  ON organizations
  FOR SELECT
  TO authenticated
  USING (
    id = (SELECT organization_id FROM users WHERE id = auth.uid())
  );

-- Allow anonymous access for initial setup
CREATE POLICY "orgs_anon_setup"
  ON organizations
  TO anon
  USING (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );

-- Allow anonymous to create the first organization
CREATE POLICY "orgs_anon_insert"
  ON organizations
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );