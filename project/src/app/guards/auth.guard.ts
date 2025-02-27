import { Injectable } from '@angular/core';
import { CanActivate, Router, ActivatedRouteSnapshot, RouterStateSnapshot } from '@angular/router';
import { Observable, map, take } from 'rxjs';
import { SupabaseService } from '../services/supabase.service';

@Injectable({
  providedIn: 'root'
})
export class AuthGuard implements CanActivate {
  constructor(
    private supabaseService: SupabaseService,
    private router: Router
  ) {}

  canActivate(
    route: ActivatedRouteSnapshot,
    state: RouterStateSnapshot
  ): Observable<boolean> {
    return this.supabaseService.currentUser$.pipe(
      take(1),
      map(user => {
        const isAuthenticated = !!user;
        
        if (!isAuthenticated) {
          this.router.navigate(['/login']);
          return false;
        }
        
        // Check for required role if specified
        const requiredRole = route.data['requiredRole'];
        if (requiredRole && user?.role !== requiredRole) {
          this.router.navigate(['/unauthorized']);
          return false;
        }
        
        return true;
      })
    );
  }
}