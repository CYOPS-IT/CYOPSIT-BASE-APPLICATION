import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatTableModule } from '@angular/material/table';
import { MatIconModule } from '@angular/material/icon';
import { MatDialogModule, MatDialog } from '@angular/material/dialog';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { SupabaseService } from '../../services/supabase.service';
import { Organization } from '../../models/user.model';

@Component({
  selector: 'app-organizations',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatTableModule,
    MatIconModule,
    MatDialogModule,
    MatSnackBarModule
  ],
  template: `
    <div class="container">
      <h1>Manage Organizations</h1>
      
      <mat-card>
        <mat-card-header>
          <mat-card-title>Create New Organization</mat-card-title>
        </mat-card-header>
        <mat-card-content>
          <form [formGroup]="orgForm" (ngSubmit)="createOrganization()">
            <mat-form-field class="full-width">
              <mat-label>Organization Name</mat-label>
              <input matInput formControlName="name" required>
              <mat-error *ngIf="orgForm.get('name')?.hasError('required')">
                Name is required
              </mat-error>
            </mat-form-field>
            
            <mat-form-field class="full-width">
              <mat-label>Short Name (for role identification)</mat-label>
              <input matInput formControlName="shortname" required>
              <mat-error *ngIf="orgForm.get('shortname')?.hasError('required')">
                Short name is required
              </mat-error>
              <mat-error *ngIf="orgForm.get('shortname')?.hasError('pattern')">
                Short name must contain only lowercase letters, numbers, and hyphens
              </mat-error>
            </mat-form-field>
            
            <button 
              mat-raised-button 
              color="primary" 
              type="submit" 
              [disabled]="orgForm.invalid || isLoading">
              Create Organization
            </button>
          </form>
        </mat-card-content>
      </mat-card>
      
      <h2>Organizations</h2>
      <table mat-table [dataSource]="organizations" class="full-width">
        <ng-container matColumnDef="name">
          <th mat-header-cell *matHeaderCellDef>Name</th>
          <td mat-cell *matCellDef="let org">{{ org.name }}</td>
        </ng-container>
        
        <ng-container matColumnDef="shortname">
          <th mat-header-cell *matHeaderCellDef>Short Name</th>
          <td mat-cell *matCellDef="let org">{{ org.shortname }}</td>
        </ng-container>
        
        <ng-container matColumnDef="created_at">
          <th mat-header-cell *matHeaderCellDef>Created</th>
          <td mat-cell *matCellDef="let org">{{ org.created_at | date }}</td>
        </ng-container>
        
        <ng-container matColumnDef="actions">
          <th mat-header-cell *matHeaderCellDef>Actions</th>
          <td mat-cell *matCellDef="let org">
            <button mat-icon-button color="primary" (click)="viewUsers(org)">
              <mat-icon>people</mat-icon>
            </button>
            <button mat-icon-button color="accent" (click)="addUser(org)">
              <mat-icon>person_add</mat-icon>
            </button>
          </td>
        </ng-container>
        
        <tr mat-header-row *matHeaderRowDef="displayedColumns"></tr>
        <tr mat-row *matRowDef="let row; columns: displayedColumns;"></tr>
      </table>
    </div>
  `,
  styles: [`
    .container {
      padding: 20px;
    }
    
    .full-width {
      width: 100%;
      margin-bottom: 15px;
    }
    
    mat-card {
      margin-bottom: 20px;
    }
  `]
})
export class OrganizationsComponent implements OnInit {
  orgForm: FormGroup;
  organizations: Organization[] = [];
  isLoading = false;
  displayedColumns: string[] = ['name', 'shortname', 'created_at', 'actions'];

  constructor(
    private fb: FormBuilder,
    private supabaseService: SupabaseService,
    private dialog: MatDialog,
    private snackBar: MatSnackBar
  ) {
    this.orgForm = this.fb.group({
      name: ['', Validators.required],
      shortname: ['', [Validators.required, Validators.pattern('^[a-z0-9-]+$')]]
    });
  }

  ngOnInit() {
    this.loadOrganizations();
  }

  async loadOrganizations() {
    try {
      this.organizations = await this.supabaseService.getOrganizations();
    } catch (error: any) {
      this.snackBar.open(`Error loading organizations: ${error.message}`, 'Close', {
        duration: 5000
      });
    }
  }

  async createOrganization() {
    if (this.orgForm.invalid) {
      return;
    }
    
    this.isLoading = true;
    
    try {
      const { name, shortname } = this.orgForm.value;
      await this.supabaseService.createOrganization(name, shortname);
      this.orgForm.reset();
      await this.loadOrganizations();
      this.snackBar.open('Organization created successfully', 'Close', {
        duration: 3000
      });
    } catch (error: any) {
      this.snackBar.open(`Error creating organization: ${error.message}`, 'Close', {
        duration: 5000
      });
    } finally {
      this.isLoading = false;
    }
  }

  viewUsers(org: Organization) {
    // This would navigate to a users view filtered by organization
    // or open a dialog showing users in this organization
    this.snackBar.open(`Viewing users for ${org.name}`, 'Close', {
      duration: 3000
    });
  }

  addUser(org: Organization) {
    // Open a dialog to add a user
    this.snackBar.open(`This feature will be implemented soon. You'll be able to invite users to ${org.name}.`, 'Close', {
      duration: 5000
    });
    
    // In the future, we'll implement a dialog for inviting users
    // For now, we'll just show a message
  }
}