/**
 * n8n Code node — bucket eligibility, per-bucket scores, single bucket_selected.
 * Processes rows with status = ready (or new with description for ATS).
 * Effective JD = description || full_jd
 */

const CONFIG = {
  systemsTitles: ['systems engineer', 'system engineer'],
  systemsJd: ['mbse'],
  mechanicalTitle: ['mechanical'],
  mechanicalTitleExtra: ['engineer', 'design'],
  mechanicalJd: ['mechanical engineering', 'mechanical design'],
  controlsTitle: [
    'control system engineer',
    'control systems engineer',
    'controls engineer',
  ],
  controlsTitleBroad: ['control', 'controls'],
  controlsJd: ['control systems', 'controls', 'feedback', 'plc', 'instrumentation'],
};

function norm(s) {
  return (s || '').toString().toLowerCase();
}

function includesAny(text, phrases) {
  const t = norm(text);
  return phrases.some((p) => t.includes(p));
}

function scoreBucket(title, jd, rules) {
  let score = 0;
  const reasons = [];

  if (rules.titleMatch && rules.titleMatch(title)) {
    score += 30;
    reasons.push('title_match');
  }
  if (rules.jdMatch && jd && rules.jdMatch(jd)) {
    score += 25;
    reasons.push('jd_match');
  }
  if (rules.titleOnly && rules.titleOnly(title) && !jd) {
    score += 10;
    reasons.push('title_only_no_jd');
  }

  return { score, rank_reason: reasons.join(',') };
}

function eligibleSystems(title, jd) {
  const titleOk = includesAny(title, CONFIG.systemsTitles);
  if (!titleOk) return false;
  if (!jd || !jd.trim()) return true; // title-only until JD pasted
  return includesAny(jd, CONFIG.systemsJd);
}

function eligibleMechanical(title, jd) {
  const t = norm(title);
  if (CONFIG.mechanicalTitle.some((k) => t.includes(k)) &&
      CONFIG.mechanicalTitleExtra.some((k) => t.includes(k))) {
    return true;
  }
  return jd && includesAny(jd, CONFIG.mechanicalJd);
}

function eligibleControls(title, jd) {
  if (includesAny(title, CONFIG.controlsTitle)) return true;
  const t = norm(title);
  if (CONFIG.controlsTitleBroad.some((k) => t.includes(k)) && t.includes('system')) return true;
  return jd && includesAny(jd, CONFIG.controlsJd);
}

return $input.all().map((item) => {
  const j = { ...item.json };
  const title = j.title || '';
  const jd = (j.description || j.full_jd || '').trim();

  const systems = eligibleSystems(title, jd)
    ? scoreBucket(title, jd, {
        titleMatch: (t) => includesAny(t, CONFIG.systemsTitles),
        jdMatch: (d) => includesAny(d, CONFIG.systemsJd),
        titleOnly: (t) => includesAny(t, CONFIG.systemsTitles),
      })
    : { score: 0, rank_reason: 'ineligible' };

  const mechanical = eligibleMechanical(title, jd)
    ? scoreBucket(title, jd, {
        titleMatch: (t) => norm(t).includes('mechanical'),
        jdMatch: (d) => includesAny(d, CONFIG.mechanicalJd),
      })
    : { score: 0, rank_reason: 'ineligible' };

  const controls = eligibleControls(title, jd)
    ? scoreBucket(title, jd, {
        titleMatch: (t) => eligibleControls(t, ''),
        jdMatch: (d) => includesAny(d, CONFIG.controlsJd),
      })
    : { score: 0, rank_reason: 'ineligible' };

  j.systems_score = systems.score;
  j.systems_rank_reason = systems.rank_reason;
  j.mechanical_score = mechanical.score;
  j.mechanical_rank_reason = mechanical.rank_reason;
  j.controls_score = controls.score;
  j.controls_rank_reason = controls.rank_reason;

  const candidates = [
    { id: 'systems', score: systems.score },
    { id: 'controls', score: controls.score },
    { id: 'mechanical', score: mechanical.score },
  ].filter((c) => c.score > 0);

  const priority = { systems: 3, controls: 2, mechanical: 1 };
  candidates.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return priority[b.id] - priority[a.id];
  });

  const winner = candidates[0];
  j.bucket_selected = winner ? winner.id : 'none';
  j.score = winner ? winner.score : 0;
  j.rank_reason = winner
    ? j[`${winner.id}_rank_reason`]
    : 'no_bucket';
  j.status = 'ranked';

  return { json: j };
});
