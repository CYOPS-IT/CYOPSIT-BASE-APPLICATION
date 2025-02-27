/*
  # Application Settings Table

  1. New Tables
     - `app_settings` - Stores application-wide settings like app name
       - `key` (text) - Setting identifier
       - `value` (text) - Setting value
       - `organization_id` (uuid, nullable) - Organization this setting applies to (null for global)
       - `created_at` (timestamptz) - Creation timestamp
       - `updated_at` (timestamptz) - Last update timestamp
  
  2. Security
     - Enable RLS on `app_settings` table
     - Add policy for super admins to manage all settings
     - Add policy for org admins to manage their organization's settings
     - Add policy for all users to read settings
*/

-- Create app_settings table with nullable organization_id
CREATE TABLE IF NOT EXISTS app_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL,
  value text NOT NULL,
  organization_id uuid REFERENCES organizations(id) NULL, -- Explicitly make this nullable
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (key, organization_id)
);

-- Enable Row Level Security
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Create policies for app_settings
-- Super admins can do anything with settings
CREATE POLICY "super_admin_manage_settings"
  ON app_settings
  USING (
    (auth.jwt() ->> 'role')::text = 'super_admin'
  );

-- Org admins can manage their organization's settings
CREATE POLICY "org_admin_manage_org_settings"
  ON app_settings
  USING (
    (auth.jwt() ->> 'role')::text = 'org_admin'
    AND
    organization_id = (auth.jwt() ->> 'org_id')::uuid
  );

-- All users can read settings
CREATE POLICY "users_read_settings"
  ON app_settings
  FOR SELECT
  USING (
    organization_id IS NULL OR
    organization_id = (auth.jwt() ->> 'org_id')::uuid
  );

-- Create trigger to update the updated_at timestamp
CREATE TRIGGER update_app_settings_timestamp
BEFORE UPDATE ON app_settings
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Insert default app name
INSERT INTO app_settings (key, value, organization_id)
VALUES ('app_name', 'Admin Portal', NULL);

-- Create function to get app name for an organization
CREATE OR REPLACE FUNCTION get_app_name(org_id uuid DEFAULT NULL)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  app_name text;
BEGIN
  -- First try to get organization-specific name
  IF org_id IS NOT NULL THEN
    SELECT value INTO app_name
    FROM app_settings
    WHERE key = 'app_name' AND organization_id = org_id;
  END IF;
  
  -- If no organization-specific name, get default
  IF app_name IS NULL THEN
    SELECT value INTO app_name
    FROM app_settings
    WHERE key = 'app_name' AND organization_id IS NULL;
  END IF;
  
  -- If still null, return a default
  IF app_name IS NULL THEN
    app_name := 'Admin Portal';
  END IF;
  
  RETURN app_name;
END;
$$;

-- Create function to update app name for an organization
CREATE OR REPLACE FUNCTION update_app_name(new_name text, org_id uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user has permission
  IF NOT (
    (auth.jwt() ->> 'role')::text = 'super_admin' OR
    ((auth.jwt() ->> 'role')::text = 'org_admin' AND (auth.jwt() ->> 'org_id')::uuid = org_id)
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  -- Insert or update the app name
  INSERT INTO app_settings (key, value, organization_id)
  VALUES ('app_name', new_name, org_id)
  ON CONFLICT (key, organization_id) 
  DO UPDATE SET value = new_name, updated_at = now();
  
  RETURN true;
END;
$$;