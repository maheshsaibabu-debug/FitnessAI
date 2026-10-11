// Tests for ai-plan-generator's model routing, input validation, and
// retry/timeout handling. Mocks OpenRouter via an injected fetch — no
// real API calls, no credits consumed. Run with:
//   deno test --allow-read --allow-env supabase/functions/ai-plan-generator/index.test.ts

import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { handleRequest, resolveModel, validateRequest } from "./index.ts";

function fakeEnv(vars: Record<string, string>) {
  return { get: (key: string) => vars[key] };
}

const validProfile = {
  fitnessLevel: "beginner",
  availableEquipment: ["none"],
  daysPerWeek: 3,
  minutesPerSession: 30,
  goals: ["general"],
};

const validNutritionInput = {
  sex: "male",
  weightKg: 80,
  heightCm: 180,
  ageYears: 30,
  activityLevel: "moderatelyActive",
  goal: "maintain",
};

const validLibrary = [
  {
    id: "push-up",
    name: "Push-up",
    category: "bodyweight",
    primaryMuscles: ["chest"],
    equipment: ["none"],
    difficulty: "beginner",
  },
];

function validBody() {
  return {
    profile: validProfile,
    nutritionInput: validNutritionInput,
    library: validLibrary,
  };
}

function okCompletion(
  model: string,
  plan: unknown,
  usage?: { prompt_tokens: number; completion_tokens: number },
) {
  return {
    model,
    choices: [{ message: { content: JSON.stringify(plan) } }],
    usage,
  };
}

const samplePlan = {
  workouts: [{
    dayOffset: 0,
    workoutType: "push",
    title: "Push Day",
    exercises: [{
      exerciseId: "push-up",
      targetSets: 3,
      targetReps: 10,
      targetDurationSeconds: null,
      restSeconds: 75,
    }],
  }],
  nutrition: {
    calorieTarget: 2200,
    proteinGrams: 150,
    carbsGrams: 220,
    fatGrams: 70,
  },
};

Deno.test("resolveModel defaults to qwen3.7-flash with no override", () => {
  assertEquals(resolveModel(fakeEnv({})), "qwen/qwen3.7-flash");
});

Deno.test("resolveModel respects OPENROUTER_PLAN_MODEL override, independent of the shared OPENROUTER_MODEL secret", () => {
  assertEquals(
    resolveModel(
      fakeEnv({
        OPENROUTER_PLAN_MODEL: "some/other-model",
        OPENROUTER_MODEL: "ignored-for-this-function",
      }),
    ),
    "some/other-model",
  );
});

Deno.test("validateRequest accepts a valid body", () => {
  assertEquals(validateRequest(validBody()), null);
});

Deno.test("validateRequest rejects a missing library", () => {
  const body = {
    profile: validProfile,
    nutritionInput: validNutritionInput,
    library: [],
  };
  assertStringIncludes(validateRequest(body) ?? "", "library");
});

Deno.test("validateRequest rejects implausible weight instead of passing it through", () => {
  const body = {
    ...validBody(),
    nutritionInput: { ...validNutritionInput, weightKg: 0 },
  };
  assertStringIncludes(validateRequest(body) ?? "", "weightKg");
});

Deno.test("validateRequest rejects implausible age", () => {
  const body = {
    ...validBody(),
    nutritionInput: { ...validNutritionInput, ageYears: 200 },
  };
  assertStringIncludes(validateRequest(body) ?? "", "ageYears");
});

Deno.test("validateRequest rejects daysPerWeek out of range", () => {
  const body = { ...validBody(), profile: { ...validProfile, daysPerWeek: 9 } };
  assertStringIncludes(validateRequest(body) ?? "", "daysPerWeek");
});

Deno.test("handleRequest rejects non-POST", async () => {
  const req = new Request("https://x.test", { method: "GET" });
  const res = await handleRequest(req, {
    env: fakeEnv({ OPENROUTER_API_KEY: "k" }),
  });
  assertEquals(res.status, 405);
});

Deno.test("handleRequest returns 500 when the API key secret is missing", async () => {
  const req = new Request("https://x.test", {
    method: "POST",
    body: JSON.stringify(validBody()),
  });
  const res = await handleRequest(req, { env: fakeEnv({}) });
  assertEquals(res.status, 500);
});

Deno.test("handleRequest returns 400 for invalid JSON body", async () => {
  const req = new Request("https://x.test", {
    method: "POST",
    body: "not json",
  });
  const res = await handleRequest(req, {
    env: fakeEnv({ OPENROUTER_API_KEY: "k" }),
  });
  assertEquals(res.status, 400);
});

Deno.test("handleRequest returns 400 for an implausible input without ever calling OpenRouter", async () => {
  let fetchCalled = false;
  const fetchImpl = (() => {
    fetchCalled = true;
    throw new Error("should not be called");
  }) as typeof fetch;

  const body = {
    ...validBody(),
    nutritionInput: { ...validNutritionInput, weightKg: -5 },
  };
  const req = new Request("https://x.test", {
    method: "POST",
    body: JSON.stringify(body),
  });
  const res = await handleRequest(req, {
    env: fakeEnv({ OPENROUTER_API_KEY: "k" }),
    fetchImpl,
  });

  assertEquals(res.status, 400);
  assertEquals(fetchCalled, false);
});

