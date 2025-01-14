// middleware.ts

import { NextRequest, NextResponse } from 'next/server';

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  // Paths that require login
  const protectedPaths = ['/register', '/success'];

  if (protectedPaths.some((path) => pathname.startsWith(path))) {
    const isLoggedIn = request.cookies.get('isLoggedIn')?.value;
    if (isLoggedIn !== 'true') {
      // Redirect to /login if not logged in
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }

  return NextResponse.next();
}