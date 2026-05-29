/**
 * n8n Code node — Workflow B
 * Set BUCKET below to: systems | mechanical | controls
 */

const BUCKET = 'systems';

function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function getRankingConfig() {
  const staticData = $getWorkflowStaticData('global');
  return staticData.rankingConfig || {};
}

const resumeKeyByBucket = {
  systems: 'systems_resume_text',
  mechanical: 'mechanical_resume_text',
  controls: 'controls_resume_text',
};

const resumeKey = resumeKeyByBucket[BUCKET] || `${BUCKET}_resume_text`;
const cfg = getRankingConfig();
const resume = clean(cfg[resumeKey]);

if (!resume) {
  const found = Object.keys(cfg)
    .filter((key) => key.includes('resume'))
    .map((key) => `${key}=${cfg[key] ? 'set' : 'empty'}`)
    .join(', ');

  throw new Error(
    `Missing ${resumeKey} for ${BUCKET} pipeline. ` +
    `Add it to the config tab (key column). Resume fields seen: ${found || 'none'}`
  );
}

const promptTemplate =
  clean(cfg[`${BUCKET}_rank_prompt`]) ||
  clean(cfg.llm_rank_prompt) ||
  '';

return $input.all().map((item) => ({
  json: {
    ...(item.json || {}),
    _pipeline_bucket: BUCKET,
    _pipeline_resume: resume,
    _pipeline_rank_prompt: promptTemplate,
    _openai_model: clean(cfg.openai_model) || 'gpt-4o-mini',
  },
}));
