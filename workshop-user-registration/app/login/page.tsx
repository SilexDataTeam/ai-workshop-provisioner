// app/login/page.tsx

"use client";

import { useState } from "react";

/* eslint-disable @typescript-eslint/no-unused-vars */

export default function LoginPage() {
  const [secret, setSecret] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    try {
      const res = await fetch("/api/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ secret }),
      });

      if (res.ok) {
        // Redirect to /register
        window.location.href = "/register";
      } else {
        setError("Invalid secret. Please try again.");
      }
    } catch (err) {
      setError("Something went wrong. Please try again.");
    }
  };

  return (
    <div className="flex flex-col items-center justify-center min-h-screen">
      <div className="max-w-sm w-full bg-white rounded shadow p-4">
        <h1 className="text-2xl mb-4">Silex GenAI Workshop Registration</h1>
        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label htmlFor="secret" className="block mb-2">
              Shared Secret
            </label>
            <input
              type="password"
              id="secret"
              value={secret}
              onChange={(e) => setSecret(e.target.value)}
              className="border rounded w-full p-2"
              required
            />
          </div>
          {error && <p className="text-red-500 mb-4">{error}</p>}
          <button
            type="submit"
            className="bg-blue-500 text-white py-2 px-4 rounded hover:bg-blue-600"
          >
            Login
          </button>
        </form>
      </div>
    </div>
  );
}