/*
  # Initial Schema Setup for Multi-Tenant Application

  1. New Tables
    - `organizations` - Stores organization information
    - `users` - Stores user profiles linked to auth.users
    - `roles` - Stores role definitions
    - `permissions` - Stores permission definitions
    - `role_permissions` - Junction table for roles and permissions
    - `external_sync_log` - Tracks synchronization with external database

  2. Security
    - Enable RLS on all tables
    - Create policies for each table
    - Set up super admin access

  3. Functions
    - Create function for external database synchronization
    - Create function for user impersonation (super admin only)
*/

-- Create organizations table
CREATE TABLE IF NOT EXISTS organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  shortname text NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create users table (extends auth.users)
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  email text NOT NULL UNIQUE,
  first_name text,
  last_name text,
  role text NOT NULL,
  organization_id uuid REFERENCES organizations(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create roles table
CREATE TABLE IF NOT EXISTS roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  organization_id uuid REFERENCES organizations(id),
  is_system_role boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(name, organization_id)
);

-- Create permissions table
CREATE TABLE IF NOT EXISTS permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Create role_permissions junction table
CREATE TABLE IF NOT EXISTS role_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(role_id, permission_id)
);

-- Create external_sync_log table
CREATE TABLE IF NOT EXISTS external_sync_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sync_type text NOT NULL,
  status text NOT NULL,
  details jsonb,
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_sync_log ENABLE ROW LEVEL SECURITY;

-- Create policies for organizations
CREATE POLICY "Super admins can do anything with organizations"
  ON organizations
  USING (auth.jwt() ->> 'role' = 'super_admin');

CREATE POLICY "Users can view their own organization"
  ON organizations
  FOR SELECT
  USING (id = (SELECT organization_id FROM users WHERE id = auth.uid()));

-- Create policies for users
CREATE POLICY "Super admins can do anything with users"
  ON users
  USING (auth.jwt() ->> 'role' = 'super_admin');

CREATE POLICY "Organization admins can manage users in their organization"
  ON users
  USING (
    (auth.jwt() ->> 'role' = 'org_admin') AND
    organization_id = (SELECT organization_id FROM users WHERE id = auth.uid())
  );

CREATE POLICY "Users can view users in their organization"
  ON users
  FOR SELECT
  USING (
    organization_id = (SELECT organization_id FROM users WHERE id = auth.uid())
  );

CREATE POLICY "Users can view their own profile"
  ON users
  FOR SELECT
  USING (id = auth.uid());

-- Create policies for roles
CREATE POLICY "Super admins can do anything with roles"
  ON roles
  USING (auth.jwt() ->> 'role' = 'super_admin');

CREATE POLICY "Organization admins can manage roles in their organization"
  ON roles
  USING (
    (auth.jwt() ->> 'role' = 'org_admin') AND
    organization_id = (SELECT organization_id FROM users WHERE id = auth.uid())
  );

CREATE POLICY "Users can view roles in their organization"
  ON roles
  FOR SELECT
  USING (
    organization_id IS NULL OR
    organization_id = (SELECT organization_id FROM users WHERE id = auth.uid())
  );

-- Create policies for permissions
CREATE POLICY "Super admins can do anything with permissions"
  ON permissions
  USING (auth.jwt() ->> 'role' = 'super_admin');

CREATE POLICY "Users can view permissions"
  ON permissions
  FOR SELECT
  USING (true);

-- Create policies for role_permissions
CREATE POLICY "Super admins can do anything with role_permissions"
  ON role_permissions
  USING (auth.jwt() ->> 'role' = 'super_admin');

CREATE POLICY "Organization admins can manage role_permissions for their organization"
  ON role_permissions
  USING (
    (auth.jwt() ->> 'role' = 'org_admin') AND
    EXISTS (
      SELECT 1 FROM roles
      WHERE roles.id = role_permissions.role_id
      AND roles.organization_id = (SELECT organization_id FROM users WHERE id = auth.uid())
    )
  );

CREATE POLICY "Users can view role_permissions"
  ON role_permissions
  FOR SELECT
  USING (true);

-- Create policies for external_sync_log
CREATE POLICY "Super admins can do anything with external_sync_log"
  ON external_sync_log
  USING (auth.jwt() ->> 'role' = 'super_admin');

