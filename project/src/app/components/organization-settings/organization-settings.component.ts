import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { SupabaseService } from '../../services/supabase.service';
import { AppSettingsService } from '../../services/app-settings.service';
import { User } from '../../models/user.model';

@Component({
  selector: 'app-organization-settings',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatSnackBarModule,
    MatProgressSpinnerModule,
    MatIconModule,
    MatDividerModule
  ],
  template: `
    <div class="container">
      <h1 class="page-title">Organization Settings</h1>
      
      <mat-card>
        <mat-card-header>
          <mat-card-title>Application Branding</mat-card-title>
          <mat-card-subtitle>Customize how the application appears to your users</mat-card-subtitle>
        </mat-card-header>
        
        <mat-divider></mat-divider>
        
        <mat-card-content>
          <form [formGroup]="brandingForm" (ngSubmit)="updateAppName()">
            <mat-form-field appearance="outline" class="full-width">
              <mat-label>Application Name</mat-label>
              <input matInput formControlName="appName" required>
              <mat-icon matSuffix>business</mat-icon>
              <mat-hint>This name will appear in the header and browser title</mat-hint>
              <mat-error *ngIf="brandingForm.get('appName')?.hasError('required')">
                Application name is required
              </mat-error>
              <mat-error *ngIf="brandingForm.get('appName')?.hasError('minlength')">
                Application name must be at least 3 characters
              </mat-error>
              <mat-error *ngIf="brandingForm.get('appName')?.hasError('maxlength')">
                Application name must be at most 50 characters
              </mat-error>
            </mat-form-field>
            
            <div *ngIf="errorMessage" class="error-message">
              <mat-icon>error</mat-icon> {{ errorMessage }}
            </div>
            
            <div *ngIf="successMessage" class="success-message">
              <mat-icon>check_circle</mat-icon> {{ successMessage }}
            </div>
            
            <div class="form-actions">
              <button 
                mat-raised-button 
                color="primary" 
                type="submit" 
                [disabled]="brandingForm.invalid || isLoading">
                <mat-spinner *ngIf="isLoading" diameter="20"></mat-spinner>
                <span *ngIf="!isLoading">Update Application Name</span>
              </button>
            </div>
          </form>
        </mat-card-content>
      </mat-card>
      
      <mat-card *ngIf="isSuperAdmin">
        <mat-card-header>
          <mat-card-title>Global Application Settings</mat-card-title>
          <mat-card-subtitle>These settings apply to all organizations</mat-card-subtitle>
        </mat-card-header>
        
        <mat-divider></mat-divider>
        
        <mat-card-content>
          <form [formGroup]="globalSettingsForm" (ngSubmit)="updateGlobalAppName()">
            <mat-form-field appearance="outline" class="full-width">
              <mat-label>Default Application Name</mat-label>
              <input matInput formControlName="globalAppName" required>
              <mat-icon matSuffix>public</mat-icon>
              <mat-hint>This name will be used for organizations that haven't set a custom name</mat-hint>
              <mat-error *ngIf="globalSettingsForm.get('globalAppName')?.hasError('required')">
                Default application name is required
              </mat-error>
            </mat-form-field>
            
            <div *ngIf="globalErrorMessage" class="error-message">
              <mat-icon>error</mat-icon> {{ globalErrorMessage }}
            </div>
            
            <div *ngIf="globalSuccessMessage" class="success-message">
              <mat-icon>check_circle</mat-icon> {{ globalSuccessMessage }}
            </div>
            
            <div class="form-actions">
              <button 
                mat-raised-button 
                color="primary" 
                type="submit" 
                [disabled]="globalSettingsForm.invalid || isGlobalLoading">
                <mat-spinner *ngIf="isGlobalLoading" diameter="20"></mat-spinner>
                <span *ngIf="!isGlobalLoading">Update Default Application Name</span>
              </button>
            </div>
          </form>
        </mat-card-content>
      </mat-card>
    </div>
  `,
  styles: [`
    .form-actions {
      display: flex;
      justify-content: flex-end;
      margin-top: 16px;
    }
    
    .error-message {
      display: flex;
      align-items: center;
      gap: 8px;
      color: var(--warning-color);
      margin: 16px 0;
      padding: 8px 16px;
      background-color: rgba(231, 76, 60, 0.1);
      border-radius: var(--border-radius);
    }
    
    .success-message {
      display: flex;
      align-items: center;
      gap: 8px;
      color: var(--accent-color);
      margin: 16px 0;
      padding: 8px 16px;
      background-color: rgba(26, 188, 156, 0.1);
      border-radius: var(--border-radius);
    }
    
    mat-card {
      margin-bottom: 24px;
    }
  `]
})
export class OrganizationSettingsComponent implements OnInit {
  brandingForm: FormGroup;
  globalSettingsForm: FormGroup;
  isLoading = false;
  isGlobalLoading = false;
  errorMessage = '';
  successMessage = '';
  globalErrorMessage = '';
  globalSuccessMessage = '';
  isSuperAdmin = false;
  currentUser: User | null = null;

