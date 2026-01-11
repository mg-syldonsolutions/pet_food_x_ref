export async function apiGet(path) {
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE}${path}`);
  return res.json();
}

export async function apiPost(path, body) {
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return res.json();
}