CREATE POLICY "Users can view external_sync_log"
  ON external_sync_log
  FOR SELECT
  USING (true);

-- Insert default system roles
INSERT INTO roles (name, is_system_role) 
VALUES 
  ('super_admin', true),
  ('org_admin', true),
  ('user', true);

-- Insert default permissions
INSERT INTO permissions (name, description)
VALUES
  ('create:users', 'Create users'),
  ('read:users', 'Read users'),
  ('update:users', 'Update users'),
  ('delete:users', 'Delete users'),
  ('create:roles', 'Create roles'),
  ('read:roles', 'Read roles'),
  ('update:roles', 'Update roles'),
  ('delete:roles', 'Delete roles'),
  ('impersonate:users', 'Impersonate users'),
  ('sync:external', 'Sync with external database');

-- Assign permissions to roles
DO $$
DECLARE
  super_admin_id uuid;
  org_admin_id uuid;
  user_id uuid;
  perm_id uuid;
BEGIN
  SELECT id INTO super_admin_id FROM roles WHERE name = 'super_admin';
  SELECT id INTO org_admin_id FROM roles WHERE name = 'org_admin';
  SELECT id INTO user_id FROM roles WHERE name = 'user';
  
  -- Assign all permissions to super_admin
  FOR perm_id IN SELECT id FROM permissions
  LOOP
    INSERT INTO role_permissions (role_id, permission_id)
    VALUES (super_admin_id, perm_id);
  END LOOP;
  
  -- Assign organization management permissions to org_admin
  FOR perm_id IN SELECT id FROM permissions 
    WHERE name IN ('create:users', 'read:users', 'update:users', 'delete:users', 'create:roles', 'read:roles', 'update:roles', 'delete:roles')
  LOOP
    INSERT INTO role_permissions (role_id, permission_id)
    VALUES (org_admin_id, perm_id);
  END LOOP;
  
  -- Assign basic permissions to user
  FOR perm_id IN SELECT id FROM permissions 
    WHERE name IN ('read:users', 'read:roles')
  LOOP
    INSERT INTO role_permissions (role_id, permission_id)
    VALUES (user_id, perm_id);
  END LOOP;
END $$;

-- Create function for external database synchronization
CREATE OR REPLACE FUNCTION sync_external_database()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  -- Check if user has permission
  IF NOT EXISTS (
    SELECT 1 FROM users u
    JOIN roles r ON u.role = r.name
    JOIN role_permissions rp ON r.id = rp.role_id
    JOIN permissions p ON rp.permission_id = p.id
    WHERE u.id = auth.uid() AND p.name = 'sync:external'
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  -- Log the sync attempt
  INSERT INTO external_sync_log (sync_type, status, details)
  VALUES ('full', 'started', jsonb_build_object('initiated_by', auth.uid()));
  
  -- Here you would implement the actual sync logic
  -- This is a placeholder for the actual implementation
  
  -- Update the sync log
  UPDATE external_sync_log
  SET status = 'completed', 
      details = jsonb_build_object(
        'initiated_by', auth.uid(),
        'completed_at', now(),
        'records_synced', 0
      )
  WHERE status = 'started' AND details->>'initiated_by' = auth.uid()::text
  RETURNING details INTO result;
  
  RETURN result;
END;
$$;

-- Create function for user impersonation (super admin only)
CREATE OR REPLACE FUNCTION impersonate_user(target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  is_super_admin boolean;
  result jsonb;
BEGIN
  -- Check if the current user is a super admin
  SELECT (role = 'super_admin') INTO is_super_admin
  FROM users
  WHERE id = auth.uid();
  
  IF NOT is_super_admin THEN
    RAISE EXCEPTION 'Only super admins can impersonate users';
  END IF;
  
  -- Here you would implement the actual impersonation logic
  -- This would typically involve creating a new JWT token for the target user
  -- This is a placeholder for the actual implementation
  
  -- For demonstration purposes, return some information
  SELECT jsonb_build_object(
    'impersonator', auth.uid(),
    'target_user', target_user_id,
    'timestamp', now()
  ) INTO result;
  
  RETURN result;
END;
$$;

-- Create trigger to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_organizations_timestamp
BEFORE UPDATE ON organizations
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_users_timestamp
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_roles_timestamp
BEFORE UPDATE ON roles
FOR EACH ROW EXECUTE FUNCTION update_timestamp();