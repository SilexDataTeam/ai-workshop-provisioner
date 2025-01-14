// app/success/SuccessClient.tsx
"use client";

import { useSearchParams } from "next/navigation";

interface SuccessClientProps {
  userId?: string;
}

export default function SuccessClient({ userId }: SuccessClientProps) {
  // Optionally read from the URL if needed:
  const searchParams = useSearchParams();
  const paramUserId = searchParams.get("userId");

  const finalUserId = paramUserId || userId || "";

  return (
    <div className="flex flex-col items-center justify-center min-h-screen">
      <div className="max-w-sm w-full bg-white rounded shadow p-4 text-center">
        <h1 className="text-2xl mb-4">Registration Successful</h1>
        {finalUserId ? (
          <p className="text-lg">
            Your assigned user ID is{" "}
            <span className="font-bold">{finalUserId}</span>.
          </p>
        ) : (
          <p>No user ID found.</p>
        )}
      </div>
    </div>
  );
}