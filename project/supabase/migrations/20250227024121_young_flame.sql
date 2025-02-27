/*
  # Super Admin Helper Functions
  
  1. New Functions
     - Creates a helper function to check if a super admin exists
     - Provides documentation on super admin management
*/

-- Create a function to check if a super admin exists
CREATE OR REPLACE FUNCTION check_super_admin_exists()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT EXISTS (SELECT 1 FROM users WHERE role = 'super_admin');
$$;

-- Add helpful comment for administrators
COMMENT ON FUNCTION check_super_admin_exists IS 
'Checks if any super admin users exist in the system.
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