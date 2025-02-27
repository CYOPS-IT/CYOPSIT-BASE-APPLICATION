/*
  # Super Admin Utility Functions

  1. New Functions
    - `super_admin_exists` - Checks if any super admin users exist in the system
  
  2. Documentation
    - Added helpful comments on how to create a super admin user
*/

-- Create a function to check if a super admin exists
CREATE OR REPLACE FUNCTION super_admin_exists()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin');
$$;

-- Add a comment explaining how to create a super admin
COMMENT ON FUNCTION super_admin_exists IS 
'Check if any super admin users exist in the system.
To create a super admin:
1. First create a user through the Supabase Auth API
2. Then use the set_user_as_super_admin function to set them as a super admin
Example:
  SELECT set_user_as_super_admin(
    ''user-uuid-from-auth'', 
    ''admin@example.com'', 
    ''Super'', 
    ''Admin''
  );';