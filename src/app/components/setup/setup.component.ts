import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { SupabaseService } from '../../services/supabase.service';

@Component({
  selector: 'app-setup',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatProgressSpinnerModule,
    MatSnackBarModule
  ],
  template: `
    <div class="setup-container">
      <mat-card>
        <mat-card-header>
          <mat-card-title>Initial Setup</mat-card-title>
          <mat-card-subtitle>Create your first admin user and organization</mat-card-subtitle>
        </mat-card-header>
        <mat-card-content>
          <div *ngIf="setupNeeded; else alreadySetup">
            <form [formGroup]="setupForm" (ngSubmit)="onSubmit()">
              <h3>Organization Details</h3>
              <mat-form-field class="full-width">
                <mat-label>Organization Name</mat-label>
                <input matInput formControlName="orgName" required>
                <mat-error *ngIf="setupForm.get('orgName')?.hasError('required')">
                  Organization name is required
                </mat-error>
              </mat-form-field>
              
              <mat-form-field class="full-width">
                <mat-label>Organization Short Name</mat-label>
                <input matInput formControlName="orgShortName" required>
                <mat-hint>Used for role identification (lowercase letters, numbers, and hyphens only)</mat-hint>
                <mat-error *ngIf="setupForm.get('orgShortName')?.hasError('required')">
                  Short name is required
                </mat-error>
                <mat-error *ngIf="setupForm.get('orgShortName')?.hasError('pattern')">
                  Short name must contain only lowercase letters, numbers, and hyphens
                </mat-error>
              </mat-form-field>
              
              <h3>Admin User Details</h3>
              <mat-form-field class="full-width">
                <mat-label>First Name</mat-label>
                <input matInput formControlName="firstName" required>
                <mat-error *ngIf="setupForm.get('firstName')?.hasError('required')">
                  First name is required
                </mat-error>
              </mat-form-field>
              
              <mat-form-field class="full-width">
                <mat-label>Last Name</mat-label>
                <input matInput formControlName="lastName" required>
                <mat-error *ngIf="setupForm.get('lastName')?.hasError('required')">
                  Last name is required
                </mat-error>
              </mat-form-field>
              
              <mat-form-field class="full-width">
                <mat-label>Email</mat-label>
                <input matInput formControlName="email" type="email" required>
                <mat-error *ngIf="setupForm.get('email')?.hasError('required')">
                  Email is required
                </mat-error>
                <mat-error *ngIf="setupForm.get('email')?.hasError('email')">
                  Please enter a valid email address
                </mat-error>
              </mat-form-field>
              
              <mat-form-field class="full-width">
                <mat-label>Password</mat-label>
                <input matInput formControlName="password" type="password" required>
                <mat-error *ngIf="setupForm.get('password')?.hasError('required')">
                  Password is required
                </mat-error>
                <mat-error *ngIf="setupForm.get('password')?.hasError('minlength')">
                  Password must be at least 8 characters
                </mat-error>
              </mat-form-field>
              
              <div *ngIf="errorMessage" class="error-message">
                {{ errorMessage }}
              </div>
              
              <button 
                mat-raised-button 
                color="primary" 
                type="submit" 
                [disabled]="setupForm.invalid || isLoading"
                class="full-width">
                <mat-spinner *ngIf="isLoading" diameter="20"></mat-spinner>
                <span *ngIf="!isLoading">Create Admin & Organization</span>
              </button>
            </form>
          </div>
          
          <ng-template #alreadySetup>
            <div class="already-setup">
              <h3>System Already Set Up</h3>
              <p>An admin user already exists in the system.</p>
              <button mat-raised-button color="primary" (click)="goToLogin()">
                Go to Login
              </button>
            </div>
          </ng-template>
        </mat-card-content>
      </mat-card>
    </div>
  `,
  styles: [`
    .setup-container {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      padding: 20px;
      background-color: #f5f5f5;
    }
    
    mat-card {
      max-width: 600px;
      width: 100%;
      padding: 20px;
    }
    
    .full-width {
      width: 100%;
      margin-bottom: 15px;
    }
    
    .error-message {
      color: red;
      margin-bottom:  15px;
    }
    
    h3 {
      margin-top: 20px;
      margin-bottom: 10px;
      color: #3f51b5;
    }
    
    .already-setup {
      text-align: center;
      padding: 20px;
    }
  `]
})
export class SetupComponent implements OnInit {
  setupForm: FormGroup;
  isLoading = false;
  errorMessage = '';
  setupNeeded = true;

  constructor(
    private fb: FormBuilder,
    private supabaseService: SupabaseService,
    private router: Router,
    private snackBar: MatSnackBar
  ) {
    this.setupForm = this.fb.group({
      orgName: ['', Validators.required],
      orgShortName: ['', [Validators.required, Validators.pattern('^[a-z0-9-]+$')]],
      firstName: ['', Validators.required],
      lastName: ['', Validators.required],
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, Validators.minLength(8)]]
    });
  }

  ngOnInit() {
    this.checkIfSetupNeeded();
  }

  async checkIfSetupNeeded() {
    try {
      this.supabaseService.checkIfSuperAdminExists().subscribe(exists => {
        this.setupNeeded = !exists;
        if (exists) {
          this.snackBar.open('System is already set up. Redirecting to login...', 'Close', {
            duration: 3000
          });
          setTimeout(() => this.goToLogin(), 3000);
        }
      });
    } catch (error) {
      console.error('Error checking if setup is needed:', error);
      // If there's an error, assume setup is needed
      this.setupNeeded = true;
    }
  }

  goToLogin() {
    this.router.navigate(['/login']);
  }

  async onSubmit() {
    if (this.setupForm.invalid) {
      return;
    }
    
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      const { orgName, orgShortName, firstName, lastName, email, password } = this.setupForm.value;
      
      // Use the new createInitialSetup method that uses a security definer function
      const result = await this.supabaseService.createInitialSetup(
        orgName, 
        orgShortName, 
        email, 
        password, 
        firstName, 
        lastName
      );
      
      console.log('Setup completed:', result);
      
      this.snackBar.open('Setup completed successfully! Please check your email to verify your account before signing in.', 'Close', {
        duration: 8000
      });
      
      // Navigate to login page
      this.router.navigate(['/login']);
    } catch (error: any) {
      console.error('Setup error:', error);
      this.errorMessage = error.message || 'An error occurred during setup';
    } finally {
      this.isLoading = false;
    }
  }
}