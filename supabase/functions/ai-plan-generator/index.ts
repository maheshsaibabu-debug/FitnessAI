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
// Model routing is intentionally its own env var (OPENROUTER_PLAN_MODEL),
// separate from the OPENROUTER_MODEL secret shared by ai-coach-gateway and
// ai-program-overview — changing what this function uses must never move
// those two. See docs/AI_ARCHITECTURE.md.
//
// Secrets: OPENROUTER_API_KEY (required), OPENROUTER_PLAN_MODEL (optional,
// defaults to PLAN_MODEL below).
//
// Scope note (see the task this was built for): the meal/food items shown
// in the Diet tab come from a fixed deterministic template table
// (lib/data/repositories/nutrition_repository.dart), never from an LLM —
// only the four nutrition numbers below (calorieTarget/protein/carbs/fat)
// are AI-generated, alongside the workout plan. Dietary restrictions
// (vegetarian/halal/etc.) already apply at the template-selection step,
// not here, since they don't change macro *targets*, only which foods
// fill them. Likewise, exercise history/recovery/injuries and food
// budget/preferences aren't collected anywhere in the app today, so
// they're not referenced in the prompt below — adding them is a data
// model change, not a model-routing one.

const PLAN_MODEL = "qwen/qwen3.7-flash";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const MAX_ATTEMPTS = 2;
const RETRY_DELAY_MS = 300;
const REQUEST_TIMEOUT_MS = 25_000;
const TEMPERATURE = 0.3;
const MAX_TOKENS = 4000;

