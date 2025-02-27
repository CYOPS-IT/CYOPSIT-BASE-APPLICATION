import { Component, Inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { MatDialogRef, MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatSelectModule } from '@angular/material/select';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { SupabaseService } from '../../services/supabase.service';
import { Organization } from '../../models/user.model';

@Component({
  selector: 'app-invite-user-dialog',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatSelectModule,
    MatProgressSpinnerModule
  ],
  template: `
    <h2 mat-dialog-title>Invite User to {{ data.organization.name }}</h2>
    <div mat-dialog-content>
      <form [formGroup]="inviteForm">
        <mat-form-field class="full-width">
          <mat-label>Email</mat-label>
          <input matInput formControlName="email" type="email" required>
          <mat-error *ngIf="inviteForm.get('email')?.hasError('required')">
            Email is required
          </mat-error>
          <mat-error *ngIf="inviteForm.get('email')?.hasError('email')">
            Please enter a valid email address
          </mat-error>
        </mat-form-field>
        
        <mat-form-field class="full-width">
          <mat-label>First Name</mat-label>
          <input matInput formControlName="firstName" required>
          <mat-error *ngIf="inviteForm.get('firstName')?.hasError('required')">
            First name is required
          </mat-error>
        </mat-form-field>
        
        <mat-form-field class="full-width">
          <mat-label>Last Name</mat-label>
          <input matInput formControlName="lastName" required>
          <mat-error *ngIf="inviteForm.get('lastName')?.hasError('required')">
            Last name is required
          </mat-error>
        </mat-form-field>
        
        <mat-form-field class="full-width">
          <mat-label>Role</mat-label>
          <mat-select formControlName="role" required>
            <mat-option value="user">User</mat-option>
            <mat-option value="org_admin">Organization Admin</mat-option>
          </mat-select>
          <mat-error *ngIf="inviteForm.get('role')?.hasError('required')">
            Role is required
          </mat-error>
        </mat-form-field>
        
        <div *ngIf="errorMessage" class="error-message">
          {{ errorMessage }}
        </div>
      </form>
    </div>
    <div mat-dialog-actions align="end">
      <button mat-button (click)="onCancel()">Cancel</button>
      <button 
        mat-raised-button 
        color="primary" 
        [disabled]="inviteForm.invalid || isLoading"
        (click)="onSubmit()">
        <mat-spinner *ngIf="isLoading" diameter="20"></mat-spinner>
        <span *ngIf="!isLoading">Invite User</span>
      </button>
    </div>
  `,
  styles: [`
    .full-width {
      width: 100%;
      margin-bottom: 15px;
    }
    
    .error-message {
      color: red;
      margin-bottom: 15px;
    }
  `]
})
export class InviteUserDialogComponent {
  inviteForm: FormGroup;
  isLoading = false;
  errorMessage = '';

  constructor(
    private fb: FormBuilder,
    private supabaseService: SupabaseService,
    public dialogRef: MatDialogRef<InviteUserDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: { organization: Organization }
  ) {
    this.inviteForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      firstName: ['', Validators.required],
      lastName: ['', Validators.required],
      role: ['user', Validators.required]
    });
  }

  onCancel(): void {
    this.dialogRef.close();
  }

  async onSubmit(): void {
    if (this.inviteForm.invalid) {
      return;
    }
    
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      const { email, firstName, lastName, role } = this.inviteForm.value;
      
      // Invite the user without setting a password
      // They will receive an email to set their own password
      const result = await this.supabaseService.inviteUser(
        email,
        firstName,
        lastName,
        this.data.organization.id,
        role
      );
      
      this.dialogRef.close(result);
    } catch (error: any) {
      console.error('Error inviting user:', error);
      this.errorMessage = error.message || 'An error occurred while inviting the user';
    } finally {
      this.isLoading = false;
    }
  }
}