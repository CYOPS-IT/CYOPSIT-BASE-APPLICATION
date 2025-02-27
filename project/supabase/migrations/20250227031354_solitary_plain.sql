/*
  # Optimize Super Admin Existence Check

  1. Changes
     - Modify the check_super_admin_exists function to cache results
     - Add a trigger to invalidate cache when super admin status changes
     - Improve performance by avoiding redundant checks

  2. Security
     - Maintain existing security model
     - No changes to access control policies
*/

-- Create a table to cache the super admin existence check
CREATE TABLE IF NOT EXISTS system_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS on the system_settings table
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- Allow super admins to manage system settings
CREATE POLICY "super_admin_manage_settings"
  ON system_settings
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role = 'super_admin'
    )
  );

-- Allow anyone to read system settings
CREATE POLICY "anyone_read_settings"
  ON system_settings
  FOR SELECT
  USING (true);

-- Optimize the check_super_admin_exists function to use caching
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