// app/api/login/route.ts

import { NextRequest, NextResponse } from "next/server";

export async function POST(request: NextRequest) {
  const { secret } = await request.json();
  const sharedSecret = process.env.SHARED_SECRET;

  if (!sharedSecret) {
    return NextResponse.json(
      { error: "Server not configured with SHARED_SECRET." },
      { status: 500 }
    );
  }

  if (secret === sharedSecret) {
    // Set a cookie for isLoggedIn
    const response = NextResponse.json({ success: true }, { status: 200 });
    response.cookies.set("isLoggedIn", "true", {
      httpOnly: true,
      path: "/",
    });
    return response;
  } else {
    return NextResponse.json({ error: "Invalid secret." }, { status: 401 });
  }
}