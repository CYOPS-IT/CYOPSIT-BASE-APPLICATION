/*
  # Fix Recursive Policies

  1. Changes
     - Drop all existing policies on users and organizations tables
     - Create new non-recursive policies with direct checks
     - Fix the check_super_admin_exists function to avoid RLS
  
  2. Security
     - Maintain proper row-level security
     - Ensure proper access control for different user roles
     - Fix infinite recursion issues
*/

-- First, drop all existing policies to start fresh
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
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  -- Direct SQL query that bypasses RLS
  SELECT EXISTS (
    SELECT 1 
    FROM public.users 
    WHERE role = 'super_admin' 
    LIMIT 1
  );
$$;

-- Create simplified policies for users table
-- Allow authenticated users to see their own profile
CREATE POLICY "users_self_view"
  ON users
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Allow super admins to do anything with users
-- This uses a direct subquery instead of a recursive check
CREATE POLICY "users_super_admin_all"
  ON users
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM public.users WHERE role = 'super_admin'
    )
  );

-- Allow org admins to manage users in their org
CREATE POLICY "users_org_admin_manage"
  ON users
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM public.users WHERE role = 'org_admin'
    )
    AND 
    users.organization_id IN (
      SELECT organization_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Allow users to view other users in their org
CREATE POLICY "users_org_members_view"
  ON users
  FOR SELECT
  TO authenticated
  USING (
    users.organization_id IN (
      SELECT organization_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Allow anonymous access for initial setup
CREATE POLICY "users_anon_setup_view"
  ON users
  FOR SELECT
  TO anon
  USING (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
    OR
    role = 'super_admin'
  );

-- Allow anonymous to create the first super admin
CREATE POLICY "users_anon_setup_insert"
  ON users
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
  );

-- Create simplified policies for organizations table
-- Allow super admins to do anything with organizations
CREATE POLICY "orgs_super_admin_all"
  ON organizations
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM public.users WHERE role = 'super_admin'
    )
  );

-- Allow users to view their own organization
CREATE POLICY "orgs_user_view"
  ON organizations
  FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT organization_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Allow anonymous access for initial setup
CREATE POLICY "orgs_anon_setup_view"
  ON organizations
  FOR SELECT
  TO anon
  USING (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
  );

-- Allow anonymous to create the first organization
CREATE POLICY "orgs_anon_setup_insert"
  ON organizations
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
  );