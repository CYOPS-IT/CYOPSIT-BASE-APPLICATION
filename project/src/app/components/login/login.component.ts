import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatTabsModule } from '@angular/material/tabs';
import { CommonModule } from '@angular/common';
import { SupabaseService } from '../../services/supabase.service';
import { AppSettingsService } from '../../services/app-settings.service';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatProgressSpinnerModule,
    MatSnackBarModule,
    MatIconModule,
    MatDividerModule,
    MatTabsModule
  ],
  template: `
    <div class="landing-container">
      <header class="landing-header">
        <span class="logo-text">{{ appName }}</span>
        <div class="header-actions">
          <a href="#" class="nav-link">DOCS</a>
          <button mat-flat-button color="primary" (click)="showLoginForm()">
            LOGIN
          </button>
        </div>
      </header>

      <div *ngIf="!showLogin" class="hero-section">
        <div class="hero-content">
          <h1>Welcome to {{ appName }}</h1>
          <p class="hero-subtitle">Advanced inventory and production management system</p>
          <p class="hero-description">With over 10 years of experience in the steel industry</p>
          <button mat-raised-button color="primary" class="hero-cta" (click)="showLoginForm()">
            Get Started
          </button>
        </div>
        <div class="hero-image">
          <img src="https://images.unsplash.com/photo-1581091226033-d5c48150dbaa?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80" alt="Admin Portal">
        </div>
      </div>

      <div *ngIf="!showLogin" class="features-section">
        <div class="feature-card">
          <mat-icon class="feature-icon">inventory_2</mat-icon>
          <h3>Production Management</h3>
          <p>Streamline your manufacturing processes with real-time tracking and analytics.</p>
        </div>
        <div class="feature-card">
          <mat-icon class="feature-icon">insights</mat-icon>
          <h3>Real-time Analytics</h3>
          <p>Gain valuable insights into your operations with comprehensive dashboards and reports.</p>
        </div>
        <div class="feature-card">
          <mat-icon class="feature-icon">verified</mat-icon>
          <h3>Quality Assurance</h3>
          <p>Maintain the highest standards with our integrated quality control systems.</p>
        </div>
        <div class="feature-card">
          <mat-icon class="feature-icon">settings_suggest</mat-icon>
          <h3>Custom Solutions</h3>
          <p>Tailored implementations to meet your specific business requirements.</p>
        </div>
      </div>

      <div *ngIf="!showLogin" class="company-section">
        <div class="company-info">
          <h2>Industrial Solutions Inc.</h2>
          <p class="company-tagline">Your trusted partner in industrial management</p>
          
          <h3>Our Specialties</h3>
          <ul class="specialties-list">
            <li><mat-icon>check_circle</mat-icon> Real-time Data Analysis</li>
            <li><mat-icon>check_circle</mat-icon> Production Management</li>
            <li><mat-icon>check_circle</mat-icon> Custom Solutions</li>
            <li><mat-icon>check_circle</mat-icon> Quality Control</li>
          </ul>
        </div>
        <div class="company-image">
          <img src="https://images.unsplash.com/photo-1551288049-bebda4e38f71?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80" alt="Analytics Dashboard">
        </div>
      </div>

      <div *ngIf="!showLogin" class="facilities-section">
        <h2>Our State-of-the-Art Facilities</h2>
        
        <div class="facilities-grid">
          <div class="facility-card">
            <img src="https://images.unsplash.com/photo-1581092921461-39b9d08a9b21?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80" alt="Steel Processing Machines">
            <h3>Steel Processing Machines</h3>
            <p>Our state-of-the-art steel processing equipment offers cutting-edge technology available to meet the most demanding manufacturing specifications.</p>
          </div>
          <div class="facility-card">
            <img src="https://images.unsplash.com/photo-1558494949-ef010cbdcc31?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2068&q=80" alt="Modern Storage Solutions">
            <h3>Modern Storage Solutions</h3>
            <p>Our advanced storage systems ensure optimal inventory management, product safety, and efficient retrieval to maintain service quality and client satisfaction.</p>
          </div>
        </div>
      </div>

      <div *ngIf="showLogin" class="login-container">
        <mat-card class="auth-card">
          <button mat-icon-button class="close-button" (click)="hideLoginForm()">
            <mat-icon>close</mat-icon>
          </button>
          
          <div class="auth-header">
            <h1 class="auth-title">{{ appName }}</h1>
            <p class="auth-subtitle">Sign in to your account</p>
          </div>
          
          <mat-divider></mat-divider>
          
          <form [formGroup]="loginForm" (ngSubmit)="onSubmit()" class="auth-form">
            <mat-form-field appearance="outline" class="full-width">
              <mat-label>Email</mat-label>
              <input matInput formControlName="email" type="email" required>
              <mat-icon matSuffix>email</mat-icon>
              <mat-error *ngIf="loginForm.get('email')?.hasError('required')">
                Email is required
              </mat-error>
              <mat-error *ngIf="loginForm.get('email')?.hasError('email')">
                Please enter a valid email address
              </mat-error>
            </mat-form-field>
            
            <mat-form-field appearance="outline" class="full-width">
              <mat-label>Password</mat-label>
              <input matInput formControlName="password" [type]="hidePassword ? 'password' : 'text'" required>
              <button type="button" mat-icon-button matSuffix (click)="hidePassword = !hidePassword">
                <mat-icon>{{hidePassword ? 'visibility_off' : 'visibility'}}</mat-icon>
              </button>
              <mat-error *ngIf="loginForm.get('password')?.hasError('required')">
                Password is required
              </mat-error>
            </mat-form-field>
            
            <div *ngIf="errorMessage" class="error-message">
              <mat-icon>error</mat-icon> {{ errorMessage }}
            </div>
            
            <div class="auth-actions">
              <button 
                mat-raised-button 
                color="primary" 
                type="submit" 
                [disabled]="loginForm.invalid || isLoading"
                class="full-width login-button">
                <mat-spinner *ngIf="isLoading" diameter="20"></mat-spinner>
                <span *ngIf="!isLoading">Sign In</span>
              </button>
              
              <button 
                mat-stroked-button 
                color="primary" 
                type="button"
                (click)="resetPassword()"
                [disabled]="!loginForm.get('email')?.valid || isLoading"
                class="full-width">
                Forgot Password?
              </button>
            </div>
          </form>
          
          <div *ngIf="showSetupLink" class="auth-link">
            <mat-divider class="setup-divider"></mat-divider>
            <p>No admin account exists yet</p>
            <button mat-flat-button color="accent" (click)="goToSetup()">
              <mat-icon>settings</mat-icon> Initial System Setup
            </button>
          </div>
        </mat-card>
      </div>

      <footer class="landing-footer">
        <div class="footer-content">
          <p>&copy; 2025 {{ appName }}. All rights reserved.</p>
          <div class="footer-links">
            <a href="#">Privacy Policy</a>
            <a href="#">Terms of Service</a>
            <a href="#">Contact Us</a>
          </div>
        </div>
      </footer>
    </div>
  `,
  styles: [`
    .landing-container {
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      background-color: #f8f9fa;
    }
    
    .landing-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 0 32px;
      background-color: #2c3e50;
      color: white;
      height: 56px;
      position: sticky;
      top: 0;
      z-index: 100;
    }
    
    .logo-text {
      font-size: 20px;
      font-weight: 500;
      color: white;
      letter-spacing: 0.5px;
    }
    
    .header-actions {
      display: flex;
      align-items: center;
      gap: 24px;
    }
    
    .nav-link {
      color: white;
      text-decoration: none;
      font-size: 14px;
      font-weight: 500;
      letter-spacing: 0.5px;
      transition: opacity 0.2s;
    }
    
    .nav-link:hover {
      opacity: 0.8;
    }
    
    .hero-section {
      display: flex;
      padding: 64px 32px;
      background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
      color: white;
      min-height: 400px;
    }
    
    .hero-content {
      flex: 1;
      display: flex;
      flex-direction: column;
      justify-content: center;
      padding-right: 32px;
    }
    
    .hero-content h1 {
      font-size: 42px;
      font-weight: 700;
      margin-bottom: 16px;
      color: white;
    }
    
    .hero-content h1:after {
      display: none;
    }
    
    .hero-subtitle {
      font-size: 24px;
      margin-bottom: 16px;
      font-weight: 300;
    }
    
    .hero-description {
      font-size: 18px;
      margin-bottom: 32px;
      opacity: 0.9;
    }
    
    .hero-cta {
      align-self: flex-start;
      padding: 8px 32px;
      font-size: 18px;
    }
    
    .hero-image {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    
    .hero-image img {
      max-width: 100%;
      max-height: 400px;
      border-radius: 8px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
    }
    
    .features-section {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 24px;
      padding: 64px 32px;
      background-color: white;
    }
    
    .feature-card {
      padding: 32px;
      border-radius: 8px;
      background-color: white;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
      transition: transform 0.3s ease, box-shadow 0.3s ease;
      text-align: center;
    }
    
    .feature-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
    }
    
    .feature-icon {
      font-size: 48px;
      height: 48px;
      width: 48px;
      color: var(--secondary-color);
      margin-bottom: 16px;
    }
    
    .feature-card h3 {
      font-size: 20px;
      font-weight: 500;
      margin-bottom: 12px;
      color: var(--primary-color);
    }
    
    .feature-card p {
      color: var(--text-secondary);
      line-height: 1.5;
    }
    
    .company-section {
      display: flex;
      padding: 64px 32px;
      background-color: #f8f9fa;
    }
    
    .company-info {
      flex: 1;
      padding-right: 32px;
    }
    
    .company-info h2 {
      font-size: 32px;
      margin-bottom: 16px;
      color: var(--primary-color);
    }
    
    .company-tagline {
      font-size: 18px;
      color: var(--text-secondary);
      margin-bottom: 32px;
    }
    
    .company-info h3 {
      font-size: 20px;
      margin-bottom: 16px;
      color: var(--primary-color);
    }
    
    .specialties-list {
      list-style: none;
      padding: 0;
      margin: 0;
    }
    
    .specialties-list li {
      display: flex;
      align-items: center;
      margin-bottom: 12px;
      font-size: 16px;
    }
    
    .specialties-list mat-icon {
      color: var(--secondary-color);
      margin-right: 8px;
      font-size: 20px;
    }
    
    .company-image {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    
    .company-image img {
      max-width: 100%;
      border-radius: 8px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
    }
    
    .facilities-section {
      padding: 64px 32px;
      background-color: white;
    }
    
    .facilities-section h2 {
      font-size: 32px;
      margin-bottom: 32px;
      text-align: center;
      color: var(--primary-color);
    }
    
    .facilities-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
      gap: 32px;
    }
    
    .facility-card {
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
      transition: transform 0.3s ease, box-shadow 0.3s ease;
    }
    
    .facility-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
    }
    
    .facility-card img {
      width: 100%;
      height: 240px;
      object-fit: cover;
    }
    
    .facility-card h3 {
      font-size: 20px;
      font-weight: 500;
      margin: 16px;
      color: var(--primary-color);
    }
    
    .facility-card p {
      padding: 0 16px 16px;
      color: var(--text-secondary);
      line-height: 1.5;
    }
    
    .landing-footer {
      background-color: var(--primary-color);
      color: white;
      padding: 32px;
      margin-top: auto;
    }
    
    .footer-content {
      display: flex;
      justify-content: space-between;
      align-items: center;
      max-width: 1200px;
      margin: 0 auto;
    }
    
    .footer-links {
      display: flex;
      gap: 24px;
    }
    
    .footer-links a {
      color: white;
      text-decoration: none;
      transition: opacity 0.2s;
    }
    
    .footer-links a:hover {
      opacity: 0.8;
    }
    
    .login-container {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background-color: rgba(0, 0, 0, 0.5);
      display: flex;
      justify-content: center;
      align-items: center;
      z-index: 1000;
      padding: 20px;
    }
    
    .auth-card {
      max-width: 450px;
      width: 100%;
      padding: 32px;
      border-radius: var(--border-radius) !important;
      position: relative;
    }
    
    .close-button {
      position: absolute;
      top: 8px;
      right: 8px;
    }
    
    .auth-header {
      text-align: center;
      margin-bottom: 24px;
    }
    
    .auth-title {
      font-size: 28px;
      font-weight: 500;
      margin: 0 0 8px;
      color: var(--primary-color);
    }
    
    .auth-subtitle {
      color: var(--text-secondary);
      margin: 0;
      font-size: 16px;
    }
    
    .auth-form {
      margin-top: 24px;
    }
    
    .auth-actions {
      margin-top: 24px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    
    .login-button {
      height: 48px;
      font-size: 16px;
    }
    
    .error-message {
      display: flex;
      align-items: center;
      gap: 8px;
      color: var(--warning-color);
      margin: 8px 0;
      padding: 8px 16px;
      background-color: rgba(231, 76, 60, 0.1);
      border-radius: var(--border-radius);
    }
    
    .auth-link {
      margin-top: 24px;
      text-align: center;
    }
    
    .setup-divider {
      margin: 24px 0 16px;
    }
    
    .full-width {
      width: 100%;
    }
    
    @media (max-width: 992px) {
      .hero-section, .company-section {
        flex-direction: column;
      }
      
      .hero-content, .company-info {
        padding-right: 0;
        margin-bottom: 32px;
      }
      
      .facilities-grid {
        grid-template-columns: 1fr;
      }
    }
    
    @media (max-width: 768px) {
      .footer-content {
        flex-direction: column;
        gap: 16px;
      }
      
      .hero-content h1 {
        font-size: 32px;
      }
      
      .hero-subtitle {
        font-size: 20px;
      }
    }
  `]
})
export class LoginComponent implements OnInit {
  loginForm: FormGroup;
  isLoading = false;
  errorMessage = '';
  showSetupLink = false;
  hidePassword = true;
  showLogin = false;
  appName = environment.appName;

