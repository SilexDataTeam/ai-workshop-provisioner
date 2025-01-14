// app/success/page.tsx

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import SuccessClient from "./SuccessClient"

export default async function SuccessPage() {
  // 1. Access cookies server-side
  const cookieStore = await cookies();
  const isRegistered = cookieStore.get("isRegistered")?.value;
  const userId = cookieStore.get("userId")?.value;

  // 2. If no cookie, redirect to /login (or wherever you want)
  if (isRegistered !== "true") {
    redirect("/login");
  }

  return <SuccessClient userId={userId} />;
}