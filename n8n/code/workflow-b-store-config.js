/**
 * n8n Code node — Workflow B
 * Parse config tab once and store for all parallel ranking branches.
 * Wire: Read config tab B -> Store ranking config -> Validate config -> Read unique_jobs tab
 */

function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

/** Keep resume text intact (newlines); only trim ends. */
function cleanResume(value) {
  return String(value ?? '').trim();
}

function normalizeKey(raw) {
  return clean(raw)
    .toLowerCase()
    .replace(/\s+/g, '_')
    .replace(/[^a-z0-9_]/g, '');
}

function isHeaderRow(key, value) {
  const k = normalizeKey(key);
  const v = normalizeKey(value);
  return (k === 'key' && (v === 'value' || v === '')) || (k === 'config_key' && v === 'config_value');
}

function looksLikeConfigKey(text) {
  const t = normalizeKey(text);
  return t.length > 0 && t.length < 80 && /^[a-z][a-z0-9_]*$/.test(t);
}

function extractPair(json) {
  const obj = json || {};

  // Standard Google Sheets shape (row_number, key, value)
  if (obj.key !== undefined && obj.key !== null && String(obj.key).trim()) {
    const key = clean(String(obj.key));
    const raw = obj.value;
    if (raw !== undefined && raw !== null && String(raw).trim()) {
      const value = key.toLowerCase().includes('resume')
        ? cleanResume(raw)
        : clean(raw);
      return { key, value };
    }
  }

  const skip = new Set(['row_number', 'row', 'id']);

  const keyCandidates = [
    'key', 'Key', 'KEY', 'config_key', 'name', 'setting', 'parameter',
    'A', 'Column A', 'col_1', 'column_1',
  ];
  const valueCandidates = [
    'value', 'Value', 'VALUE', 'config_value', 'content', 'text',
    'B', 'Column B', 'col_2', 'column_2',
  ];

  let key = '';
  let value = '';

  for (const field of keyCandidates) {
    if (obj[field] !== undefined && obj[field] !== null && String(obj[field]).trim()) {
      key = clean(obj[field]);
      break;
    }
  }

  for (const field of valueCandidates) {
    if (obj[field] !== undefined && obj[field] !== null && String(obj[field]).trim()) {
      const raw = obj[field];
      const keyHint = clean(key).toLowerCase();
      value = keyHint.includes('resume') ? cleanResume(raw) : clean(raw);
      break;
    }
  }

  if (key && value) {
    if (key.length > 500 && value.length < 120 && looksLikeConfigKey(value)) {
      return { key: value, value: key };
    }
    return { key, value };
  }

  const entries = Object.entries(obj)
    .filter(([name, val]) => !skip.has(name) && val !== undefined && val !== null && clean(val))
    .map(([name, val]) => [name, clean(val)]);

  if (entries.length >= 2) {
    const [a, b] = entries;
    const aIsKey = looksLikeConfigKey(a[1]);
    const bIsKey = looksLikeConfigKey(b[1]);
    if (aIsKey && !bIsKey) return { key: a[1], value: b[1] };
    if (bIsKey && !aIsKey) return { key: b[1], value: a[1] };
    return { key: a[1], value: b[1] };
  }

  if (entries.length === 1) {
    const [name, val] = entries[0];
    if (looksLikeConfigKey(name)) return { key: name, value: val };
    if (looksLikeConfigKey(val)) return { key: val, value: '' };
  }

  return { key: '', value: '' };
}

function buildConfigMap(rows) {
  const map = {};

  for (const item of rows) {
    const { key, value } = extractPair(item.json || {});
    if (!key || isHeaderRow(key, value)) continue;

    const nk = normalizeKey(key);
    if (!nk) continue;

    const existing = map[nk] || '';
    if (value && (!existing || value.length > existing.length)) {
      map[nk] = value;
    }
  }

  return map;
}

/** Always read all config rows from the sheet node (not just $input item 1). */
function getConfigRows() {
  try {
    const sheetRows = $('Read config tab B').all();
    if (sheetRows.length) return sheetRows;
  } catch (error) {}

  return $input.all();
}

function pick(map, keys) {
  for (const key of keys) {
    const nk = normalizeKey(key);
    if (map[nk]) return map[nk];
  }
  for (const key of keys) {
    const wanted = normalizeKey(key);
    const fuzzy = Object.keys(map).find((k) => k.includes(wanted) || wanted.includes(k));
    if (fuzzy && map[fuzzy]) return map[fuzzy];
  }
  return '';
}

const rows = $input.all();
const map = buildConfigMap(rows);
const staticData = $getWorkflowStaticData('global');

staticData.rankingConfig = {
  openai_api_key: pick(map, ['openai_api_key']),
  openai_model: pick(map, ['openai_model']) || 'gpt-4o-mini',
  jd_score_prompt: pick(map, ['jd_score_prompt', 'llm_rank_prompt']),
  llm_rank_prompt: pick(map, ['llm_rank_prompt', 'jd_score_prompt']),
  systems_rank_prompt: pick(map, ['systems_rank_prompt']),
  mechanical_rank_prompt: pick(map, ['mechanical_rank_prompt']),
  controls_rank_prompt: pick(map, ['controls_rank_prompt']),
  systems_resume_text: pick(map, [
    'systems_resume_text',
    'systems_resume',
    'system_resume_text',
  ]),
  mechanical_resume_text: pick(map, [
    'mechanical_resume_text',
    'mechanical_resume',
    'mech_resume_text',
  ]),
  controls_resume_text: pick(map, [
    'controls_resume_text',
    'controls_resume',
    'control_resume_text',
  ]),
  blocklist: pick(map, ['blocklist']),
};

const loadedKeys = Object.keys(map);
const firstRow = rows[0]?.json || {};
const resumeKeyLengths = loadedKeys
  .filter((k) => k.includes('resume'))
  .map((k) => `${k}=${(map[k] || '').length}`)
  .join(', ');

return [{
  json: {
    config_loaded: true,
    config_rows: rows.length,
    config_rows_from_input: $input.all().length,
    config_pairs_parsed: loadedKeys.length,
    has_systems_resume: Boolean(staticData.rankingConfig.systems_resume_text),
    has_mechanical_resume: Boolean(staticData.rankingConfig.mechanical_resume_text),
    has_controls_resume: Boolean(staticData.rankingConfig.controls_resume_text),
    config_keys_seen: loadedKeys.slice(0, 40).join(', '),
  // row_number + key + value is the expected Google Sheets shape — not an error
    debug_first_row_fields: Object.keys(firstRow).join(', '),
    debug_resume_key_lengths: resumeKeyLengths || 'no keys containing "resume" in config tab',
    systems_resume_chars: String(staticData.rankingConfig.systems_resume_text || '').length,
    mechanical_resume_chars: String(staticData.rankingConfig.mechanical_resume_text || '').length,
    controls_resume_chars: String(staticData.rankingConfig.controls_resume_text || '').length,
  },
}];
