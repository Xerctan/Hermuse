// Client lokal ambil request yang antri (max 8 per poll)
export async function onRequestPost({ request, env }) {
  const { key, limit } = await request.json().catch(() => ({}));
  if (key !== env.TUNNEL_KEY) return new Response("forbidden", { status: 403 });

  const now = Date.now();
  await env.DB.batch([
    env.DB.prepare("DELETE FROM tunnel_requests WHERE created_at < ?").bind(now - 120000),
    env.DB.prepare("DELETE FROM tunnel_responses WHERE created_at < ?").bind(now - 120000),
  ]);

  const n = Math.min(Math.max(parseInt(limit) || 4, 1), 8);
  const rows = await env.DB.prepare(
    "SELECT id, method, path, headers, body FROM tunnel_requests WHERE status='pending' ORDER BY created_at ASC LIMIT ?"
  ).bind(n).all();

  if (rows.results.length > 0) {
    const ids = rows.results.map((r) => r.id);
    const placeholders = ids.map(() => "?").join(",");
    await env.DB.prepare(
      `UPDATE tunnel_requests SET status='claimed' WHERE id IN (${placeholders})`
    ).bind(...ids).run();
  }

  return Response.json({ requests: rows.results });
}
