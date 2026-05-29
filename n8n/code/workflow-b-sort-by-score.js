/**
 * n8n Code node — Workflow B
 * Sort ranked jobs by score descending (highest first).
 */

function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

const rows = $input.all();

rows.sort((a, b) => {
  const scoreA = Number(a.json?.score) || 0;
  const scoreB = Number(b.json?.score) || 0;
  return scoreB - scoreA;
});

return rows.map((item, index) => ({
  json: {
    ...(item.json || {}),
    rank: index + 1,
  },
}));
