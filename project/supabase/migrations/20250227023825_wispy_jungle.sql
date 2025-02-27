/*
  # Create Initial Super Admin User

  1. Creates a function to add a super admin user
  2. This migration provides a function that can be called after creating a user through the Supabase Auth API
*/

-- Create a function to set a user as super admin
CREATE OR REPLACE FUNCTION set_user_as_super_admin(
  user_uuid UUID,
  user_email TEXT,
  first_name TEXT DEFAULT 'Super',
  last_name TEXT DEFAULT 'Admin'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Insert user profile with super_admin role
  INSERT INTO users (
    id, 
    email, 
    first_name, 
    last_name, 
    role
  ) VALUES (
    user_uuid,
    user_email,
    first_name,
    last_name,
    'super_admin'
  )
  ON CONFLICT (id) DO UPDATE
  SET role = 'super_admin',
      first_name = EXCLUDED.first_name,
      last_name = EXCLUDED.last_name;
END;
$$;

-- Add a comment explaining how to use this function
COMMENT ON FUNCTION set_user_as_super_admin IS 
'After creating a user through the Supabase Auth API, call this function to set them as a super admin.
Example usage:
  SELECT set_user_as_super_admin(
    ''user-uuid-from-auth'', 
    ''admin@example.com'', 
    ''Super'', 
    ''Admin''
  );';