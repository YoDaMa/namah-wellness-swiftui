# TODOS

## P2 — Adaptive Scheduling (Phase 2)
Learn from user completion timestamps to suggest personalized time blocks. E.g., "You usually take morning supplements at 7:30am, not 6:00am — adjust?"
- **Why**: Transforms static time blocks into an intelligent daily coach
- **Depends on**: Completion history data (created in time-block PR)
- **Effort**: L

## P2 — Phase-Aware Notification Content
Custom notification text per cycle phase. E.g., "Luteal phase tip: Your progesterone is high today, magnesium will help with sleep tonight" instead of generic "Time to take evening supplements."
- **Why**: Makes notifications feel like a knowledgeable coach, not a generic reminder app
- **Depends on**: Notification infrastructure from time-block PR
- **Effort**: M

## P3 — iOS Widget for Current Time Block
Lock Screen / Home Screen widget showing current time block + next action. E.g., "MORNING — Take Vitamin D · Breakfast: Masala Oats"
- **Why**: Most visible touchpoint — users see widget without opening app
- **Depends on**: TimeBlockService from time-block PR
- **Effort**: L
