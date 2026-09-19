// AI coach gateway — implements docs/AI_ARCHITECTURE.md's CloudAiProvider
// contract. This is the ONLY place the real OpenRouter API key and model
// id live; the Flutter client never sees either (see
// lib/ai/providers/cloud_ai_provider.dart).
//
// Secrets (set via `supabase secrets set`, never committed):
//   OPENROUTER_API_KEY  - required
//   OPENROUTER_MODEL    - optional, defaults to a free model below.
//                          Free-tier model availability on OpenRouter
//                          changes over time — check https://openrouter.ai/models
//                          (filter: prompt pricing $0) and override this
//                          secret if the default below has been retired.

const DEFAULT_MODEL = "meta-llama/llama-3.1-8b-instruct:free";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

// Deliberately narrow: the LLM explains and motivates over numbers the
// deterministic engines already computed (docs/AI_ARCHITECTURE.md
// "Division of responsibility"). It must never invent a workout plan,
// a calorie/macro target, or medical/injury advice.
const SYSTEM_PROMPT = `You are a supportive fitness coach inside a fitness app.
You are given a JSON snapshot of the user's real, already-computed data: their
goals, fitness level, recent workout adherence, streak, step average, weight
trend, and daily calorie/protein targets. Use only these numbers.

Rules:
- Never invent a new workout plan, exercise list, or calorie/macro target —
  those come from the app's own engines, not you. If asked to change the
  plan, tell the user to use the Plan screen's regenerate action or redo
  onboarding for major changes.
- Never give medical, injury, or diagnostic advice — suggest seeing a
  professional for anything beyond general fitness/nutrition coaching.
- Keep replies short (2-4 sentences), warm, and specific to the numbers
  given. Never shame or guilt-trip about missed workouts.
- If the context doesn't contain enough information to answer well, say so
  plainly rather than guessing.`;

interface GatewayRequest {
  userMessage: string;
  context: Record<string, unknown>;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "Gateway is not configured" }), { status: 500 });
  }

  let body: GatewayRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), { status: 400 });
  }

  if (typeof body.userMessage !== "string" || body.userMessage.trim().length === 0) {
    return new Response(JSON.stringify({ error: "userMessage is required" }), { status: 400 });
  }
  // A generous but bounded cap — this is a chat box, not a document
  // upload; also limits worst-case token spend per call.
  if (body.userMessage.length > 2000) {
    return new Response(JSON.stringify({ error: "userMessage too long" }), { status: 400 });
  }

  const model = Deno.env.get("OPENROUTER_MODEL") ?? DEFAULT_MODEL;

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
        { role: "user", content: `User data: ${JSON.stringify(body.context ?? {})}\n\nUser message: ${body.userMessage}` },
      ],
      max_tokens: 300,
    }),
  });

  if (!openRouterResponse.ok) {
    const errorText = await openRouterResponse.text();
    console.error(`OpenRouter error ${openRouterResponse.status}: ${errorText}`);
    return new Response(JSON.stringify({ error: "Coach is temporarily unavailable" }), { status: 502 });
  }

  const completion = await openRouterResponse.json();
  const message = completion?.choices?.[0]?.message?.content;
  if (typeof message !== "string") {
    return new Response(JSON.stringify({ error: "Coach returned an empty reply" }), { status: 502 });
  }

  return new Response(
    JSON.stringify({ message, model: completion?.model ?? model }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
