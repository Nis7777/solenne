// Shared helpers for Solenne edge functions (Deno).
import Anthropic from "npm:@anthropic-ai/sdk@1.10.0";
import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2.119.2";

export const MODEL = "claude-opus-5-5";

/** Per-user caps per UTC day. Stories are the expensive call (text + voice). */
export const DAILY_LIMITS: Record<string, number> = {
  story: 12,
  reflect: 30,
  tags: 10,
  voice: 3,
};

export const anthropic = new Anthropic(); // reads ANTHROPIC_API_KEY from the function's secrets

export const admin: SupabaseClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Resolves the signed-in (anonymous or Apple) user from the request's JWT. */
export async function requireUser(req: Request): Promise<User | Response> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "missing token" }, 401);
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return json({ error: "invalid token" }, 401);
  return data.user;
}

/** Records one generation, or returns a 429 response if today's cap is reached. */
export async function spend(userId: string, kind: keyof typeof DAILY_LIMITS): Promise<Response | null> {
  const since = new Date();
  since.setUTCHours(0, 0, 0, 0);
  const { count, error } = await admin
    .from("generations")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("kind", kind)
    .gte("created_at", since.toISOString());
  if (error) return json({ error: error.message }, 500);
  if ((count ?? 0) >= DAILY_LIMITS[kind]) return json({ error: "daily limit reached" }, 429);
  await admin.from("generations").insert({ user_id: userId, kind });
  return null;
}

/**
 * One Claude call returning plain text. Uses server-side refusal fallbacks so a
 * classifier false-positive on an intimate story doesn't leave the user with nothing.
 */
export async function ask(system: string, prompt: string, maxTokens: number, effort: "low" | "medium" = "medium"): Promise<string> {
  const response = await anthropic.beta.messages.create({
    model: MODEL,
    max_tokens: maxTokens,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    output_config: { effort },
    system,
    messages: [{ role: "user", content: prompt }],
  });
  if (response.stop_reason === "refusal") throw new Error("refused");
  return response.content
    .flatMap((block) => (block.type === "text" ? [block.text] : []))
    .join("")
    .trim();
}

type Person = { name: string; relation: string };
export type Profile = Record<string, unknown> & {
  people?: Person[];
  kids?: Person[];
  lifestyleTags?: string[];
  neverInclude?: string[];
  notes?: string[];
};

const LABELS: [string, string][] = [
  ["name", "Name"], ["age", "Age"], ["gender", "Gender"], ["sexuality", "Sexuality"],
  ["city", "Lives in"], ["relationship", "Relationship"], ["hasKids", "Has kids"],
  ["work", "Work"], ["workFeeling", "Feels about work"], ["hopingChanges", "Hoping changes"],
  ["whyNow", "Why now"], ["obstacle", "In the way"], ["about", "About them"], ["past", "Past"],
  ["dreamLocation", "Dream location"], ["homeType", "Dream home"], ["partner", "Dream partner"],
  ["dreamCareer", "Dream career"], ["dreamMoney", "Dream money"], ["dreamBody", "Dream body"],
  ["dreamDay", "Dream day"],
];

/** Renders the profile as labelled lines. The answers are user-written data, not instructions. */
export function profileText(p: Profile): string {
  const lines: string[] = [];
  for (const [key, label] of LABELS) {
    const v = typeof p[key] === "string" ? (p[key] as string).trim() : "";
    if (v) lines.push(`${label}: ${v.slice(0, 600)}`);
  }
  const people = (p.people ?? []).map((x) => `${x.name} (${x.relation})`).join(", ");
  if (people) lines.push(`Important people: ${people}`);
  const kids = (p.kids ?? []).map((x) => `${x.name} (${x.relation})`).join(", ");
  if (kids) lines.push(`Kids: ${kids}`);
  if (p.lifestyleTags?.length) lines.push(`Lifestyle: ${p.lifestyleTags.join(", ")}`);
  if (p.notes?.length) lines.push(`Their notes for future stories: ${p.notes.slice(-10).join(" | ")}`);
  return lines.join("\n");
}
