// POST multipart { name, sample } -> { voice_id }  — ElevenLabs instant voice clone from a ~10s sample.
import { json, requireUser, spend } from "../_shared/common.ts";

Deno.serve(async (req) => {
  const user = await requireUser(req);
  if (user instanceof Response) return user;
  const limited = await spend(user.id, "voice");
  if (limited) return limited;

  const key = Deno.env.get("ELEVENLABS_API_KEY");
  if (!key) return json({ error: "voice service not configured" }, 503);

  const form = await req.formData();
  const sample = form.get("sample");
  if (!(sample instanceof File)) return json({ error: "missing sample" }, 400);
  if (sample.size > 5_000_000) return json({ error: "sample too large" }, 413);

  const upstream = new FormData();
  upstream.append("name", `solenne-${user.id}`);
  upstream.append("description", `Solenne listener ${String(form.get("name") ?? "").slice(0, 40)}`);
  upstream.append("files", sample, "sample.m4a");

  const res = await fetch("https://api.elevenlabs.io/v1/voices/add", {
    method: "POST",
    headers: { "xi-api-key": key },
    body: upstream,
  });
  if (!res.ok) return json({ error: `clone failed (${res.status})` }, 502);
  const { voice_id } = await res.json() as { voice_id: string };
  return json({ voice_id });
});
