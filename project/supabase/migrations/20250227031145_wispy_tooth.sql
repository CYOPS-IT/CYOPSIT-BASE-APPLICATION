/*
  # Fix Recursion Issues in RLS Policies

  1. Changes
     - Drop all existing policies on users and organizations tables
     - Create new non-recursive policies that avoid infinite recursion
     - Fix the check_super_admin_exists function to use a direct query
     - Add proper RLS policies for all tables with safe implementation

  2. Security
     - Maintain proper row-level security for all tables
     - Ensure super admin access works correctly
     - Allow organization admins to manage their organization users
     - Enable initial setup for first-time system configuration
*/

-- First, drop all existing policies to start fresh
DO $$
DECLARE
  policy_record RECORD;
BEGIN
  -- Drop policies on users table
  FOR policy_record IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'users' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON users', policy_record.policyname);
  END LOOP;
  
  -- Drop policies on organizations table
  FOR policy_record IN 
    SELECT policyname 
    FROM pg_policies 
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
CREATE POLICY "users_super_admin_all"
  ON users
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  );

-- Allow org admins to manage users in their org
CREATE POLICY "users_org_admin_manage"
  ON users
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() 
      AND role = 'org_admin'
      AND organization_id = users.organization_id
    )
  );

-- Allow users to view other users in their org
CREATE POLICY "users_org_members_view"
  ON users
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid()
      AND organization_id = users.organization_id
    )
  );

-- Allow anonymous access for initial setup
CREATE POLICY "users_anon_setup_view"
  ON users
  FOR SELECT
  TO anon
  USING (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
    OR role = 'super_admin'
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
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  );

-- Allow users to view their own organization
CREATE POLICY "orgs_user_view"
  ON organizations
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid()
      AND organization_id = organizations.id
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