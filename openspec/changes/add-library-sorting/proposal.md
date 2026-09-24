# Change: Add library sorting

## Why
Books and audio lists cannot currently be sorted by users.

## What Changes
- Natural title/filename ascending by default; offer import time and direction.
- Remember independent book and audio preferences.
- Keep playback order aligned with displayed audio without modifying sort_order.

## Impact
- Affected specs: library-sorting
- Affected code: settings, book list/detail, providers, file scanner
