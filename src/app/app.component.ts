import { Component } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatListModule } from '@angular/material/list';
import { CommonModule } from '@angular/common';
import { SupabaseService } from './services/supabase.service';
import { AppSettingsService } from './services/app-settings.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    MatToolbarModule,
    MatButtonModule,
    MatIconModule,
    MatMenuModule,
    MatSidenavModule,
    MatListModule,
    CommonModule
  ],
  template: `
    <div class="app-container" *ngIf="(supabaseService.currentUser$ | async) as user; else loginTemplate">
      <mat-toolbar color="primary" class="app-toolbar">
        <button mat-icon-button (click)="drawer.toggle()" class="menu-button">
          <mat-icon>menu</mat-icon>
        </button>
        <a [routerLink]="['/dashboard']" class="logo">
          <mat-icon class="logo-icon">admin_panel_settings</mat-icon>
          <span>{{ appName }}</span>
        </a>
        <span class="spacer"></span>
        <div class="user-menu">
          <span class="user-name hide-small">{{ user.first_name || 'User' }}</span>
          <button mat-icon-button [matMenuTriggerFor]="userMenu" class="user-avatar">
            <span class="avatar-text">{{ getUserInitials(user) }}</span>
          </button>
          <mat-menu #userMenu="matMenu" class="user-dropdown">
            <div class="user-menu-header">
              <p class="user-menu-name">{{ user.first_name }} {{ user.last_name }}</p>
              <p class="user-menu-email">{{ user.email }}</p>
              <div class="user-menu-role">{{ user.role }}</div>
            </div>
            <mat-divider></mat-divider>
            <button mat-menu-item [routerLink]="['/profile']">
              <mat-icon>person</mat-icon>
              <span>My Profile</span>
            </button>
            <button mat-menu-item *ngIf="isOrgAdmin(user) || isSuperAdmin(user)" [routerLink]="['/organization-settings']">
              <mat-icon>settings</mat-icon>
              <span>Organization Settings</span>
            </button>
            <button mat-menu-item (click)="logout()">
              <mat-icon>exit_to_app</mat-icon>
              <span>Logout</span>
            </button>
          </mat-menu>
        </div>
      </mat-toolbar>

      <mat-sidenav-container class="sidenav-container">
        <mat-sidenav #drawer mode="side" opened class="sidenav">
          <mat-nav-list>
            <a mat-list-item routerLink="/dashboard" routerLinkActive="active">
              <mat-icon matListItemIcon>dashboard</mat-icon>
              <span matListItemTitle>Dashboard</span>
            </a>
            <a mat-list-item *ngIf="isSuperAdmin(user)" routerLink="/organizations" routerLinkActive="active">
              <mat-icon matListItemIcon>business</mat-icon>
              <span matListItemTitle>Organizations</span>
            </a>
            <a mat-list-item *ngIf="isSuperAdmin(user) || isOrgAdmin(user)" routerLink="/users" routerLinkActive="active">
              <mat-icon matListItemIcon>people</mat-icon>
              <span matListItemTitle>Users</span>
            </a>
            <a mat-list-item *ngIf="isSuperAdmin(user) || isOrgAdmin(user)" routerLink="/roles" routerLinkActive="active">
              <mat-icon matListItemIcon>admin_panel_settings</mat-icon>
              <span matListItemTitle>Roles</span>
            </a>
            <a mat-list-item *ngIf="isSuperAdmin(user) || isOrgAdmin(user)" routerLink="/organization-settings" routerLinkActive="active">
              <mat-icon matListItemIcon>settings</mat-icon>
              <span matListItemTitle>Settings</span>
            </a>
          </mat-nav-list>
        </mat-sidenav>
        <mat-sidenav-content class="sidenav-content">
          <router-outlet></router-outlet>
        </mat-sidenav-content>
      </mat-sidenav-container>
    </div>

    <ng-template #loginTemplate>
      <router-outlet></router-outlet>
    </ng-template>
  `,
  styles: [`
    .app-container {
      display: flex;
      flex-direction: column;
      height: 100vh;
    }
    
    .app-toolbar {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      z-index: 2;
    }
    
    .sidenav-container {
      flex: 1;
      margin-top: 64px;
    }
    
    .sidenav {
      width: 250px;
      border-right: 1px solid rgba(0, 0, 0, 0.08);
      background-color: #fff;
    }
    
    .sidenav-content {
      padding: 20px;
      background-color: var(--background-color);
    }
    
    .logo {
      text-decoration: none;
      color: white;
      display: flex;
      align-items: center;
      font-weight: 500;
      letter-spacing: 0.5px;
    }
    
    .logo-icon {
      margin-right: 8px;
    }
    
    .user-menu {
      display: flex;
      align-items: center;
    }
    
    .user-name {
      margin-right: 12px;
      font-weight: 500;
    }
    
    .user-avatar {
      background-color: rgba(255, 255, 255, 0.2);
      width: 36px;
      height: 36px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
    }
    
    .avatar-text {
      font-size: 14px;
      font-weight: 500;
    }
    
    .user-menu-header {
      padding: 16px;
      background-color: rgba(0, 0, 0, 0.02);
    }
    
    .user-menu-name {
      font-weight: 500;
      margin: 0 0 4px;
    }
    
    .user-menu-email {
      font-size: 12px;
      margin: 0 0 8px;
      color: var(--text-secondary);
    }
    
    .user-menu-role {
      display: inline-block;
      font-size: 11px;
      text-transform: uppercase;
      background-color: var(--secondary-color);
      color: white;
      padding: 3px 8px;
      border-radius: 12px;
      letter-spacing: 0.5px;
    }
    
    .active {
      background-color: rgba(52, 152, 219, 0.1) !important;
      color: var(--secondary-color) !important;
      border-left: 3px solid var(--secondary-color);
    }
    
    .active mat-icon {
      color: var(--secondary-color);
    }
    
    mat-nav-list a {
      margin: 4px 8px;
      border-radius: 4px;
      transition: all 0.2s;
    }
    
    @media (max-width: 768px) {
      .hide-small {
        display: none;
      }
      
      .sidenav {
        width: 200px;
      }
    }
  `]
})
export class AppComponent {
  appName = 'Admin Portal';

  constructor(
    public supabaseService: SupabaseService,
    private appSettingsService: AppSettingsService
  ) {
    // Subscribe to app name changes
    this.appSettingsService.appName$.subscribe(name => {
      this.appName = name;
      // Update document title
      document.title = name;
    });
  }

  isSuperAdmin(user: any): boolean {
    return user.role === 'super_admin';
  }
  
  isOrgAdmin(user: any): boolean {
    return user.role === 'org_admin';
  }
  
  getUserInitials(user: any): string {
    if (!user.first_name && !user.last_name) return 'U';
    return `${user.first_name?.charAt(0) || ''}${user.last_name?.charAt(0) || ''}`;
  }
  
  async logout() {
    try {
      await this.supabaseService.signOut();
    } catch (error: any) {
      console.error('Error logging out:', error.message);
    }
  }
}