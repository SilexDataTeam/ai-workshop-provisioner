// app/api/register/route.ts

import { NextResponse } from "next/server";
import { readRegistrations, appendRegistration, getNextAvailableUserId } from "@/app/lib/csvUtils"

export async function POST(request: Request) {
  try {
    // 1. Parse JSON body
    const { firstName, lastName, email } = await request.json();

    // 2. Basic validation
    if (!firstName || !lastName || !email) {
      return NextResponse.json(
        { error: "All fields (firstName, lastName, email) are required." },
        { status: 400 }
      );
    }

    // 3. Read environment variables
    const maxUsers = parseInt(process.env.MAX_USERS || "60", 10);
    const csvFilePath = process.env.CSV_FILE_PATH || "/app/data/registrations.csv";

    // 4. Read existing registrations from CSV
    const registrations = readRegistrations(csvFilePath);

    // 5. Check if we've already reached the max
    if (registrations.length >= maxUsers) {
      return NextResponse.json(
        { error: "Registration limit reached." },
        { status: 403 }
      );
    }

    // 6. Get next available user ID
    const userId = getNextAvailableUserId(registrations, maxUsers);
    if (!userId) {
      return NextResponse.json(
        { error: "No user IDs left." },
        { status: 403 }
      );
    }

    // 7. Append the new registration record
    const newRegistration = {
      userId,
      firstName,
      lastName,
      email,
      registrationDate: new Date().toISOString(),
    };
    appendRegistration(csvFilePath, newRegistration);

    // 8. On success, return JSON including userId
    //    and set a "isRegistered" cookie so we know the user is registered.
    const response = NextResponse.json({ userId }, { status: 200 });

    // The "isRegistered" cookie can be read in your default page or middleware
    // to immediately redirect the user to /success if they're already registered.
    response.cookies.set("isRegistered", "true", {
      httpOnly: true, // More secure if we only need the cookie server-side
      path: "/",      // Cookie is valid for the entire site
      // maxAge, secure, etc. can be added as needed
    });
    response.cookies.set("userId", userId, {
      httpOnly: true,
      path: "/",
    });

    return response;
  } catch (error) {
    console.error("Registration error:", error);
    return NextResponse.json(
      { error: "Could not complete registration." },
      { status: 500 }
    );
  }
}