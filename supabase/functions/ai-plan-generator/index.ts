// AI plan generator — the LLM-driven counterpart to
// domain/workout_engine/workout_generation_engine.dart and
// domain/nutrition_engine/nutrition_calculation_engine.dart. Given a
// user's profile and the bundled exercise library, asks the model to
// produce a full week's workout plan and daily nutrition targets as
// strict JSON. This is the ONLY place the OpenRouter key/model live for
// plan generation; the Flutter client (lib/ai/plan/ai_plan_provider.dart)
// never sees either, and independently re-validates every number this
// returns before anything is persisted — a malformed or unsafe response
// here just makes the client fall back to the deterministic engines, it
// can never corrupt local data.
//
// Secrets: OPENROUTER_API_KEY (required), OPENROUTER_MODEL (optional,
// same default/override as ai-coach-gateway).

const DEFAULT_MODEL = "google/gemini-2.5-flash-lite";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

const SYSTEM_PROMPT = `You design a one-week workout plan and daily nutrition targets for a fitness app user, from their profile and an exercise library.

Hard rules:
- Every exercise you select MUST use an "id" copied exactly from the provided library — never invent an exercise or its id.
- Only select exercises whose "equipment" is a subset of the user's availableEquipment (the library already includes "none" for bodyweight-only, which is always allowed).
- Only select exercises whose "difficulty" is at or below the user's fitnessLevel (beginner < intermediate < advanced).
- Produce exactly profile.daysPerWeek workout days (dayOffset 0..daysPerWeek-1), each with 3-8 exercises.
- For each exercise set either targetReps (rep-based) or targetDurationSeconds (time-based, e.g. planks/HIIT), never both.
- calorieTarget must be a defensible estimate for the user's stated goal (fat loss/muscle gain/weight gain/maintain) — never an extreme deficit or surplus.
- Respond with ONLY a single JSON object, no prose, no markdown fences, matching exactly this shape:
{
  "workouts": [
    {
      "dayOffset": 0,
      "workoutType": "push",
      "title": "Push Day",
      "exercises": [
        {"exerciseId": "push-up", "targetSets": 3, "targetReps": 10, "targetDurationSeconds": null, "restSeconds": 75}
      ]
    }
  ],
  "nutrition": {
    "calorieTarget": 2200,
    "proteinGrams": 150,
    "carbsGrams": 220,
    "fatGrams": 70
  }
}`;

interface PlanRequest {
  profile: {
    fitnessLevel: string;
    availableEquipment: string[];
    daysPerWeek: number;
    minutesPerSession: number;
    goals: string[];
  };
  nutritionInput: {
    sex: string;
    weightKg: number;
    heightCm: number;
    ageYears: number;
    activityLevel: string;
    goal: string;
  };
  library: Array<{
    id: string;
    name: string;
    category: string;
    primaryMuscles: string[];
    equipment: string[];
    difficulty: string;
  }>;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "Gateway is not configured" }), { status: 500 });
  }

  let body: PlanRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), { status: 400 });
  }

  if (!body.profile || !body.nutritionInput || !Array.isArray(body.library) || body.library.length === 0) {
    return new Response(JSON.stringify({ error: "profile, nutritionInput, and a non-empty library are required" }), {
      status: 400,
    });
  }

  const model = Deno.env.get("OPENROUTER_MODEL") ?? DEFAULT_MODEL;

  const userPrompt = `Profile: ${JSON.stringify(body.profile)}
Nutrition input: ${JSON.stringify(body.nutritionInput)}
Exercise library (${body.library.length} entries): ${JSON.stringify(body.library)}`;

  const openRouterResponse = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userPrompt },
      ],
      response_format: { type: "json_object" },
      max_tokens: 4000,
    }),
  });

  if (!openRouterResponse.ok) {
    const errorText = await openRouterResponse.text();
    console.error(`OpenRouter error ${openRouterResponse.status}: ${errorText}`);
    return new Response(JSON.stringify({ error: "Plan generator is temporarily unavailable" }), { status: 502 });
  }

  const completion = await openRouterResponse.json();
  const content = completion?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    return new Response(JSON.stringify({ error: "Plan generator returned an empty reply" }), { status: 502 });
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    console.error(`Plan generator returned non-JSON content: ${content}`);
    return new Response(JSON.stringify({ error: "Plan generator returned malformed JSON" }), { status: 502 });
  }

  return new Response(JSON.stringify({ plan: parsed, model: completion?.model ?? model }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