const SYSTEM_PROMPT =
  `You design a one-week workout plan and daily nutrition targets for a fitness app user, from their profile and an exercise library. Respond with ONLY the JSON object below — no prose, no markdown fences.

Hard rules:
- Every exercise "id" MUST be copied exactly from the provided library — never invent one.
- Only select exercises whose "equipment" is a subset of availableEquipment ("none" is always allowed; "full_gym" unlocks every machine/barbell/dumbbell/bench exercise).
- Only select exercises whose "difficulty" is at or below fitnessLevel (beginner < intermediate < advanced).
- Produce exactly profile.daysPerWeek days (dayOffset 0..daysPerWeek-1), no more, no fewer.
- With gym access (full_gym, machines, barbell, or dumbbells+bench) and 4+ days/week, use a real muscle-group split (e.g. chest/triceps, back/biceps, legs/core, shoulders, arms) giving each major group ~twice-weekly exposure, 5-8 exercises/day, compounds before isolation. Weave in 1-2 short conditioning/HIIT finishers for fat-loss/endurance/cardio goals, never on leg days.
- Bodyweight-only or fewer days: 3-6 exercises/day is fine.
- Each exercise sets exactly one of targetReps (rep-based) or targetDurationSeconds (time-based, e.g. planks/HIIT) — never both, never neither.
- calorieTarget is a defensible estimate for the stated goal (fat loss/muscle gain/weight gain/maintain) — never an extreme deficit or surplus.

Respond with exactly this shape:
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

/** Which OpenRouter model this function calls — independently configurable
 * from the other two AI features via its own env var. */
export function resolveModel(
  env: { get(key: string): string | undefined } = Deno.env,
): string {
  return env.get("OPENROUTER_PLAN_MODEL") ?? PLAN_MODEL;
}

/** Rejects missing/structurally wrong fields and implausible numbers
 * (e.g. a 0kg bodyweight) before anything is sent to the model — the
 * schema-preserving way to "flag missing or implausible data instead of
 * fabricating precision": the model is never asked to reason over bad
 * numbers in the first place. Returns an error message, or null if valid. */
export function validateRequest(body: unknown): string | null {
  if (typeof body !== "object" || body === null) {
    return "Request body must be a JSON object";
  }
  const b = body as Partial<PlanRequest>;

  if (!b.profile || typeof b.profile !== "object") return "profile is required";
  if (!b.nutritionInput || typeof b.nutritionInput !== "object") {
    return "nutritionInput is required";
  }
  if (!Array.isArray(b.library) || b.library.length === 0) {
    return "a non-empty library is required";
  }

  const p = b.profile;
  if (
    !Number.isFinite(p.daysPerWeek) || p.daysPerWeek < 1 || p.daysPerWeek > 7
  ) {
    return "profile.daysPerWeek must be between 1 and 7";
  }
  if (
    !Number.isFinite(p.minutesPerSession) || p.minutesPerSession < 10 ||
    p.minutesPerSession > 180
  ) {
    return "profile.minutesPerSession must be between 10 and 180";
  }
  if (!p.fitnessLevel || !Array.isArray(p.availableEquipment)) {
    return "profile.fitnessLevel and profile.availableEquipment are required";
  }

  const n = b.nutritionInput;
  if (!Number.isFinite(n.weightKg) || n.weightKg <= 0 || n.weightKg > 400) {
    return "nutritionInput.weightKg is missing or implausible";
  }
  if (!Number.isFinite(n.heightCm) || n.heightCm <= 0 || n.heightCm > 272) {
    return "nutritionInput.heightCm is missing or implausible";
  }
  if (!Number.isFinite(n.ageYears) || n.ageYears < 13 || n.ageYears > 100) {
    return "nutritionInput.ageYears is missing or implausible";
  }
  if (!n.sex || !n.activityLevel || !n.goal) {
    return "nutritionInput.sex, activityLevel, and goal are required";
  }

  return null;
}

interface OpenRouterCallResult {
  content: string;
  model: string;
  usage: { prompt_tokens?: number; completion_tokens?: number } | null;
}

class RetryableError extends Error {}

/** One OpenRouter attempt: times out via AbortController, and throws
 * RetryableError for anything a retry could plausibly fix (network
 * failure, 429, 5xx, or content that didn't parse as JSON) so the caller
 * knows what's safe to retry versus what should fail fast. */
async function callOnce(
  model: string,
  userPrompt: string,
  apiKey: string,
  fetchImpl: typeof fetch,
): Promise<OpenRouterCallResult> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let response: Response;
  try {
    response = await fetchImpl(OPENROUTER_URL, {
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
        temperature: TEMPERATURE,
        max_tokens: MAX_TOKENS,
      }),
      signal: controller.signal,
    });
  } catch (e) {
    throw new RetryableError(`OpenRouter request failed: ${e}`);
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    const errorText = await response.text();
    const message = `OpenRouter error ${response.status}: ${errorText}`;
    if (response.status === 429 || response.status >= 500) {
      throw new RetryableError(message);
    }
    throw new Error(message);
  }

  const completion = await response.json();
  const content = completion?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    throw new RetryableError("OpenRouter returned an empty reply");
  }

  try {
    JSON.parse(content); // validated for real by the caller; this just decides retry-worthiness
  } catch {
    throw new RetryableError(
      `OpenRouter returned non-JSON content: ${content}`,
    );
  }

  return {
    content,
    model: completion?.model ?? model,
    usage: completion?.usage ?? null,
  };
}

/** Bounded retry around [callOnce] — only for failures callOnce marked
 * retryable; anything else (bad API key, our own validation) fails on the
 * first attempt. Emits one structured telemetry line regardless of
 * outcome, since this is the only place that knows the real model,
 * attempt count, latency, and token usage. */
async function callWithRetry(
  model: string,
  userPrompt: string,
  apiKey: string,
  fetchImpl: typeof fetch,
): Promise<OpenRouterCallResult> {
  const startedAt = Date.now();
  let lastError: unknown;
  let attemptsMade = 0;

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    attemptsMade = attempt;
    try {
      const result = await callOnce(model, userPrompt, apiKey, fetchImpl);
      console.log(JSON.stringify({
        event: "ai_plan_generation",
        model,
        attempts: attempt,
        latencyMs: Date.now() - startedAt,
        promptTokens: result.usage?.prompt_tokens ?? null,
        completionTokens: result.usage?.completion_tokens ?? null,
        outcome: "success",
      }));
      return result;
    } catch (e) {
      lastError = e;
      if (!(e instanceof RetryableError) || attempt === MAX_ATTEMPTS) break;
      await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
    }
  }

  console.log(JSON.stringify({
    event: "ai_plan_generation",
    model,
    attempts: attemptsMade,
    latencyMs: Date.now() - startedAt,
    outcome: "failure",
    error: String(lastError),
  }));
  throw lastError;
}

/** The actual request handler — a plain function (not inline in
 * Deno.serve) so it's directly callable from tests with a fake fetch and
 * env, without starting a real server or hitting the network. */
export async function handleRequest(
  req: Request,
  deps: {
    fetchImpl?: typeof fetch;
    env?: { get(key: string): string | undefined };
  } = {},
): Promise<Response> {
  const fetchImpl = deps.fetchImpl ?? fetch;
  const env = deps.env ?? Deno.env;

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
    });
  }

  const apiKey = env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "Gateway is not configured" }),
      { status: 500 },
    );
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
    });
  }

  const validationError = validateRequest(body);
  if (validationError) {
    return new Response(JSON.stringify({ error: validationError }), {
      status: 400,
    });
  }
  const planRequest = body as PlanRequest;

  const model = resolveModel(env);
  const userPrompt = `Profile: ${JSON.stringify(planRequest.profile)}
Nutrition input: ${JSON.stringify(planRequest.nutritionInput)}
Exercise library (${planRequest.library.length} entries): ${
    JSON.stringify(planRequest.library)
  }`;

  let result: OpenRouterCallResult;
  try {
    result = await callWithRetry(model, userPrompt, apiKey, fetchImpl);
  } catch (e) {
    console.error(`Plan generator failed after retries: ${e}`);
    return new Response(
      JSON.stringify({ error: "Plan generator is temporarily unavailable" }),
      { status: 502 },
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(result.content);
  } catch {
    console.error(
      `Plan generator returned non-JSON content after retries: ${result.content}`,
    );
    return new Response(
      JSON.stringify({ error: "Plan generator returned malformed JSON" }),
      { status: 502 },
    );
  }

  return new Response(JSON.stringify({ plan: parsed, model: result.model }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

// Guarded so importing this module from a test (to reach the exported
// functions above) never binds a real network listener.
if (import.meta.main) {
  Deno.serve((req) => handleRequest(req));
}
