// app/layout.tsx

import "./globals.css";
import Image from "next/image";
import { ReactNode } from "react";

export const metadata = {
  title: "Silex GenAI Workshop Registration",
  description: "App for user registration",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-gray-100">
        {/* Our shared header */}
        <header className="flex items-center p-4 bg-white shadow mb-6">
          <div className="container mx-auto">
            <Image
              src="/silex-logo.png"
              alt="Silex Data Solutions"
              width={120}
              height={40}
              priority
            />
          </div>
        </header>

        {/* The main content (all pages) */}
        <main className="container mx-auto">{children}</main>
      </body>
    </html>
  );
}