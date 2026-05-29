/**
 * Shared helpers for Gmail alert parsers (paste at top of provider-specific nodes).
 */

function stripRating(company) {
  return (company || '').replace(/\s*\d+(\.\d+)?\s*★.*$/i, '').trim();
}

function parseAgeHint(token) {
  if (!token) return null;
  const m = String(token).trim().match(/^(\d+)\s*(h|d)$/i);
  if (!m) return null;
  const n = parseInt(m[1], 10);
  const unit = m[2].toLowerCase();
  const ms = unit === 'h' ? n * 3600000 : n * 86400000;
  return new Date(Date.now() - ms).toISOString();
}

function parseDicePosted(line) {
  const m = (line || '').match(/Posted:\s*(\d{2}-\d{2}-\d{4})/i);
  if (!m) return null;
  const [mm, dd, yyyy] = m[1].split('-');
  return new Date(`${yyyy}-${mm}-${dd}T12:00:00Z`).toISOString();
}

function baseRow(fields) {
  return {
    found_at: new Date().toISOString(),
    status: 'needs_jd',
    needs_manual_jd: true,
    apply_url: '',
    description: '',
    ...fields,
  };
}

module.exports = { stripRating, parseAgeHint, parseDicePosted, baseRow };
