import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatTooltipModule } from '@angular/material/tooltip';
import { Router } from '@angular/router';
import { SupabaseService } from '../../services/supabase.service';
import { User } from '../../models/user.model';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    CommonModule,
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatDividerModule,
    MatProgressBarModule,
    MatTooltipModule
  ],
  template: `
    <div class="container">
      <h1 class="page-title">Dashboard</h1>
      
      <div class="dashboard-overview">
        <mat-card class="dashboard-card welcome-card">
          <mat-card-content>
            <div class="welcome-header">
              <div class="welcome-avatar">
                <div class="avatar-text">{{ getUserInitials() }}</div>
              </div>
              <div class="welcome-text">
                <h2>Welcome, {{ user?.first_name || 'User' }}!</h2>
                <div class="role-badge">{{ user?.role | titlecase }}</div>
              </div>
            </div>
            
            <mat-divider></mat-divider>
            
            <div class="user-details">
              <div class="detail-item">
                <mat-icon>email</mat-icon>
                <span>{{ user?.email }}</span>
              </div>
              <div class="detail-item" *ngIf="user?.organization_id">
                <mat-icon>business</mat-icon>
                <span>Organization ID: {{ user?.organization_id }}</span>
              </div>
            </div>
          </mat-card-content>
        </mat-card>
        
        <div class="stats-cards">
          <mat-card class="dashboard-card stat-card">
            <mat-card-content>
              <div class="stat-icon users-icon">
                <mat-icon>people</mat-icon>
              </div>
              <div class="stat-info">
                <h3>Users</h3>
                <p class="stat-value">{{ isSuperAdmin ? '42' : '12' }}</p>
                <mat-progress-bar mode="determinate" value="65"></mat-progress-bar>
              </div>
            </mat-card-content>
          </mat-card>
          
          <mat-card class="dashboard-card stat-card">
            <mat-card-content>
              <div class="stat-icon orgs-icon">
                <mat-icon>business</mat-icon>
              </div>
              <div class="stat-info">
                <h3>Organizations</h3>
                <p class="stat-value">{{ isSuperAdmin ? '8' : '1' }}</p>
                <mat-progress-bar mode="determinate" value="40"></mat-progress-bar>
              </div>
            </mat-card-content>
          </mat-card>
          
          <mat-card class="dashboard-card stat-card">
            <mat-card-content>
              <div class="stat-icon roles-icon">
                <mat-icon>admin_panel_settings</mat-icon>
              </div>
              <div class="stat-info">
                <h3>Roles</h3>
                <p class="stat-value">{{ isSuperAdmin ? '12' : '3' }}</p>
                <mat-progress-bar mode="determinate" value="75"></mat-progress-bar>
              </div>
            </mat-card-content>
          </mat-card>
        </div>
      </div>
      
      <div *ngIf="isSuperAdmin">
        <h2 class="section-title">Super Admin Actions</h2>
        <div class="admin-actions">
          <mat-card class="dashboard-card action-card" (click)="navigateTo('/organizations')">
            <mat-card-content>
              <mat-icon class="action-icon">business</mat-icon>
              <h3>Manage Organizations</h3>
              <p>Create, edit, and manage all organizations</p>
            </mat-card-content>
          </mat-card>
          
          <mat-card class="dashboard-card action-card" (click)="navigateTo('/users')">
            <mat-card-content>
              <mat-icon class="action-icon">people</mat-icon>
              <h3>Manage Users</h3>
              <p>Add, edit, and manage all system users</p>
            </mat-card-content>
          </mat-card>
          
          <mat-card class="dashboard-card action-card" (click)="navigateTo('/roles')">
            <mat-card-content>
              <mat-icon class="action-icon">admin_panel_settings</mat-icon>
              <h3>Manage Roles</h3>
              <p>Configure roles and permissions</p>
            </mat-card-content>
          </mat-card>
          
          <mat-card class="dashboard-card action-card" (click)="syncExternalDatabase()">
            <mat-card-content>
              <mat-icon class="action-icon">sync</mat-icon>
              <h3>Sync External Database</h3>
              <p>Synchronize with external data sources</p>
            </mat-card-content>
          </mat-card>
        </div>
      </div>
      
      <div *ngIf="isOrgAdmin">
        <h2 class="section-title">Organization Admin Actions</h2>
        <div class="admin-actions">
          <mat-card class="dashboard-card action-card" (click)="navigateTo('/org-users')">
            <mat-card-content>
              <mat-icon class="action-icon">people</mat-icon>
              <h3>Manage Organization Users</h3>
              <p>Add, edit, and manage users in your organization</p>
            </mat-card-content>
          </mat-card>
          
          <mat-card class="dashboard-card action-card" (click)="navigateTo('/org-roles')">
            <mat-card-content>
              <mat-icon class="action-icon">admin_panel_settings</mat-icon>
              <h3>Manage Organization Roles</h3>
              <p>Configure roles and permissions for your organization</p>
            </mat-card-content>
          </mat-card>
        </div>
      </div>
      
      <div class="recent-activity">
        <h2 class="section-title">Recent Activity</h2>
        <mat-card>
          <mat-card-content>
            <div class="activity-item">
              <div class="activity-icon">
                <mat-icon>person_add</mat-icon>
              </div>
              <div class="activity-details">
                <p class="activity-text">New user <strong>John Doe</strong> was added to the system</p>
                <p class="activity-time">2 hours ago</p>
              </div>
            </div>
            
            <mat-divider></mat-divider>
            
            <div class="activity-item">
              <div class="activity-icon">
                <mat-icon>edit</mat-icon>
              </div>
              <div class="activity-details">
                <p class="activity-text">Organization <strong>Acme Corp</strong> was updated</p>
                <p class="activity-time">Yesterday</p>
              </div>
            </div>
            
            <mat-divider></mat-divider>
            
            <div class="activity-item">
              <div class="activity-icon">
                <mat-icon>sync</mat-icon>
              </div>
              <div class="activity-details">
                <p class="activity-text">External database synchronization completed</p>
                <p class="activity-time">3 days ago</p>
              </div>
            </div>
          </mat-card-content>
        </mat-card>
      </div>
    </div>
  `,
  styles: [`
    .dashboard-overview {
      display: grid;
      grid-template-columns: 1fr 2fr;
      gap: 24px;
      margin-bottom: 32px;
    }
    
    .welcome-card {
      height: 100%;
    }
    
    .welcome-header {
      display: flex;
      align-items: center;
      margin-bottom: 16px;
    }
    
    .welcome-avatar {
      background-color: var(--secondary-color);
      color: white;
      width: 64px;
      height: 64px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-right: 16px;
      box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
    }
    
    .avatar-text {
      font-size: 24px;
      font-weight: 500;
    }
    
    .welcome-text h2 {
      margin: 0 0 8px;
      font-size: 24px;
      font-weight: 500;
      color: var(--primary-color);
    }
    
    .role-badge {
      display: inline-block;
      background-color: var(--secondary-color);
      color: white;
      padding: 4px 12px;
      border-radius: 16px;
      font-size: 12px;
      text-transform: uppercase;
      margin: 0;
      font-weight: 500;
      letter-spacing: 0.5px;
    }
    
    .user-details {
      margin-top: 16px;
    }
    
    .detail-item {
      display: flex;
      align-items: center;
      margin-bottom: 8px;
    }
    
    .detail-item mat-icon {
      margin-right: 8px;
      color: var(--text-secondary);
    }
    
    .stats-cards {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 16px;
    }
    
    .stat-card {
      transition: transform 0.3s ease, box-shadow 0.3s ease;
    }
    
    .stat-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 16px rgba(0, 0, 0, 0.1) !important;
    }
    
    .stat-icon {
      width: 48px;
      height: 48px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 16px;
    }
    
    .stat-icon mat-icon {
      font-size: 28px;
      width: 28px;
      height: 28px;
      color: white;
    }
    
    .users-icon {
      background-color: var(--secondary-color);
    }
    
    .orgs-icon {
      background-color: var(--warning-color);
    }
    
    .roles-icon {
      background-color: var(--accent-color);
    }
    
    .stat-info h3 {
      margin: 0 0 8px;
      font-size: 16px;
      color: var(--text-secondary);
    }
    
    .stat-value {
      font-size: 28px;
      font-weight: 500;
      margin: 0 0 8px;
      color: var(--primary-color);
    }
    
    .admin-actions {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
      gap: 16px;
      margin-bottom: 32px;
    }
    
    .action-card {
      cursor: pointer;
      transition: all 0.3s ease;
    }
    
    .action-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 16px rgba(0, 0, 0, 0.1) !important;
    }
    
    .action-icon {
      font-size: 36px;
      width: 36px;
      height: 36px;
      color: var(--secondary-color);
      margin-bottom: 16px;
    }
    
    .action-card h3 {
      margin: 0 0 8px;
      font-size: 18px;
      font-weight: 500;
      color: var(--primary-color);
    }
    
    .action-card p {
      margin: 0;
      color: var(--text-secondary);
    }
    
    .recent-activity {
      margin-bottom: 32px;
    }
    
    .activity-item {
      display: flex;
      align-items: center;
      padding: 16px 0;
    }
    
    .activity-icon {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background-color: rgba(0, 0, 0, 0.03);
      display: flex;
      align-items: center;
      justify-content: center;
      margin-right: 16px;
    }
    
    .activity-icon mat-icon {
      color: var(--secondary-color);
    }
    
    .activity-details {
      flex: 1;
    }
    
    .activity-text {
      margin: 0 0 4px;
      color: var(--primary-color);
    }
    
    .activity-time {
      margin: 0;
      font-size: 12px;
      color: var(--text-secondary);
    }
    
    @media (max-width: 992px) {
      .dashboard-overview {
        grid-template-columns: 1fr;
      }
      
      .stats-cards {
        grid-template-columns: repeat(3, 1fr);
      }
    }
    
    @media (max-width: 768px) {
      .stats-cards {
        grid-template-columns: repeat(2, 1fr);
      }
      
      .admin-actions {
        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      }
    }
    
    @media (max-width: 576px) {
      .stats-cards {
        grid-template-columns: 1fr;
      }
    }
  `]
})
export class DashboardComponent implements OnInit {
  user: User | null = null;
  isSuperAdmin = false;
  isOrgAdmin = false;

  constructor(
    private supabaseService: SupabaseService,
    private router: Router
  ) {}

  ngOnInit() {
    this.supabaseService.currentUser$.subscribe(user => {
      this.user = user;
      this.isSuperAdmin = user?.role === 'super_admin';
      this.isOrgAdmin = user?.role === 'org_admin';
    });
  }

  getUserInitials(): string {
    if (!this.user?.first_name && !this.user?.last_name) return 'U';
    return `${this.user.first_name?.charAt(0) || ''}${this.user.last_name?.charAt(0) || ''}`;
  }

  navigateTo(path: string) {
    this.router.navigate([path]);
  }

  async syncExternalDatabase() {
    try {
      await this.supabaseService.syncToExternalDatabase();
      alert('Database synchronization completed successfully');
    } catch (error: any) {
      alert(`Error syncing database: ${error.message}`);
    }
  }

  async logout() {
    try {
      await this.supabaseService.signOut();
      this.router.navigate(['/login']);
    } catch (error: any) {
      alert(`Error logging out: ${error.message}`);
    }
  }
}