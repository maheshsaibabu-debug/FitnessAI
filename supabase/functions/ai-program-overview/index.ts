// AI program overview — the narrative layer over a real, already-computed
// trajectory (lib/domain/program_engine/program_trajectory_engine.dart),
// weekly plan, and nutrition targets. Same division of responsibility as
// every other AI feature in this app (docs/AI_ARCHITECTURE.md): this
// function explains and organizes numbers the client already computed
// deterministically — it never invents a new weight trajectory, calorie
// target, or exercise. Only this file and its OPENROUTER_MODEL secret
// know which LLM is behind it.
//
// Returns structured sections (not one flat block of prose) so the
// client can render nutrition/meal suggestions as their own findable
// card — burying them partway through a wall of text was a real
// usability complaint, not a style preference.

const DEFAULT_MODEL = "google/gemini-2.5-flash-lite";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

const SYSTEM_PROMPT = `You write a personal fitness/nutrition program overview, in the friendly but informative style of a knowledgeable coach, from real data given to you as JSON. You are NOT deciding any numbers — every weight milestone, calorie/macro target, and exercise you mention MUST come from the data given. Never invent a different trajectory, target, or exercise, and never state a daily calorie/protein/carb/fat number other than the ones given.

Respond with ONLY a single JSON object, no prose outside it, no markdown fences, matching exactly this shape:
{
  "summary": "One paragraph on the goal and pace, mentioning if/why the timeline was safety-adjusted when the data says so.",
  "weeklyPlanNarrative": "A few sentences walking through the real workout days given (title, exercise names, focus). If several strength days are given, briefly note the muscle-group logic when apparent (e.g. chest/back roughly twice weekly) — never invent extra days or exercises.",
  "nutritionSummary": "1-2 sentences restating the given calorie/protein/carb/fat targets exactly and noting that hitting protein consistently matters more than hitting every number exactly.",
  "meals": [
    {"label": "Breakfast", "suggestion": "A real, specific meal with rough portions, fitting dietaryPreference and respecting dietaryRestrictions."},
    {"label": "Lunch", "suggestion": "..."},
    {"label": "Snack", "suggestion": "..."},
    {"label": "Dinner", "suggestion": "..."},
    {"label": "Pre/post-workout", "suggestion": "..."}
  ],
  "trackingChecklist": ["Weight trend (7-day average)", "Steps", "Workouts completed", "Sleep"],
  "closingLine": "If the user is 40+, new to exercise, or the pace required a safety adjustment, suggest checking with a doctor before starting; otherwise a short encouraging line."
}

If dietaryPreference/dietaryRestrictions aren't given, keep meal suggestions broadly omnivorous. Keep it warm and concrete, not clinical. Reference the person's actual goals/level and dietary preference where relevant.`;

interface OverviewRequest {
  profile: {
    name: string;
    fitnessLevel: string;
    goals: string[];
    dietaryPreference?: string;
    dietaryRestrictions?: string[];
  };
  trajectory: {
    startWeightKg: number;
    goalWeightKg: number;
    effectiveTargetDate: string;
    wasAdjusted: boolean;
    adjustmentReason: string | null;
    weeklyRateKg: number;
    milestones: Array<{ date: string; weightKg: number; label: string }>;
  };
  nutrition: {
    calorieTarget: number;
    proteinGrams: number;
    carbsGrams: number;
    fatGrams: number;
  };
  weeklyPlan: Array<{
    title: string;
    workoutType: string;
    exercises: string[];
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

  let body: OverviewRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), { status: 400 });
  }

  if (!body.profile || !body.trajectory || !body.nutrition || !Array.isArray(body.weeklyPlan)) {
    return new Response(
      JSON.stringify({ error: "profile, trajectory, nutrition, and weeklyPlan are required" }),
      { status: 400 },
    );
  }

  const model = Deno.env.get("OPENROUTER_MODEL") ?? DEFAULT_MODEL;
  const userPrompt = `Profile: ${JSON.stringify(body.profile)}
Trajectory: ${JSON.stringify(body.trajectory)}
Nutrition targets: ${JSON.stringify(body.nutrition)}
This week's real plan: ${JSON.stringify(body.weeklyPlan)}`;

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
      max_tokens: 2600,
    }),
  });

  if (!openRouterResponse.ok) {
    const errorText = await openRouterResponse.text();
    console.error(`OpenRouter error ${openRouterResponse.status}: ${errorText}`);
    return new Response(JSON.stringify({ error: "Program overview is temporarily unavailable" }), { status: 502 });
  }

  const completion = await openRouterResponse.json();
  const content = completion?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    return new Response(JSON.stringify({ error: "Program overview generator returned an empty reply" }), {
      status: 502,
    });
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    console.error(`Program overview generator returned non-JSON content: ${content}`);
    return new Response(JSON.stringify({ error: "Program overview generator returned malformed JSON" }), {
      status: 502,
    });
  }

  return new Response(JSON.stringify({ overview: parsed, model: completion?.model ?? model }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
