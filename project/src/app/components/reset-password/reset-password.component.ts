import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { SupabaseService } from '../../services/supabase.service';

@Component({
  selector: 'app-reset-password',
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
    <div class="reset-container">
      <mat-card>
        <mat-card-header>
          <mat-card-title>{{ isNewUser ? 'Set Your Password' : 'Reset Your Password' }}</mat-card-title>
          <mat-card-subtitle>
            {{ isNewUser ? 'Create a new password for your account' : 'Enter a new password for your account' }}
          </mat-card-subtitle>
        </mat-card-header>
        <mat-card-content>
          <form [formGroup]="resetForm" (ngSubmit)="onSubmit()">
            <mat-form-field class="full-width">
              <mat-label>New Password</mat-label>
              <input matInput formControlName="password" type="password" required>
              <mat-error *ngIf="resetForm.get('password')?.hasError('required')">
                Password is required
              </mat-error>
              <mat-error *ngIf="resetForm.get('password')?.hasError('minlength')">
                Password must be at least 8 characters
              </mat-error>
            </mat-form-field>
            
            <mat-form-field class="full-width">
              <mat-label>Confirm Password</mat-label>
              <input matInput formControlName="confirmPassword" type="password" required>
              <mat-error *ngIf="resetForm.get('confirmPassword')?.hasError('required')">
                Please confirm your password
              </mat-error>
              <mat-error *ngIf="resetForm.get('confirmPassword')?.hasError('passwordMismatch')">
                Passwords do not match
              </mat-error>
            </mat-form-field>
            
            <div *ngIf="errorMessage" class="error-message">
              {{ errorMessage }}
            </div>
            
            <button 
              mat-raised-button 
              color="primary" 
              type="submit" 
              [disabled]="resetForm.invalid || isLoading"
              class="full-width">
              <mat-spinner *ngIf="isLoading" diameter="20"></mat-spinner>
              <span *ngIf="!isLoading">{{ isNewUser ? 'Set Password' : 'Reset Password' }}</span>
            </button>
            
            <div class="login-link">
              <button mat-button color="primary" (click)="goToLogin()">
                Back to Login
              </button>
            </div>
          </form>
        </mat-card-content>
      </mat-card>
    </div>
  `,
  styles: [`
    .reset-container {
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      background-color: #f5f5f5;
    }
    
    mat-card {
      max-width: 400px;
      width: 100%;
      padding: 20px;
    }
    
    .full-width {
      width: 100%;
      margin-bottom: 15px;
    }
    
    .error-message {
      color: red;
      margin-bottom: 15px;
    }
    
    .login-link {
      margin-top: 15px;
      text-align: center;
    }
  `]
})
export class ResetPasswordComponent implements OnInit {
  resetForm: FormGroup;
  isLoading = false;
  errorMessage = '';
  isNewUser = false;

  constructor(
    private fb: FormBuilder,
    private supabaseService: SupabaseService,
    private router: Router,
    private route: ActivatedRoute,
    private snackBar: MatSnackBar
  ) {
    this.resetForm = this.fb.group({
      password: ['', [Validators.required, Validators.minLength(8)]],
      confirmPassword: ['', Validators.required]
    }, { validators: this.passwordMatchValidator });
  }

  ngOnInit() {
    // Check if this is a new user or password reset
    this.route.queryParams.subscribe(params => {
      // If type=signup is in the URL, it's a new user setting their password
      this.isNewUser = params['type'] === 'signup';
    });
  }

  passwordMatchValidator(form: FormGroup) {
    const password = form.get('password')?.value;
    const confirmPassword = form.get('confirmPassword')?.value;
    
    if (password !== confirmPassword) {
      form.get('confirmPassword')?.setErrors({ passwordMismatch: true });
      return { passwordMismatch: true };
    }
    
    return null;
  }

  goToLogin() {
    this.router.navigate(['/login']);
  }

  async onSubmit() {
    if (this.resetForm.invalid) {
      return;
    }
    
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      const { password } = this.resetForm.value;
      
      // Update the user's password
      await this.supabaseService.updatePassword(password);
      
      this.snackBar.open(
        this.isNewUser ? 
          'Password set successfully! You can now log in.' : 
          'Password reset successfully! You can now log in with your new password.',
        'Close',
        { duration: 5000 }
      );
      
      // Navigate to login page
      this.router.navigate(['/login']);
    } catch (error: any) {
      console.error('Password reset error:', error);
      this.errorMessage = error.message || 'An error occurred during password reset';
    } finally {
      this.isLoading = false;
    }
  }
}