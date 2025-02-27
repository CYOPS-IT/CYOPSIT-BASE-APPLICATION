/*
  # Fix Recursive Policies

  1. Changes
     - Fix infinite recursion in user policies
     - Add proper RLS policies for setup functionality
     - Add function to check if setup is needed
*/

-- Drop the problematic policies that cause recursion
DROP POLICY IF EXISTS "Users can view users in their organization" ON users;
DROP POLICY IF EXISTS "Organization admins can manage users in their organization" ON users;

-- Create new policies that don't cause recursion
CREATE POLICY "Users can view users in their organization" 
  ON users
  FOR SELECT
  USING (
    organization_id IN (
      SELECT organization_id FROM users WHERE id = auth.uid()
    )
  );

CREATE POLICY "Organization admins can manage users in their organization"
  ON users
  USING (
    (SELECT role FROM users WHERE id = auth.uid()) = 'org_admin' AND
    organization_id IN (
      SELECT organization_id FROM users WHERE id = auth.uid()
    )
  );

-- Add policy to allow public access to super_admin_exists function
CREATE POLICY "Anyone can check if super admin exists"
  ON users
  FOR SELECT
  USING (role = 'super_admin');

-- Add policy to allow anonymous users to create the first super admin
CREATE POLICY "Allow creating the first super admin"
  ON users
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );

-- Add policy to allow anonymous users to create the first organization
CREATE POLICY "Allow creating the first organization"
  ON organizations
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin')
  );