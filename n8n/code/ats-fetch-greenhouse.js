/**
 * n8n Code node — fetch Greenhouse jobs for one company row.
 * Input: { company, slug, ats_type: greenhouse }
 * Uses HTTP Request node before this OR fetch inside Code (n8n allows $helpers.httpRequest in some versions).
 * This version expects previous HTTP node attached; maps jobs array from json body.
 */

const HOURS_24 = 24 * 60 * 60 * 1000;

function stripHtml(html) {
  return (html || '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
}

const company = $json.company || '';
const jobs = $json.jobs || $json.body?.jobs || [];

return jobs.map((job) => {
  const updated = job.updated_at ? new Date(job.updated_at).getTime() : 0;
  const recent = updated && Date.now() - updated <= HOURS_24;

  return {
    json: {
      found_at: new Date().toISOString(),
      status: 'new',
      needs_manual_jd: false,
      title: job.title,
      company,
      location: job.location?.name || '',
      source: 'greenhouse',
      discovery_url: job.absolute_url,
      apply_url: job.absolute_url,
      description: stripHtml(job.content || ''),
      posted_at: job.updated_at || '',
      updated_at: job.updated_at || '',
      timestamp_confidence: recent ? 'high' : 'medium',
      fetch_mode: 'single_call',
    },
  };
});
