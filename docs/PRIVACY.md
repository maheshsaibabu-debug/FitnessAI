# Privacy

## Health data is sensitive by default

Steps, weight, body composition, measurements, and workout performance are treated as sensitive personal data, not generic app telemetry.

- **Minimize at the source**: `HealthRepository` (phase 8) will request only the HealthKit/Health Connect data types the app actually displays (steps, and later workouts/energy if a feature needs them) — not a broad "read everything" permission grant.
- **Never sent to the AI gateway wholesale**: the `FitnessContextResolver` (see [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md)) sends a bounded, summarized context (e.g. "adherence 4/5 this week, trending down 0.3kg/week"), never raw historical rows of weight/steps/workouts.
- **Never logged to analytics**: the analytics event list in the product brief §45 (`workout_completed`, `steps_synced`, etc.) records that an action happened, not the health values involved — no weight, step count, or body measurement value belongs in an analytics payload.

## User control

- Health integrations must be disconnectable from Settings (phase 8/15) without deleting local historical data already recorded.
- Community/challenge visibility (phase 14) defaults to private; sharing progress is opt-in per the product brief §36.

## Data minimization to the AI gateway

The AI gateway (a Supabase Edge Function, phase 11) is the only network hop that ever sees coaching-relevant context. It receives a resolved, summarized context object — never a raw database dump — and the client never talks to an LLM vendor directly (see [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md)), so a vendor never sees the user's raw health history either.

## Status

This document describes the privacy rules the implementation is required to follow as each phase lands; it will be updated with concrete verification (e.g. a captured network payload showing a summarized, not raw, AI context) once phase 8 (health) and phase 11 (AI coach) exist to check against.
