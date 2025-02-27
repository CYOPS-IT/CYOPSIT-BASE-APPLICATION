/*
  # Fix Authentication and Policy Issues

  1. Changes
     - Simplify policy structure to avoid recursion
     - Create security definer functions for initial setup
     - Fix organization access policies
     - Break down complex queries into simpler ones
*/

-- Create a security definer function to check if super admin exists
-- This bypasses RLS and avoids recursion
CREATE OR REPLACE FUNCTION public.check_super_admin_exists()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin' LIMIT 1);
$$;

-- Create a security definer function to create initial setup
CREATE OR REPLACE FUNCTION public.create_initial_setup(
  org_name text,
  org_shortname text,
  user_email text,
  user_first_name text,
  user_last_name text,
  user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_org_id uuid;
  result json;
BEGIN
  -- Check if super admin already exists
  IF EXISTS (SELECT 1 FROM users WHERE role = 'super_admin') THEN
    RAISE EXCEPTION 'Setup already completed. A super admin already exists.';
  END IF;
  
  -- Create organization
  INSERT INTO organizations (name, shortname)
  VALUES (org_name, org_shortname)
  RETURNING id INTO new_org_id;
  
  -- Create super admin user
  INSERT INTO users (
    id,
    email,
    first_name,
    last_name,
    role,
    organization_id
  ) VALUES (
    user_id,
    user_email,
    user_first_name,
    user_last_name,
    'super_admin',
    new_org_id
  );
  
  -- Return success result
  SELECT json_build_object(
    'success', true,
    'organization_id', new_org_id,
    'message', 'Initial setup completed successfully'
  ) INTO result;
  
  RETURN result;
END;
$$;

-- Drop existing policies that might conflict
DO $$
BEGIN
  -- Drop user policies if they exist
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Users can view users in same organization') THEN
    DROP POLICY "Users can view users in same organization" ON users;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Organization admins manage organization users') THEN
    DROP POLICY "Organization admins manage organization users" ON users;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Public can check for super admin existence') THEN
    DROP POLICY "Public can check for super admin existence" ON users;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Anonymous can create first super admin') THEN
    DROP POLICY "Anonymous can create first super admin" ON users;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Users can view their own profile') THEN
    DROP POLICY "Users can view their own profile" ON users;
  END IF;
  
  -- Drop organization policies if they exist
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'organizations' AND policyname = 'Anonymous can create first organization') THEN
    DROP POLICY "Anonymous can create first organization" ON organizations;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'organizations' AND policyname = 'Public can view organizations') THEN
    DROP POLICY "Public can view organizations" ON organizations;
  END IF;
END
$$;

-- Create simplified policies for users table
-- Super admin can do anything
CREATE POLICY "Super admins full access"
  ON users
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Create a new policy for users to view their own profile
CREATE POLICY "Users view own profile"
  ON users
  FOR SELECT
  USING (id = auth.uid());

-- Users can view other users in their organization
CREATE POLICY "Users view organization members"
  ON users
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users self
      WHERE self.id = auth.uid()
      AND self.organization_id IS NOT NULL
      AND self.organization_id = users.organization_id
    )
  );

-- Organization admins can manage users in their organization
CREATE POLICY "Org admins manage users"
  ON users
  USING (
    EXISTS (
      SELECT 1 FROM users self
      WHERE self.id = auth.uid()
      AND self.role = 'org_admin'
      AND self.organization_id IS NOT NULL
      AND self.organization_id = users.organization_id
    )
  );

-- Create simplified policies for organizations table
-- Super admin can do anything
CREATE POLICY "Super admins manage orgs"
  ON organizations
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Users can view their own organization
CREATE POLICY "Users view own org"
  ON organizations
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.organization_id = organizations.id
    )
  );

-- Allow public access to organizations for setup
CREATE POLICY "Public view orgs for setup"
  ON organizations
  FOR SELECT
  TO anon
  USING (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );

-- Allow public to create organizations during setup
CREATE POLICY "Public create first org"
  ON organizations
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );

-- Allow public to create the first super admin
CREATE POLICY "Public create first admin"
  ON users
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );