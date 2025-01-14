// app/page.tsx

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import LoginPage from "./login/page";

export default async function Home() {
  const cookieStore = await cookies();
  const isLoggedIn = cookieStore.get("isLoggedIn")?.value;
  const isRegistered = cookieStore.get("isRegistered")?.value;

  if (isRegistered=== "true") {
    redirect("/success")
  }

  if (isLoggedIn === "true") {
    redirect("/register");
  }
  
  return <LoginPage />;
}