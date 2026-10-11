// Guards the specific acceptance criterion "other AI features remain
// unchanged": ai-coach-gateway and ai-program-overview must keep reading
// the shared OPENROUTER_MODEL secret with their own original defaults,
// and must never reference the new OPENROUTER_PLAN_MODEL var this task
// introduced for ai-plan-generator only. A source-text check rather than
// an import, since these two functions call Deno.serve at module scope
// with no test seam (out of scope for this task to refactor) — this is
// still a real, CI-breaking check if either file is ever edited to read
// the new var or drop its own default.
//
// Run with: deno test --allow-read supabase/functions/ai-plan-generator/model_isolation.test.ts

import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

const coachGatewaySource = await Deno.readTextFile(
  new URL("../ai-coach-gateway/index.ts", import.meta.url),
);
const programOverviewSource = await Deno.readTextFile(
  new URL("../ai-program-overview/index.ts", import.meta.url),
);

Deno.test("ai-coach-gateway keeps its own default model and the shared OPENROUTER_MODEL var", () => {
  assertStringIncludes(
    coachGatewaySource,
    'DEFAULT_MODEL = "z-ai/glm-5.2:free"',
  );
  assertStringIncludes(coachGatewaySource, 'Deno.env.get("OPENROUTER_MODEL")');
  assertEquals(coachGatewaySource.includes("OPENROUTER_PLAN_MODEL"), false);
});

Deno.test("ai-program-overview keeps its own default model and the shared OPENROUTER_MODEL var", () => {
  assertStringIncludes(
    programOverviewSource,
    'DEFAULT_MODEL = "google/gemini-2.5-flash-lite"',
  );
  assertStringIncludes(
    programOverviewSource,
    'Deno.env.get("OPENROUTER_MODEL")',
  );
  assertEquals(programOverviewSource.includes("OPENROUTER_PLAN_MODEL"), false);
});
