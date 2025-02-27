export interface User {
  id: string;
  email: string;
  first_name?: string;
  last_name?: string;
  role: string;
  organization_id?: string;
  created_at: string;
  updated_at: string;
}

export interface Organization {
  id: string;
  name: string;
  shortname: string;
  created_at: string;
  updated_at: string;
}

export interface Role {
  id: string;
  name: string;
  organization_id?: string;
  is_system_role: boolean;
  permissions: string[];
  created_at: string;
  updated_at: string;
}