  constructor(
    private fb: FormBuilder,
    private supabaseService: SupabaseService,
    private router: Router,
    private snackBar: MatSnackBar,
    private appSettingsService: AppSettingsService
  ) {
    this.loginForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', Validators.required]
    });
    
    // Subscribe to app name changes
    this.appSettingsService.appName$.subscribe(name => {
      this.appName = name;
    });
  }

  ngOnInit() {
    this.checkIfSetupNeeded();
  }

  async checkIfSetupNeeded() {
    try {
      this.supabaseService.checkIfSuperAdminExists().subscribe(exists => {
        this.showSetupLink = !exists;
      });
    } catch (error) {
      console.error('Error checking if setup is needed:', error);
      // If there's an error, show the setup link just in case
      this.showSetupLink = true;
    }
  }

  showLoginForm() {
    this.showLogin = true;
  }

  hideLoginForm() {
    this.showLogin = false;
  }

  goToSetup() {
    this.router.navigate(['/setup']);
  }

  async resetPassword() {
    const email = this.loginForm.get('email')?.value;
    
    if (!email) {
      this.errorMessage = 'Please enter your email address to reset your password';
      return;
    }
    
    this.isLoading = true;
    
    try {
      await this.supabaseService.sendEmailVerification(email);
      this.errorMessage = '';
      this.snackBar.open(`Password reset email sent to ${email}. Please check your inbox.`, 'Close', {
        duration: 5000
      });
    } catch (error: any) {
      this.errorMessage = error.message || 'Failed to send password reset email';
    } finally {
      this.isLoading = false;
    }
  }

  async onSubmit() {
    if (this.loginForm.invalid) {
      return;
    }
    
    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      const { email, password } = this.loginForm.value;
      await this.supabaseService.signIn(email, password);
      this.router.navigate(['/dashboard']);
    } catch (error: any) {
      if (error.message.includes('Email not confirmed')) {
        this.errorMessage = 'Please check your email to verify your account before logging in.';
      } else {
        this.errorMessage = error.message || 'An error occurred during login';
      }
    } finally {
      this.isLoading = false;
    }
  }
}