Deno.test("handleRequest succeeds and reports the configured Qwen model on the first attempt", async () => {
  let callCount = 0;
  const fetchImpl = ((_url, init) => {
    callCount++;
    const sentBody = JSON.parse((init as RequestInit).body as string);
    assertEquals(sentBody.model, "qwen/qwen3.7-flash");
    return Promise.resolve(
      new Response(
        JSON.stringify(okCompletion("qwen/qwen3.7-flash", samplePlan)),
        { status: 200 },
      ),
    );
  }) as typeof fetch;

  const req = new Request("https://x.test", {
    method: "POST",
    body: JSON.stringify(validBody()),
  });
  const res = await handleRequest(req, {
    env: fakeEnv({ OPENROUTER_API_KEY: "k" }),
    fetchImpl,
  });
  const data = await res.json();

  assertEquals(res.status, 200);
  assertEquals(data.model, "qwen/qwen3.7-flash");
  assertEquals(data.plan.workouts.length, 1);
  assertEquals(callCount, 1);
});

Deno.test("handleRequest retries once on a 500 then succeeds (bounded retry recovers)", async () => {
  let callCount = 0;
  const fetchImpl = (() => {
    callCount++;
    if (callCount === 1) {
      return Promise.resolve(new Response("server error", { status: 500 }));
    }
    return Promise.resolve(
      new Response(
        JSON.stringify(okCompletion("qwen/qwen3.7-flash", samplePlan)),
        { status: 200 },
      ),
    );
  }) as typeof fetch;

  const req = new Request("https://x.test", {
    method: "POST",
    body: JSON.stringify(validBody()),
  });
  const res = await handleRequest(req, {
    env: fakeEnv({ OPENROUTER_API_KEY: "k" }),
    fetchImpl,
  });

  assertEquals(res.status, 200);
  assertEquals(callCount, 2);
});

Deno.test("handleRequest gives up after exhausting bounded retries on repeated 5xx", async () => {
  let callCount = 0;
  const fetchImpl = (() => {
    callCount++;
    return Promise.resolve(new Response("server error", { status: 503 }));
  }) as typeof fetch;

  const req = new Request("https://x.test", {
    method: "POST",
    body: JSON.stringify(validBody()),
  });
  const res = await handleRequest(req, {
    env: fakeEnv({ OPENROUTER_API_KEY: "k" }),
    fetchImpl,
  });

  assertEquals(res.status, 502);
  assertEquals(callCount, 2); // MAX_ATTEMPTS, never unbounded
});

Deno.test("handleRequest does not retry a non-retryable 4xx from OpenRouter, and reports the real attempt count in telemetry", async () => {
  let callCount = 0;
  const fetchImpl = (() => {
    callCount++;
    return Promise.resolve(new Response("bad request", { status: 400 }));
  }) as typeof fetch;

  const originalLog = console.log;
  const logged: string[] = [];
  console.log = (msg: string) => logged.push(msg);
  let res: Response;
  try {
    const req = new Request("https://x.test", {
      method: "POST",
      body: JSON.stringify(validBody()),
    });
    res = await handleRequest(req, {
      env: fakeEnv({ OPENROUTER_API_KEY: "k" }),
      fetchImpl,
    });
  } finally {
    console.log = originalLog;
  }

  assertEquals(res.status, 502); // surfaced as gateway failure, but...
  assertEquals(callCount, 1); // ...never retried...
  const telemetry = JSON.parse(logged[0]);
  assertEquals(telemetry.attempts, 1); // ...and telemetry must say so too, not MAX_ATTEMPTS
});

Deno.test("handleRequest retries malformed (non-JSON) model content, then fails cleanly if it never recovers", async () => {
  let callCount = 0;
  const fetchImpl = (() => {
    callCount++;
    const completion = {
      model: "qwen/qwen3.7-flash",
      choices: [{ message: { content: "{not json" } }],
    };
    return Promise.resolve(
      new Response(JSON.stringify(completion), { status: 200 }),
    );
  }) as typeof fetch;

  const req = new Request("https://x.test", {
    method: "POST",
    body: JSON.stringify(validBody()),
  });
  const res = await handleRequest(req, {
    env: fakeEnv({ OPENROUTER_API_KEY: "k" }),
    fetchImpl,
  });

  assertEquals(res.status, 502);
  assertEquals(callCount, 2); // retried once, then gave up — never an infinite loop
});

Deno.test("handleRequest treats an aborted (timed-out) request as retryable, then fails cleanly if it never recovers", async () => {
  let callCount = 0;
  // Simulates what REQUEST_TIMEOUT_MS's AbortController produces, without
  // waiting on the real timer — exercises the same abort-handling path.
  const fetchImpl = (() => {
    callCount++;
    return Promise.reject(
      Object.assign(new Error("The operation was aborted"), {
        name: "AbortError",
      }),
    );
  }) as typeof fetch;

  const req = new Request("https://x.test", {
    method: "POST",
    body: JSON.stringify(validBody()),
  });
  const res = await handleRequest(req, {
    env: fakeEnv({ OPENROUTER_API_KEY: "k" }),
    fetchImpl,
  });

  assertEquals(res.status, 502);
  assertEquals(callCount, 2);
});

Deno.test("a successful response never has prose attached — response is pure JSON with the request_format already enforced", async () => {
  const fetchImpl = ((_url, init) => {
    const sentBody = JSON.parse((init as RequestInit).body as string);
    assertEquals(sentBody.response_format, { type: "json_object" });
    assertEquals(typeof sentBody.temperature, "number");
    assertEquals(typeof sentBody.max_tokens, "number");
    return Promise.resolve(
      new Response(
        JSON.stringify(okCompletion("qwen/qwen3.7-flash", samplePlan)),
        { status: 200 },
      ),
    );
  }) as typeof fetch;

  const req = new Request("https://x.test", {
    method: "POST",
    body: JSON.stringify(validBody()),
  });
  const res = await handleRequest(req, {
    env: fakeEnv({ OPENROUTER_API_KEY: "k" }),
    fetchImpl,
  });
  assertEquals(res.status, 200);
});
