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

## P2 — Ovulation Detection (BBT Thermal Shift)
Analyze BBT data for thermal shift pattern: 3 consecutive temps above coverline = confirmed ovulation. Display on BBT chart + mark ovulation day on calendar.
- **Why**: Transforms BBT from passive logging to active fertility insight
- **Depends on**: BBT chart from historical-tracking PR
- **Effort**: M

## P2 — Cervical Mucus Tracking
Add CervicalMucusLog model with type enum (dry, sticky, creamy, watery, egg-white). Display on calendar dots + day detail sheet.
- **Why**: Third pillar of fertility awareness alongside BBT and cycle tracking
- **Depends on**: Day detail sheet from historical-tracking PR
- **Effort**: S

## P3 — Data Export (Cycle Report)
Generate shareable PDF/CSV report with cycle stats, BBT chart, symptom patterns, sexual activity summary. For sharing with healthcare providers.
- **Why**: Users need to share cycle data with doctors; manual transcription is error-prone
- **Depends on**: All tracking features established
- **Effort**: M
