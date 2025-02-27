import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable, from, map, catchError, of } from 'rxjs';
import { SupabaseService } from './supabase.service';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class AppSettingsService {
  private appName = new BehaviorSubject<string>('Admin Portal');
  
  constructor(private supabaseService: SupabaseService) {
    // Load app name from environment variable as default
    const defaultAppName = environment.appName || 'Admin Portal';
    this.appName.next(defaultAppName);
    
    // Subscribe to user changes to load organization-specific settings
    this.supabaseService.currentUser$.subscribe(user => {
      if (user) {
        this.loadAppName(user.organization_id);
      } else {
        // Reset to default when logged out
        this.appName.next(defaultAppName);
      }
    });
  }

  get appName$(): Observable<string> {
    return this.appName.asObservable();
  }

  async loadAppName(organizationId?: string): Promise<void> {
    try {
      // First try to get organization-specific setting
      if (organizationId) {
        const { data: orgData, error: orgError } = await this.supabaseService.supabase
          .from('app_settings')
          .select('value')
          .eq('key', 'app_name')
          .eq('organization_id', organizationId)
          .maybeSingle();
        
        if (!orgError && orgData) {
          this.appName.next(orgData.value);
          return;
        }
      }
      
      // If no org-specific setting, get global setting
      const { data, error } = await this.supabaseService.supabase
        .from('app_settings')
        .select('value')
        .eq('key', 'app_name')
        .is('organization_id', null)
        .maybeSingle();
      
      if (!error && data) {
        this.appName.next(data.value);
      } else {
        // Fallback to environment variable
        const defaultAppName = environment.appName || 'Admin Portal';
        this.appName.next(defaultAppName);
      }
    } catch (error) {
      console.error('Error loading app name:', error);
      // Fallback to environment variable
      const defaultAppName = environment.appName || 'Admin Portal';
      this.appName.next(defaultAppName);
    }
  }

  async updateAppName(newName: string, organizationId?: string): Promise<boolean> {
    try {
      if (organizationId) {
        // Update organization-specific setting
        const { data, error } = await this.supabaseService.supabase
          .from('app_settings')
          .upsert({
            key: 'app_name',
            value: newName,
            organization_id: organizationId
          });
        
        if (error) throw error;
        
        // Update the local value
        this.appName.next(newName);
        return true;
      } else {
        // Only super admins can update global settings
        const currentUser = await this.supabaseService.getCurrentUser();
        if (currentUser?.role !== 'super_admin') {
          throw new Error('Only super admins can update global settings');
        }
        
        // Update global setting
        const { data, error } = await this.supabaseService.supabase
          .from('app_settings')
          .upsert({
            key: 'app_name',
            value: newName,
            organization_id: null
          });
        
        if (error) throw error;
        
        // Update the local value
        this.appName.next(newName);
        return true;
      }
    } catch (error) {
      console.error('Error updating app name:', error);
      return false;
    }
  }
}