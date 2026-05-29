/**
 * n8n Code node — Workflow B
 * Fail fast with a clear message if resumes are missing.
 * Wire: Store ranking config -> Validate config -> Read unique_jobs tab
 */

function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function cleanResume(value) {
  return String(value ?? '').trim();
}

function normalizeKey(raw) {
  return clean(raw)
    .toLowerCase()
    .replace(/\s+/g, '_')
    .replace(/[^a-z0-9_]/g, '');
}

function getStoreOutput() {
  try {
    return $('Store ranking config').first().json || {};
  } catch (error) {
    return {};
  }
}

/** Re-load resumes from sheet if staticData is empty (safety net). */
function reloadRankingConfigFromSheet() {
  const map = {};

  try {
    for (const item of $('Read config tab B').all()) {
      const json = item.json || {};
      const key = clean(String(json.key || ''));
      const raw = json.value;
      if (!key || key.toLowerCase() === 'key') continue;
      if (raw === undefined || raw === null || !String(raw).trim()) continue;

      const nk = normalizeKey(key);
      const value = key.toLowerCase().includes('resume') ? cleanResume(raw) : clean(raw);
      if (value && (!map[nk] || value.length > map[nk].length)) {
        map[nk] = value;
      }
    }
  } catch (error) {
    return null;
  }

  if (!Object.keys(map).length) return null;

  const staticData = $getWorkflowStaticData('global');
  staticData.rankingConfig = {
    ...(staticData.rankingConfig || {}),
    openai_model: map.openai_model || staticData.rankingConfig?.openai_model || 'gpt-4o-mini',
    systems_resume_text: map.systems_resume_text || '',
    mechanical_resume_text: map.mechanical_resume_text || '',
    controls_resume_text: map.controls_resume_text || '',
    blocklist: map.blocklist || staticData.rankingConfig?.blocklist || '',
  };

  return staticData.rankingConfig;
}

let cfg = $getWorkflowStaticData('global').rankingConfig || {};
const storeOutput = getStoreOutput();

const required = [
  'systems_resume_text',
  'mechanical_resume_text',
  'controls_resume_text',
];

let missing = required.filter((key) => !String(cfg[key] || '').trim());

if (missing.length) {
  const reloaded = reloadRankingConfigFromSheet();
  if (reloaded) {
    cfg = reloaded;
    missing = required.filter((key) => !String(cfg[key] || '').trim());
  }
}

if (missing.length) {
  const keysSeen = clean(storeOutput.config_keys_seen || '');
  const resumeLikeKeys = keysSeen
    .split(',')
    .map((key) => clean(key))
    .filter((key) => key.includes('resume'));

  throw new Error(
    `Config tab is missing resume text for: ${missing.join(', ')}.\n\n` +
    'Your sheet input looks correct (row_number, key, value). Usually this means:\n' +
    '- systems_resume_text or mechanical_resume_text rows are empty in column B, OR\n' +
    '- Store ranking config Code node is set to "Run once for each item" (change to "Run once for all items")\n\n' +
    'Check **Store ranking config** output:\n' +
    `- config_rows: ${storeOutput.config_rows || 0} (should be ~20+)\n` +
    `- config_rows_from_input: ${storeOutput.config_rows_from_input || '?'}\n` +
    `- debug_resume_key_lengths: ${storeOutput.debug_resume_key_lengths || 'none'}\n` +
    `- controls_resume_chars: ${storeOutput.controls_resume_chars || 0}\n\n` +
    `Resume keys parsed: ${resumeLikeKeys.join(', ') || 'none'}\n` +
    'Re-import PipelineB.json and run from Start Workflow B.'
  );
}

return [{
  json: {
    config_valid: true,
    has_systems_resume: true,
    has_mechanical_resume: true,
    has_controls_resume: true,
    systems_resume_chars: String(cfg.systems_resume_text || '').length,
    mechanical_resume_chars: String(cfg.mechanical_resume_text || '').length,
    controls_resume_chars: String(cfg.controls_resume_text || '').length,
  },
}];
