/**
 * n8n Code node — normalize apply/discovery URLs for deduplication.
 * Input: items with json.apply_url and/or json.discovery_url
 * Output: adds json.normalized_apply_url
 */

const TRACKING_PARAMS = new Set([
  'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
  'ref', 'source', 'gh_src', 'lever_source', 'li_fat_id', 'trk', 'trkInfo',
]);

function normalizeApplyUrl(raw) {
  if (!raw || typeof raw !== 'string') return '';
  let url;
  try {
    url = new URL(raw.trim());
  } catch {
    return '';
  }

  const host = url.hostname.toLowerCase().replace(/^www\./, '');
  const params = new URLSearchParams(url.search);
  for (const key of [...params.keys()]) {
    if (TRACKING_PARAMS.has(key.toLowerCase()) || key.toLowerCase().startsWith('utm_')) {
      params.delete(key);
    }
  }
  const query = params.toString();
  let path = url.pathname.replace(/\/+$/, '') || '/';
  return `${url.protocol}//${host}${path}${query ? `?${query}` : ''}`;
}

return $input.all().map((item) => {
  const j = { ...item.json };
  const raw = j.apply_url || j.discovery_url || '';
  j.normalized_apply_url = normalizeApplyUrl(raw);
  return { json: j };
});
