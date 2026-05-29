/**
 * n8n Code node — Workflow B
 * Remove jobs whose title/JD matches config blocklist (ITAR, citizenship, etc.)
 */

function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function splitTerms(value) {
  return clean(value)
    .split(/[,;|\n]/)
    .map((term) => clean(term).toLowerCase())
    .filter(Boolean);
}

const defaultBlocklist = [
  'itar',
  'export control',
  'u.s. citizen',
  'us citizen',
  'united states citizen',
  'citizenship required',
  'must be a citizen',
  'must be a u.s. citizen',
  'active secret clearance',
  'secret clearance',
  'top secret clearance',
  'ability to obtain clearance',
];

const staticData = $getWorkflowStaticData('global');
const configured = splitTerms(staticData.rankingConfig?.blocklist || '');
const blocklist = configured.length ? configured : defaultBlocklist;

function isRestricted(job) {
  const haystack = clean([
    job.title,
    job.full_jd,
    job.location,
    job.company,
  ].join(' ')).toLowerCase();

  return blocklist.some((term) => haystack.includes(term));
}

const out = [];

for (const item of $input.all()) {
  const job = item.json || {};
  if (isRestricted(job)) continue;
  out.push(item);
}

return out;
