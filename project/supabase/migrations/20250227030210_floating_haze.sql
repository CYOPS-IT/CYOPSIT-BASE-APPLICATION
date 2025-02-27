/*
  # Fix policy conflicts and improve user management

  1. Security Functions
    - Ensure check_super_admin_exists function is properly defined
    - Ensure create_initial_setup function is properly defined
  
  2. Row Level Security
    - Drop existing policies before creating new ones to avoid conflicts
    - Create clear policies for users and organizations tables
*/

-- First, drop any existing policies that might conflict
DO $$
BEGIN
  -- Drop policies on users table
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Super admins have full access to users') THEN
    DROP POLICY "Super admins have full access to users" ON users;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Users can view own profile') THEN
    DROP POLICY "Users can view own profile" ON users;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Users can view organization members') THEN
    DROP POLICY "Users can view organization members" ON users;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Org admins manage organization users') THEN
    DROP POLICY "Org admins manage organization users" ON users;
  END IF;
  
  -- Drop policies on organizations table
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'organizations' AND policyname = 'Super admins have full access to organizations') THEN
    DROP POLICY "Super admins have full access to organizations" ON organizations;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'organizations' AND policyname = 'Users can view own organization') THEN
    DROP POLICY "Users can view own organization" ON organizations;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'organizations' AND policyname = 'Public view organizations for setup') THEN
    DROP POLICY "Public view organizations for setup" ON organizations;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'organizations' AND policyname = 'Public create first organization') THEN
    DROP POLICY "Public create first organization" ON organizations;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Public create first super admin') THEN
    DROP POLICY "Public create first super admin" ON users;
  END IF;
END
$$;

-- Create a security definer function to check if super admin exists (if it doesn't exist)
CREATE OR REPLACE FUNCTION public.check_super_admin_exists()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin' LIMIT 1);
$$;

-- Create a security definer function to create initial setup (if it doesn't exist)
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

-- Create new policies with unique names to avoid conflicts
-- Super admin can do anything with users
CREATE POLICY "Super admin full access to users"
  ON users
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Users can view their own profile
CREATE POLICY "User view own profile"
  ON users
  FOR SELECT
  USING (id = auth.uid());

-- Users can view other users in their organization
CREATE POLICY "User view organization members"
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
CREATE POLICY "Organization admin manage users"
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

-- Super admin can do anything with organizations
CREATE POLICY "Super admin full access to organizations"
  ON organizations
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Users can view their own organization
CREATE POLICY "User view own organization"
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
CREATE POLICY "Public organization view for setup"
  ON organizations
  FOR SELECT
  TO anon
  USING (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );

-- Allow public to create organizations during setup
CREATE POLICY "Public create initial organization"
  ON organizations
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );

-- Allow public to create the first super admin
CREATE POLICY "Public create initial super admin"
  ON users
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );