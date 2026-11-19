// POST { profile } -> { tags: string[] }  — short, editable lifestyle tags for the profile screen.
import { ask, json, profileText, requireUser, spend, type Profile } from "../_shared/common.ts";

const SYSTEM = `From a person's profile, write 4 to 7 short lifestyle tags (1-3 words each, Title Case), such as "Introvert", "Creative Professional", "Dog Lover".
Only use what the profile supports. Output the tags on one line, separated by commas, and nothing else.`;

Deno.serve(async (req) => {
  const user = await requireUser(req);
  if (user instanceof Response) return user;
  const limited = await spend(user.id, "tags");
  if (limited) return limited;

  const { profile } = await req.json() as { profile: Profile };
  try {
    const line = await ask(SYSTEM, `<profile>\n${profileText(profile)}\n</profile>`, 1000, "low");
    const tags = line.split(",").map((t) => t.trim()).filter((t) => t && t.length <= 32).slice(0, 7);
    return json({ tags });
  } catch (e) {
    return json({ error: (e as Error).message }, 502);
  }
});
