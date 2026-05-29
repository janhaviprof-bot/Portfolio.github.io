/**
 * n8n Code node — Workflow B
 * Rank jobs in one bucket against the matching resume using OpenAI.
 *
 * Set BUCKET + RESUME_CONFIG_KEY for each pipeline copy:
 *   systems   -> systems_resume_text
 *   mechanical -> mechanical_resume_text
 *   controls  -> controls_resume_text
 */

const BUCKET = 'systems';
const RESUME_CONFIG_KEY = 'systems_resume_text';

function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function truncate(text, maxLen) {
  const value = clean(text);
  if (value.length <= maxLen) return value;
  return `${value.slice(0, maxLen)}…`;
}

function parseJsonObject(raw) {
  const text = clean(raw);
  if (!text) return null;

  try {
    return JSON.parse(text);
  } catch (error) {}

  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return null;

  try {
    return JSON.parse(match[0]);
  } catch (error) {
    return null;
  }
}

function buildPrompt(template, vars) {
  let prompt = template || '';

  for (const [key, value] of Object.entries(vars)) {
    prompt = prompt.split(`{{${key}}}`).join(String(value ?? ''));
  }

  return prompt;
}

const defaultPrompt = `You are a hiring match evaluator.

Compare the candidate resume to the job posting.
Return ONLY valid JSON with this shape:
{
  "score": 0,
  "rank_reason": "short explanation"
}

Rules:
- score is an integer from 0 to 100 (100 = excellent match)
- rank_reason is 1-3 sentences, concrete and specific
- penalize missing must-have skills in the JD
- ignore citizenship / clearance / ITAR requirements in scoring

Bucket: {{bucket}}
Job title: {{title}}
Company: {{company}}
Location: {{location}}

Job description:
{{full_jd}}

Candidate resume:
{{resume}}`;

function getRankingConfig() {
  const staticData = $getWorkflowStaticData('global');
  return staticData.rankingConfig || {};
}

const cfg = getRankingConfig();
const jobs = $input.all();

if (!jobs.length) {
  return [];
}

const sample = jobs[0].json || {};
const apiKey = clean($env.OPENAI_API_KEY || cfg.openai_api_key);
const model = clean(sample._openai_model || cfg.openai_model) || 'gpt-4o-mini';
const resume = clean(sample._pipeline_resume || cfg[RESUME_CONFIG_KEY]);
const promptTemplate =
  clean(sample._pipeline_rank_prompt) ||
  clean(cfg[`${BUCKET}_rank_prompt`]) ||
  clean(cfg.llm_rank_prompt) ||
  defaultPrompt;

if (!apiKey) {
  throw new Error('Missing OPENAI_API_KEY in n8n env or config tab.');
}

if (!resume) {
  throw new Error(
    `Missing resume for ${BUCKET} pipeline. ` +
    `Check Filter ${BUCKET} bucket and Validate config nodes ran successfully.`
  );
}

const out = [];

for (const item of jobs) {
  const job = { ...(item.json || {}) };
  const title = clean(job.title);
  const company = clean(job.company);
  const location = clean(job.location);
  const fullJd = truncate(job.full_jd || job.description || '', 12000);

  const userPrompt = buildPrompt(promptTemplate, {
    bucket: BUCKET,
    title,
    company,
    location,
    full_jd: fullJd || '(no job description provided)',
    resume: truncate(resume, 12000),
  });

  let parsed = null;
  let rankError = '';

  try {
    const response = await this.helpers.httpRequest({
      method: 'POST',
      url: 'https://api.openai.com/v1/chat/completions',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: {
        model,
        temperature: 0.2,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: 'You score resume-to-job fit. Respond with JSON only.',
          },
          {
            role: 'user',
            content: userPrompt,
          },
        ],
      },
      json: true,
      timeout: 120000,
    });

    const content = response?.choices?.[0]?.message?.content || '';
    parsed = parseJsonObject(content);
  } catch (error) {
    rankError = clean(error.message || error);
  }

  let score = Number(parsed?.score);
  if (!Number.isFinite(score)) score = 0;
  score = Math.max(0, Math.min(100, Math.round(score)));

  const rankReason = clean(parsed?.rank_reason || rankError || 'No rank reason returned');

  out.push({
    json: {
      ...job,
      bucket_selected: BUCKET,
      score,
      rank_reason: rankReason,
      status: rankError ? 'rank_error' : 'ranked',
      ranked_at: new Date().toISOString(),
    },
  });
}

return out;