  constructor(
    private fb: FormBuilder,
    private supabaseService: SupabaseService,
    private appSettingsService: AppSettingsService,
    private snackBar: MatSnackBar
  ) {
    this.brandingForm = this.fb.group({
      appName: ['', [Validators.required, Validators.minLength(3), Validators.maxLength(50)]]
    });
    
    this.globalSettingsForm = this.fb.group({
      globalAppName: ['', [Validators.required, Validators.minLength(3), Validators.maxLength(50)]]
    });
  }

  ngOnInit() {
    // Load current user and check if super admin
    this.supabaseService.currentUser$.subscribe(user => {
      this.currentUser = user;
      this.isSuperAdmin = user?.role === 'super_admin';
    });
    
    // Load current app name
    this.appSettingsService.appName$.subscribe(appName => {
      this.brandingForm.patchValue({ appName });
      this.globalSettingsForm.patchValue({ globalAppName: appName });
    });
    
    // Load global app name for super admins
    if (this.isSuperAdmin) {
      this.loadGlobalAppName();
    }
  }

  async loadGlobalAppName() {
    try {
      const { data, error } = await this.supabaseService.supabase
        .from('app_settings')
        .select('value')
        .eq('key', 'app_name')
        .is('organization_id', null)
        .maybeSingle();
      
      if (!error && data) {
        this.globalSettingsForm.patchValue({ globalAppName: data.value });
      }
    } catch (error) {
      console.error('Error loading global app name:', error);
    }
  }

  async updateAppName() {
    if (this.brandingForm.invalid) {
      return;
    }
    
    this.isLoading = true;
    this.errorMessage = '';
    this.successMessage = '';
    
    try {
      const { appName } = this.brandingForm.value;
      
      if (!this.currentUser?.organization_id) {
        throw new Error('No organization ID found for current user');
      }
      
      const success = await this.appSettingsService.updateAppName(
        appName, 
        this.currentUser.organization_id
      );
      
      if (success) {
        this.successMessage = 'Application name updated successfully';
      } else {
        this.errorMessage = 'Failed to update application name';
      }
    } catch (error: any) {
      console.error('Error updating app name:', error);
      this.errorMessage = error.message || 'An error occurred while updating the application name';
    } finally {
      this.isLoading = false;
    }
  }

  async updateGlobalAppName() {
    if (this.globalSettingsForm.invalid || !this.isSuperAdmin) {
      return;
    }
    
    this.isGlobalLoading = true;
    this.globalErrorMessage = '';
    this.globalSuccessMessage = '';
    
    try {
      const { globalAppName } = this.globalSettingsForm.value;
      
      const success = await this.appSettingsService.updateAppName(globalAppName);
      
      if (success) {
        this.globalSuccessMessage = 'Default application name updated successfully';
      } else {
        this.globalErrorMessage = 'Failed to update default application name';
      }
    } catch (error: any) {
      console.error('Error updating global app name:', error);
      this.globalErrorMessage = error.message || 'An error occurred while updating the default application name';
    } finally {
      this.isGlobalLoading = false;
    }
  }
}