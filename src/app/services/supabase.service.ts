import { Injectable } from '@angular/core';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { BehaviorSubject, Observable, from, map, catchError, of } from 'rxjs';
import { environment } from '../../environments/environment';
import { User, Organization } from '../models/user.model';

@Injectable({
  providedIn: 'root'
})
export class SupabaseService {
  public supabase: SupabaseClient;
  private currentUser = new BehaviorSubject<User | null>(null);

  constructor() {
    // Create the Supabase client with custom storage to avoid lock issues
    this.supabase = createClient(
      environment.supabaseUrl,
      environment.supabaseKey,
      {
        auth: {
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: false, // Disable URL detection to avoid issues
          // Use custom storage implementation to avoid lock errors
          storage: {
            getItem: (key) => {
              try {
                return sessionStorage.getItem(key);
              } catch (error) {
                console.error('Storage error:', error);
                return null;
              }
            },
            setItem: (key, value) => {
              try {
                sessionStorage.setItem(key, value);
              } catch (error) {
                console.error('Storage error:', error);
              }
            },
            removeItem: (key) => {
              try {
                sessionStorage.removeItem(key);
              } catch (error) {
                console.error('Storage error:', error);
              }
            }
          },
          // Disable lock acquisition by providing a custom lock function
          lock: async (name, acquireTimeout, fn) => {
            try {
              return await fn();
            } catch (err) {
              console.error('Lock error:', err);
              throw err;
            }
          }
        }
      }
    );
    
    // Try to recover session on init
    this.loadUser();
    
    // Listen for auth changes
    this.supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_IN' && session) {
        this.loadUserProfile(session.user.id);
      } else if (event === 'SIGNED_OUT') {
        this.currentUser.next(null);
      } else if (event === 'PASSWORD_RECOVERY') {
        // Handle password recovery event
        console.log('Password recovery event detected');
      } else if (event === 'USER_UPDATED') {
        // Handle user updated event
        console.log('User updated event detected');
        if (session) {
          this.loadUserProfile(session.user.id);
        }
      }
    });
  }

  get currentUser$(): Observable<User | null> {
    return this.currentUser.asObservable();
  }

  async getCurrentUser(): Promise<User | null> {
    return this.currentUser.getValue();
  }

  async loadUser() {
    try {
      const { data: { session } } = await this.supabase.auth.getSession();
      if (session?.user) {
        await this.loadUserProfile(session.user.id);
      }
    } catch (error) {
      console.error('Error loading user session:', error);
    }
  }

  async loadUserProfile(userId: string) {
    try {
      const { data, error } = await this.supabase
        .from('users')
        .select('*')
        .eq('id', userId)
        .single();
      
      if (error) {
        console.error('Error loading user profile:', error);
        return;
      }
      
      this.currentUser.next(data as User);
    } catch (error) {
      console.error('Error loading user profile:', error);
    }
  }

  async signIn(email: string, password: string) {
    const { data, error } = await this.supabase.auth.signInWithPassword({
      email,
      password
    });
    
    if (error) {
      throw error;
    }
    
    return data;
  }

  async signOut() {
    const { error } = await this.supabase.auth.signOut();
    if (error) {
      throw error;
    }
    this.currentUser.next(null);
  }

  // Check if a super admin exists in the system using the security definer function
  checkIfSuperAdminExists(): Observable<boolean> {
    return from(this.supabase
      .rpc('check_super_admin_exists')
    ).pipe(
      map(response => {
        if (response.error) {
          throw response.error;
        }
        return !!response.data;
      }),
      catchError(error => {
        console.error('Error checking if super admin exists:', error);
        return of(false);
      })
    );
  }

  // Create initial admin user and organization in one transaction
  async createInitialAdminUser(
    email: string, 
    password: string, 
    firstName: string, 
    lastName: string, 
    organizationId: string
  ) {
    // 1. Create the auth user with email confirmation disabled
    const { data: authData, error: authError } = await this.supabase.auth.signUp({
      email,
      password
    });
    
    if (authError) {
      throw authError;
    }
    
    if (!authData.user) {
      throw new Error('Failed to create user');
    }
    
    // 2. Create the user profile with super_admin role
    const { error } = await this.supabase
      .from('users')
      .insert([{
        id: authData.user.id,
        email,
        first_name: firstName,
        last_name: lastName,
        role: 'super_admin',
        organization_id: organizationId
      }]);
    
    if (error) {
      throw error;
    }
    
    return authData.user;
  }

  // Create initial setup using the security definer function
  async createInitialSetup(
    orgName: string,
    orgShortName: string,
    email: string,
    password: string,
    firstName: string,
    lastName: string
  ) {
    // 1. Create the auth user first with email confirmation disabled
    const { data: authData, error: authError } = await this.supabase.auth.signUp({
      email,
      password
    });
    
    if (authError) {
      throw authError;
    }
    
    if (!authData.user) {
      throw new Error('Failed to create user');
    }
    
    // 2. Use the security definer function to create organization and user
    const { data, error } = await this.supabase.rpc(
      'create_initial_setup',
      {
        org_name: orgName,
        org_shortname: orgShortName,
        user_email: email,
        user_first_name: firstName,
        user_last_name: lastName,
        user_id: authData.user.id
      }
    );
    
    if (error) {
      throw error;
    }
    
    return { user: authData.user, setup: data };
  }

  // Admin functions - only available to super admins
  async createOrganization(name: string, shortname: string) {
    const { data, error } = await this.supabase
      .from('organizations')
      .insert([{ name, shortname }])
      .select()
      .single();
    
    if (error) {
      throw error;
    }
    
    return data;
  }

  async createUser(email: string, password: string, firstName: string, lastName: string, 
                  organizationId: string, role: string) {
    // First create the auth user with email confirmation disabled
    const { data: authData, error: authError } = await this.supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // Auto-confirm email for simplicity
      user_metadata: {
        first_name: firstName,
        last_name: lastName
      }
    });
    
    if (authError) {
      throw authError;
    }
    
    // Then create the user profile
    const { data, error } = await this.supabase
      .from('users')
      .insert([{
        id: authData.user.id,
        email,
        first_name: firstName,
        last_name: lastName,
        organization_id: organizationId,
        role
      }])
      .select()
      .single();
    
    if (error) {
      throw error;
    }
    
    return data;
  }

  // Invite a user without setting a password (they'll set it via email)
  async inviteUser(email: string, firstName: string, lastName: string, 
                  organizationId: string, role: string) {
    // Generate a random temporary password
    const tempPassword = Math.random().toString(36).slice(-10);
    
    // Create the auth user with email confirmation enabled
    const { data: authData, error: authError } = await this.supabase.auth.signUp({
      email,
      password: tempPassword,
      options: {
        emailRedirectTo: `${window.location.origin}/reset-password?type=signup`
      }
    });
    
    if (authError) {
      throw authError;
    }
    
    if (!authData.user) {
      throw new Error('Failed to create user');
    }
    
    // Create the user profile
    const { data, error } = await this.supabase
      .from('users')
      .insert([{
        id: authData.user.id,
        email,
        first_name: firstName,
        last_name: lastName,
        organization_id: organizationId,
        role
      }])
      .select()
      .single();
    
    if (error) {
      throw error;
    }
    
    return data;
  }

  // Send email verification to a user
  async sendEmailVerification(email: string) {
    const { error } = await this.supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`
    });
    
    if (error) {
      throw error;
    }
    
    return true;
  }

  // Update user password (used in reset password flow)
  async updatePassword(newPassword: string) {
    const { error } = await this.supabase.auth.updateUser({
      password: newPassword
    });
    
    if (error) {
      throw error;
    }
    
    return true;
  }

  async createRole(name: string, organizationId: string, permissions: string[]) {
    const { data, error } = await this.supabase
      .from('roles')
      .insert([{
        name,
        organization_id: organizationId,
        is_system_role: false,
        permissions
      }])
      .select()
      .single();
    
    if (error) {
      throw error;
    }
    
    return data;
  }

  async impersonateUser(userId: string) {
    // This would require a custom server-side function in Supabase
    const { data, error } = await this.supabase.functions.invoke('impersonate-user', {
      body: { user_id: userId }
    });
    
    if (error) {
      throw error;
    }
    
    // Update the session with the impersonated user's token
    await this.supabase.auth.setSession({
      access_token: data.access_token,
      refresh_token: data.refresh_token
    });
    
    await this.loadUserProfile(userId);
    
    return data;
  }

  async getOrganizations() {
    const { data, error } = await this.supabase
      .from('organizations')
      .select('*');
    
    if (error) {
      throw error;
    }
    
    return data;
  }

  async getUsersByOrganization(organizationId: string) {
    const { data, error } = await this.supabase
      .from('users')
      .select('*')
      .eq('organization_id', organizationId);
    
    if (error) {
      throw error;
    }
    
    return data;
  }

  async syncToExternalDatabase() {
    // This would require a custom server-side function in Supabase
    const { data, error } = await this.supabase.functions.invoke('sync-external-db');
    
    if (error) {
      throw error;
    }
    
    return data;
  }
}