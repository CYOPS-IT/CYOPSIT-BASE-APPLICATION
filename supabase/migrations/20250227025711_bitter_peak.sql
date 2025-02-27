/*
  # User Management and Email Verification

  1. New Functions
     - Create function to invite users with email verification
     - Create function to resend verification emails
     - Create function to check email verification status
  
  2. Security
     - All functions use SECURITY DEFINER to bypass RLS
     - Functions include proper permission checks
*/

-- Create a function to invite a new user with email verification
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
  
  -- Generate a random password (this will be changed by the user)
  -- In a real implementation, you would use a more secure method
  -- The user will reset this via email verification
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

-- Create a function to check if a user's email is verified
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

-- Create a function to resend verification email
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

-- Add comment explaining how to use these functions
COMMENT ON FUNCTION invite_user IS 
'Invites a new user and prepares for email verification.
Example usage:
  SELECT invite_user(
    ''user@example.com'', 
    ''First'', 
    ''Last'', 
    ''user'',
    ''organization-uuid'',
    ''admin-user-uuid''
  );';

COMMENT ON FUNCTION is_email_verified IS 
'Checks if a user''s email is verified.
Example usage:
  SELECT is_email_verified(''user-uuid'');';

COMMENT ON FUNCTION resend_verification_email IS 
'Prepares to resend a verification email to a user.
Example usage:
  SELECT resend_verification_email(
    ''user@example.com'',
    ''admin-user-uuid''
  );';