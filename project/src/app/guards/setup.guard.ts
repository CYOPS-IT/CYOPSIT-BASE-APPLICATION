import { Injectable } from '@angular/core';
import { CanActivate, Router } from '@angular/router';
import { Observable, map, take, of, catchError } from 'rxjs';
import { SupabaseService } from '../services/supabase.service';

@Injectable({
  providedIn: 'root'
})
export class SetupGuard implements CanActivate {
  constructor(
    private supabaseService: SupabaseService,
    private router: Router
  ) {}

  canActivate(): Observable<boolean> {
    return this.supabaseService.checkIfSuperAdminExists().pipe(
      take(1),
      map(exists => {
        if (exists) {
          // If super admin already exists, redirect to login
          this.router.navigate(['/login']);
          return false;
        }
        // Allow access to setup page if no super admin exists
        return true;
      }),
      catchError(error => {
        console.error('Error checking if super admin exists:', error);
        // In case of error, allow access to setup page
        return of(true);
      })
    );
  }
}