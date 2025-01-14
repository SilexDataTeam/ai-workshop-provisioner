// app/lib/csvUtils.ts

import fs from 'fs';

/* eslint-disable @typescript-eslint/no-unused-vars */

interface Registration {
  userId: string;      // e.g. 'user1', 'user2', ...
  firstName: string;
  lastName: string;
  email: string;
  registrationDate: string;
}

/**
 * Read existing CSV data from disk.
 * Returns an array of Registration objects.
 */
export function readRegistrations(csvFilePath: string): Registration[] {
  if (!fs.existsSync(csvFilePath)) {
    return [];
  }

  const data = fs.readFileSync(csvFilePath, 'utf-8').trim();
  if (!data) {
    return [];
  }

  // Split by lines
  const lines = data.split('\n');
  // Remove header row if it exists
  const [header, ...rows] = lines;

  // If the header is "userId,firstName...", skip it
  let startIndex = 0;
  if (header.includes('userId,firstName,lastName,email,registrationDate')) {
    startIndex = 0;
  } else {
    // The header isn't recognized; treat entire array as data
    rows.unshift(header);
    startIndex = -1;
  }

  return rows.map((line) => {
    const [userId, firstName, lastName, email, registrationDate] =
      line.split(',');
    return {
      userId,
      firstName,
      lastName,
      email,
      registrationDate,
    };
  });
}

/**
 * Append a new registration to the CSV file.
 * If file does not exist, create it and write header + row.
 * If file exists, just append a row.
 */
export function appendRegistration(
  csvFilePath: string,
  registration: Registration
) {
  const exists = fs.existsSync(csvFilePath);

  const row = [
    registration.userId,
    registration.firstName,
    registration.lastName,
    registration.email,
    registration.registrationDate,
  ].join(',');

  if (!exists) {
    // Write header + row
    const header =
      'userId,firstName,lastName,email,registrationDate';
    fs.writeFileSync(csvFilePath, header + '\n' + row + '\n', 'utf-8');
  } else {
    // Append row
    fs.appendFileSync(csvFilePath, row + '\n', 'utf-8');
  }
}

/**
 * Get the next available user ID (e.g., 'user1', 'user2', ...)
 * based on what's already in the CSV and up to MAX_USERS.
 */
export function getNextAvailableUserId(
  registrations: Registration[],
  maxUsers: number
): string | null {
  const usedIds = new Set(registrations.map((r) => r.userId));
  for (let i = 1; i <= maxUsers; i++) {
    const candidate = `user${i}`;
    if (!usedIds.has(candidate)) {
      return candidate;
    }
  }
  return null; // means no more spots
}