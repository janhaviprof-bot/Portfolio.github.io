/**
 * n8n Code node — map parsed Gmail rows to jobs schema with safe defaults.
 */

function uuid() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID();
  return `job_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
}

return $input.all().map((item) => {
  const j = { ...item.json };
  const now = new Date().toISOString();

  j.id = j.id || uuid();
  j.found_at = j.found_at || now;
  j.status = j.status || 'needs_jd';
  j.title = (j.title || '').toString().trim() || 'Unknown title';
  j.company = (j.company || '').toString().trim() || 'Unknown';
  j.location = (j.location || '').toString().trim();
  j.source = j.source || 'linkedin_email';
  j.discovery_url = (j.discovery_url || '').toString().trim();
  j.apply_url = (j.apply_url || '').toString().trim();
  j.posted_at = j.posted_at || '';
  j.updated_at = j.updated_at || now;
  j.timestamp_confidence = j.timestamp_confidence || 'low';
  j.fetch_mode = j.fetch_mode || 'gmail_linkedin';
  j.snippet = j.snippet || '';
  j.description = j.description || '';
  j.full_jd = j.full_jd || '';
  j.needs_manual_jd = j.needs_manual_jd !== undefined ? j.needs_manual_jd : true;
  j.apply_hint = j.apply_hint || '';
  j.normalized_apply_url = j.normalized_apply_url || '';
  j.dedupe_status = j.dedupe_status || 'unique';
  j.merged_sources = j.merged_sources || '';
  j.bucket_selected = j.bucket_selected || '';
  j.systems_score = j.systems_score || '';
  j.systems_rank_reason = j.systems_rank_reason || '';
  j.mechanical_score = j.mechanical_score || '';
  j.mechanical_rank_reason = j.mechanical_rank_reason || '';
  j.controls_score = j.controls_score || '';
  j.controls_rank_reason = j.controls_rank_reason || '';
  j.score = j.score || '';
  j.rank_reason = j.rank_reason || '';
  j.systems_ai_summary = j.systems_ai_summary || '';
  j.mechanical_ai_summary = j.mechanical_ai_summary || '';
  j.controls_ai_summary = j.controls_ai_summary || '';

  return { json: j };
});
