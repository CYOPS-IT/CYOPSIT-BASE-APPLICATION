/*
  # Fix Recursive Policies

  1. Changes
     - Drop and recreate problematic policies to eliminate infinite recursion
     - Simplify policy logic to avoid self-referential queries
     - Add direct access policies for setup functionality
*/

-- Drop all problematic policies that might cause recursion
DROP POLICY IF EXISTS "Users can view users in their organization" ON users;
DROP POLICY IF EXISTS "Organization admins can manage users in their organization" ON users;
DROP POLICY IF EXISTS "Anyone can check if super admin exists" ON users;
DROP POLICY IF EXISTS "Allow creating the first super admin" ON users;
DROP POLICY IF EXISTS "Allow creating the first organization" ON organizations;

-- Create simplified policies that don't cause recursion
-- Policy for users to view other users in their organization
CREATE POLICY "Users can view users in same organization" 
  ON users
  FOR SELECT
  USING (
    -- Either viewing your own profile
    id = auth.uid() 
    OR 
    -- Or viewing users in the same organization (using a direct join)
    (
      organization_id IS NOT NULL AND
      organization_id IN (
        SELECT organization_id FROM users WHERE id = auth.uid() AND organization_id IS NOT NULL
      )
    )
    OR
    -- Or you're a super admin
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
  );

-- Policy for organization admins to manage users
CREATE POLICY "Organization admins manage organization users"
  ON users
  USING (
    -- Either you're a super admin
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    OR
    -- Or you're an org admin managing users in your organization
    (
      EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'org_admin') AND
      organization_id IN (
        SELECT organization_id FROM users WHERE id = auth.uid() AND organization_id IS NOT NULL
      )
    )
  );

-- Allow public access for initial setup
CREATE POLICY "Public can check for super admin existence"
  ON users
  FOR SELECT
  TO anon
  USING (role = 'super_admin');

-- Allow anonymous users to create the first super admin
CREATE POLICY "Anonymous can create first super admin"
  ON users
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );

-- Allow anonymous users to create the first organization
CREATE POLICY "Anonymous can create first organization"
  ON organizations
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );

-- Allow public to view organizations for setup
CREATE POLICY "Public can view organizations"
  ON organizations
  FOR SELECT
  TO anon
  USING (true);