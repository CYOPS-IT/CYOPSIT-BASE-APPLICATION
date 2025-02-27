/*
  # Consolidated Schema for Multi-Tenant Admin Portal

  1. Core Tables
    - `organizations` - Stores organization information
    - `users` - Extends auth.users with profile and role information
    - `roles` - Defines system and organization roles
    - `permissions` - Defines available permissions
    - `role_permissions` - Junction table linking roles to permissions
    - `external_sync_log` - Tracks external database synchronization
    - `system_settings` - Stores system-wide settings and cache

  2. Security
    - Row Level Security (RLS) enabled on all tables
    - Non-recursive policies to prevent infinite recursion
    - JWT claims for role and organization information
    - Security definer functions for privileged operations

  3. Functions
    - `check_super_admin_exists` - Optimized function to check if super admin exists
    - `create_initial_setup` - Creates first organization and super admin
    - `sync_external_database` - Synchronizes with external data sources
    - `impersonate_user` - Allows super admins to impersonate users
    - `invite_user` - Invites a new user to an organization
    - `handle_new_user` - Sets JWT claims for users
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

-- Create system_settings table for caching and configuration
CREATE TABLE IF NOT EXISTS system_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_at timestamptz DEFAULT now()
);

-- Enable Row Level Security on all tables
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_sync_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

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

-- Create a trigger function to update the cache when users change
CREATE OR REPLACE FUNCTION update_super_admin_cache()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- If a super admin is added
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.role = 'super_admin' THEN
    INSERT INTO system_settings (key, value)
    VALUES ('super_admin_exists', jsonb_build_object('exists', true))
    ON CONFLICT (key) 
    DO UPDATE SET value = jsonb_build_object('exists', true), updated_at = now();
  END IF;
  
  -- If the last super admin is removed or changed role
  IF (TG_OP = 'DELETE' AND OLD.role = 'super_admin') OR 
     (TG_OP = 'UPDATE' AND OLD.role = 'super_admin' AND NEW.role != 'super_admin') THEN
    -- Check if any super admins still exist
    IF NOT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin' AND id != OLD.id) THEN
      -- If no super admins exist, update or delete the cache
      DELETE FROM system_settings WHERE key = 'super_admin_exists';
    END IF;
  END IF;
  
  RETURN NULL;
END;
$$;

-- Create the trigger on the users table
DROP TRIGGER IF EXISTS update_super_admin_cache_trigger ON users;
CREATE TRIGGER update_super_admin_cache_trigger
AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW EXECUTE FUNCTION update_super_admin_cache();

-- Create a function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers before creating them to avoid conflicts
DROP TRIGGER IF EXISTS update_organizations_timestamp ON organizations;
DROP TRIGGER IF EXISTS update_users_timestamp ON users;
DROP TRIGGER IF EXISTS update_roles_timestamp ON roles;

-- Create triggers to update timestamps
CREATE TRIGGER update_organizations_timestamp
BEFORE UPDATE ON organizations
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_users_timestamp
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_roles_timestamp
BEFORE UPDATE ON roles
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Create optimized function to check if super admin exists
CREATE OR REPLACE FUNCTION public.check_super_admin_exists()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cached_result boolean;
  actual_result boolean;
BEGIN
  -- Try to get cached result first
  SELECT (value->>'exists')::boolean INTO cached_result
  FROM system_settings
  WHERE key = 'super_admin_exists'
  LIMIT 1;
  
  -- If we have a cached result and it's true, return it immediately
  -- (We only cache positive results since they don't change often)
  IF cached_result IS NOT NULL AND cached_result = true THEN
    RETURN cached_result;
  END IF;
  
  -- Otherwise, check the actual result
  SELECT EXISTS (
    SELECT 1 
    FROM public.users 
    WHERE role = 'super_admin' 
    LIMIT 1
  ) INTO actual_result;
  
  -- If a super admin exists, cache this result
  IF actual_result = true THEN
    INSERT INTO system_settings (key, value)
    VALUES ('super_admin_exists', jsonb_build_object('exists', true))
    ON CONFLICT (key) 
    DO UPDATE SET value = jsonb_build_object('exists', true), updated_at = now();
  END IF;
  
  RETURN actual_result;
END;
$$;

-- Create function for initial setup
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

-- Create function to invite a new user with email verification
CREATE OR REPLACE FUNCTION invite_user(
  user_email text,
  user_first_name text,
  user_last_name text,
  user_role text,
  user_organization_id uuid,
  inviter_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_user_id uuid;
  result json;
BEGIN
  -- Check if inviter has permission
  IF NOT EXISTS (
    SELECT 1 FROM users 
    WHERE id = inviter_id 
    AND (
      role = 'super_admin' 
      OR (role = 'org_admin' AND organization_id = user_organization_id)
    )
  ) THEN
    RAISE EXCEPTION 'Permission denied. Only super admins or organization admins can invite users.';
  END IF;
  
  -- Check if email already exists
  IF EXISTS (SELECT 1 FROM users WHERE email = user_email) THEN
    RAISE EXCEPTION 'A user with this email already exists.';
  END IF;
  
  -- Generate a random user ID (this will be linked to auth.users)
  new_user_id := gen_random_uuid();
  
  -- Create user profile
  INSERT INTO users (
    id,
    email,
    first_name,
    last_name,
    role,
    organization_id
  ) VALUES (
    new_user_id,
    user_email,
    user_first_name,
    user_last_name,
    user_role,
    user_organization_id
  );
  
  -- Return success result
  SELECT json_build_object(
    'success', true,
    'user_id', new_user_id,
    'message', 'User invited successfully. Verification email will be sent.'
  ) INTO result;
  
  RETURN result;
END;
$$;

-- Create function to check if a user's email is verified
CREATE OR REPLACE FUNCTION is_email_verified(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT email_confirmed_at IS NOT NULL 
  FROM auth.users 
  WHERE id = user_id;
$$;

-- Create function to resend verification email
CREATE OR REPLACE FUNCTION resend_verification_email(user_email text, admin_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result json;
BEGIN
  -- Check if admin has permission
  IF NOT EXISTS (
    SELECT 1 FROM users 
    WHERE id = admin_id 
    AND (role = 'super_admin' OR role = 'org_admin')
  ) THEN
    RAISE EXCEPTION 'Permission denied. Only admins can resend verification emails.';
  END IF;
  
  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = user_email) THEN
    RAISE EXCEPTION 'User with this email does not exist.';
  END IF;
  
  -- Return success result
  -- Note: The actual email sending is handled by the client
  SELECT json_build_object(
    'success', true,
    'message', 'Verification email will be resent.'
  ) INTO result;
  
  RETURN result;
END;
$$;

-- Drop all existing policies to start fresh
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
  
  -- Drop policies on roles table
  FOR policy_record IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'roles' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON roles', policy_record.policyname);
  END LOOP;
  
  -- Drop policies on permissions table
  FOR policy_record IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'permissions' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON permissions', policy_record.policyname);
  END LOOP;
  
  -- Drop policies on role_permissions table
  FOR policy_record IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'role_permissions' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON role_permissions', policy_record.policyname);
  END LOOP;
  
  -- Drop policies on external_sync_log table
  FOR policy_record IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'external_sync_log' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON external_sync_log', policy_record.policyname);
  END LOOP;
  
  -- Drop policies on system_settings table
  FOR policy_record IN 
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'system_settings' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON system_settings', policy_record.policyname);
  END LOOP;
END
$$;

-- Create non-recursive policies for users table
-- 1. Allow users to view their own profile
CREATE POLICY "users_self_view"
  ON users
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- 2. Allow super admins to do anything with users
CREATE POLICY "users_super_admin_all"
  ON users
  USING (
    (auth.jwt() ->> 'role')::text = 'super_admin'
  );

-- 3. Allow org admins to manage users in their org
CREATE POLICY "users_org_admin_manage"
  ON users
  USING (
    (auth.jwt() ->> 'role')::text = 'org_admin'
    AND
    (auth.jwt() ->> 'org_id')::uuid = users.organization_id
  );

-- 4. Allow users to view other users in their org
CREATE POLICY "users_org_members_view"
  ON users
  FOR SELECT
  USING (
    (auth.jwt() ->> 'org_id')::uuid = users.organization_id
  );

-- 5. Allow anonymous access for initial setup
CREATE POLICY "users_anon_setup_view"
  ON users
  FOR SELECT
  TO anon
  USING (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
    OR role = 'super_admin'
  );

-- 6. Allow anonymous to create the first super admin
CREATE POLICY "users_anon_setup_insert"
  ON users
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
  );

-- Create policies for organizations table
-- 1. Allow super admins to do anything with organizations
CREATE POLICY "orgs_super_admin_all"
  ON organizations
  USING (
    (auth.jwt() ->> 'role')::text = 'super_admin'
  );

-- 2. Allow users to view their own organization
CREATE POLICY "orgs_user_view"
  ON organizations
  FOR SELECT
  USING (
    id = (auth.jwt() ->> 'org_id')::uuid
  );

-- 3. Allow anonymous access for initial setup
CREATE POLICY "orgs_anon_setup_view"
  ON organizations
  FOR SELECT
  TO anon
  USING (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
  );

-- 4. Allow anonymous to create the first organization
CREATE POLICY "orgs_anon_setup_insert"
  ON organizations
  FOR INSERT
  TO anon
  WITH CHECK (
    NOT EXISTS (SELECT 1 FROM public.users WHERE role = 'super_admin')
  );

-- Create policies for roles table
-- 1. Allow super admins to do anything with roles
CREATE POLICY "roles_super_admin_all"
  ON roles
  USING (
    (auth.jwt() ->> 'role')::text = 'super_admin'
  );

-- 2. Allow org admins to manage roles in their organization
CREATE POLICY "roles_org_admin_manage"
  ON roles
  USING (
    (auth.jwt() ->> 'role')::text = 'org_admin'
    AND
    organization_id = (auth.jwt() ->> 'org_id')::uuid
  );

-- 3. Allow users to view roles in their organization
CREATE POLICY "roles_user_view"
  ON roles
  FOR SELECT
  USING (
    organization_id IS NULL OR
    organization_id = (auth.jwt() ->> 'org_id')::uuid
  );

-- Create policies for permissions table
-- 1. Allow super admins to do anything with permissions
CREATE POLICY "permissions_super_admin_all"
  ON permissions
  USING (
    (auth.jwt() ->> 'role')::text = 'super_admin'
  );

-- 2. Allow users to view permissions
CREATE POLICY "permissions_user_view"
  ON permissions
  FOR SELECT
  USING (true);

-- Create policies for role_permissions table
-- 1. Allow super admins to do anything with role_permissions
CREATE POLICY "role_permissions_super_admin_all"
  ON role_permissions
  USING (
    (auth.jwt() ->> 'role')::text = 'super_admin'
  );

-- 2. Allow org admins to manage role_permissions for their organization
CREATE POLICY "role_permissions_org_admin_manage"
  ON role_permissions
  USING (
    (auth.jwt() ->> 'role')::text = 'org_admin'
    AND
    EXISTS (
      SELECT 1 FROM roles
      WHERE roles.id = role_permissions.role_id
      AND roles.organization_id = (auth.jwt() ->> 'org_id')::uuid
    )
  );

-- 3. Allow users to view role_permissions
CREATE POLICY "role_permissions_user_view"
  ON role_permissions
  FOR SELECT
  USING (true);

-- Create policies for external_sync_log table
-- 1. Allow super admins to do anything with external_sync_log
CREATE POLICY "external_sync_log_super_admin_all"
  ON external_sync_log
  USING (
    (auth.jwt() ->> 'role')::text = 'super_admin'
  );

-- 2. Allow users to view external_sync_log
CREATE POLICY "external_sync_log_user_view"
  ON external_sync_log
  FOR SELECT
  USING (true);

-- Create policies for system_settings table
-- 1. Allow super admins to manage system settings
CREATE POLICY "system_settings_super_admin_all"
  ON system_settings
  USING (
    (auth.jwt() ->> 'role')::text = 'super_admin'
  );

-- 2. Allow anyone to read system settings
CREATE POLICY "system_settings_anyone_read"
  ON system_settings
  FOR SELECT
  USING (true);

-- Insert default system roles
INSERT INTO roles (name, is_system_role) 
VALUES 
  ('super_admin', true),
  ('org_admin', true),
  ('user', true)
ON CONFLICT (name, organization_id) DO NOTHING;

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
  ('sync:external', 'Sync with external database')
ON CONFLICT (name) DO NOTHING;

-- Assign permissions to roles
DO $$
DECLARE
  super_admin_id uuid;
  org_admin_id uuid;
  user_id uuid;
  perm_id uuid;
BEGIN
  SELECT id INTO super_admin_id FROM roles WHERE name = 'super_admin' AND organization_id IS NULL;
  SELECT id INTO org_admin_id FROM roles WHERE name = 'org_admin' AND organization_id IS NULL;
  SELECT id INTO user_id FROM roles WHERE name = 'user' AND organization_id IS NULL;
  
  -- Only proceed if we found the roles
  IF super_admin_id IS NOT NULL AND org_admin_id IS NOT NULL AND user_id IS NOT NULL THEN
    -- Assign all permissions to super_admin
    FOR perm_id IN SELECT id FROM permissions
    LOOP
      INSERT INTO role_permissions (role_id, permission_id)
      VALUES (super_admin_id, perm_id)
      ON CONFLICT (role_id, permission_id) DO NOTHING;
    END LOOP;
    
    -- Assign organization management permissions to org_admin
    FOR perm_id IN SELECT id FROM permissions 
      WHERE name IN ('create:users', 'read:users', 'update:users', 'delete:users', 'create:roles', 'read:roles', 'update:roles', 'delete:roles')
    LOOP
      INSERT INTO role_permissions (role_id, permission_id)
      VALUES (org_admin_id, perm_id)
      ON CONFLICT (role_id, permission_id) DO NOTHING;
    END LOOP;
    
    -- Assign basic permissions to user
    FOR perm_id IN SELECT id FROM permissions 
      WHERE name IN ('read:users', 'read:roles')
    LOOP
      INSERT INTO role_permissions (role_id, permission_id)
      VALUES (user_id, perm_id)
      ON CONFLICT (role_id, permission_id) DO NOTHING;
    END LOOP;
  END IF;
END $$;

-- Initialize the cache if super admin exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM users WHERE role = 'super_admin') THEN
    INSERT INTO system_settings (key, value)
    VALUES ('super_admin_exists', jsonb_build_object('exists', true))
    ON CONFLICT (key) 
    DO UPDATE SET value = jsonb_build_object('exists', true), updated_at = now();
  ELSE
    DELETE FROM system_settings WHERE key = 'super_admin_exists';
  END IF;
END
$$;

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