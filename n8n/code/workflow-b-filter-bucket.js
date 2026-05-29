/**
 * n8n Code node — Workflow B
 * Set BUCKET below to: systems | mechanical | controls
 */

const BUCKET = 'systems';

function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function cleanResume(value) {
  return String(value ?? '').trim();
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

function readConfigValueFromTab(configKey) {
  const wanted = clean(configKey).toLowerCase();
  try {
    for (const item of $('Read config tab B').all()) {
      const key = clean(String(item.json?.key || '')).toLowerCase();
      if (key !== wanted) continue;
      const raw = item.json?.value;
      if (raw !== undefined && raw !== null && String(raw).trim()) {
        return cleanResume(raw);
      }
    }
  } catch (error) {}

  return '';
}

function readResumeFromConfigTab(resumeKey) {
  return readConfigValueFromTab(resumeKey);
}

function getJdScorePrompt(cfg) {
  const fromStore = cleanResume(cfg.jd_score_prompt || cfg.llm_rank_prompt || '');
  if (fromStore) return fromStore;

  const fromSheet = readConfigValueFromTab('jd_score_prompt');
  if (fromSheet) {
    const staticData = $getWorkflowStaticData('global');
    if (!staticData.rankingConfig) staticData.rankingConfig = {};
    staticData.rankingConfig.jd_score_prompt = fromSheet;
    return fromSheet;
  }

  return readConfigValueFromTab('llm_rank_prompt');
}

function getResumeForBucket(bucket) {
  const resumeKey = resumeKeyByBucket[bucket] || `${bucket}_resume_text`;
  const cfg = getRankingConfig();
  let resume = cleanResume(cfg[resumeKey]);

  if (!resume) {
    resume = readResumeFromConfigTab(resumeKey);
    if (resume) {
      const staticData = $getWorkflowStaticData('global');
      if (!staticData.rankingConfig) staticData.rankingConfig = {};
      staticData.rankingConfig[resumeKey] = resume;
    }
  }

  return { resumeKey, resume, cfg };
}

const bucketJobs = $input.all().filter((item) => {
  const selected = clean(item.json?.bucket_selected).toLowerCase();
  return selected === BUCKET;
});

if (!bucketJobs.length) {
  return [];
}

const { resumeKey, resume, cfg } = getResumeForBucket(BUCKET);

if (!resume) {
  const staticCfg = getRankingConfig();
  const found = Object.keys(staticCfg)
    .filter((key) => key.includes('resume'))
    .map((key) => `${key}=${staticCfg[key] ? 'set' : 'empty'}`)
    .join(', ');

  throw new Error(
    `Missing ${resumeKey} for ${BUCKET} pipeline. ` +
    `Resume fields in staticData: ${found || 'none'}. ` +
    'Run full workflow from Start (not this node alone). ' +
    'Confirm config tab row exists with resume text in column B.'
  );
}

const promptTemplate = getJdScorePrompt(cfg);

if (!promptTemplate) {
  throw new Error(
    'Missing jd_score_prompt in config tab (column A key, column B value). ' +
    'Add a row: key=jd_score_prompt, value=<your scoring prompt>.'
  );
}

return bucketJobs.map((item) => ({
  json: {
    ...(item.json || {}),
    _pipeline_bucket: BUCKET,
    _pipeline_resume: resume,
    _pipeline_rank_prompt: promptTemplate,
    _openai_model: clean(cfg.openai_model) || 'gpt-4o-mini',
  },
}));
