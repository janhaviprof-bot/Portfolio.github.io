/**
 * n8n Code node — read companies tab rows, derive ats_type + slug from career_page_url.
 * Input: rows from Google Sheets (companies tab) with company, career_page_url, ats_type, enabled
 */

function inferAtsType(url) {
  try {
    const u = new URL(url);
    const host = u.hostname.toLowerCase();
    const path = u.pathname;

    if (host.includes('greenhouse.io')) return 'greenhouse';
    if (host.includes('lever.co')) return 'lever';
    if (host.includes('recruitee.com')) return 'recruitee';
    if (host.includes('ashbyhq.com')) return 'ashby';
    if (host.includes('smartrecruiters.com')) return 'smartrecruiters';
    if (host.includes('bamboohr.com')) return 'bamboohr';
    if (host.includes('myworkdayjobs.com')) return 'workday';
    if (host.includes('icims.com')) return 'icims';
  } catch {
    return '';
  }
  return '';
}

function deriveSlug(url, atsType) {
  try {
    const u = new URL(url);
    const parts = u.pathname.split('/').filter(Boolean);

    switch (atsType) {
      case 'greenhouse':
        // boards.greenhouse.io/{token}/...
        if (u.hostname.includes('boards-api.')) return parts[1] || parts[0];
        return parts[0];
      case 'lever':
        return parts[0];
      case 'recruitee':
        return u.hostname.split('.')[0];
      case 'ashby':
        return parts[0];
      case 'smartrecruiters':
        return parts[0];
      default:
        return '';
    }
  } catch {
    return '';
  }
}

return $input.all()
  .filter((item) => {
    const e = item.json.enabled;
    return e === true || e === 'TRUE' || e === 'true' || e === '1' || e === 1;
  })
  .map((item) => {
    const j = { ...item.json };
    const url = j.career_page_url || j.endpoint || '';
    const manualType = (j.ats_type || '').trim().toLowerCase();
    const atsType = manualType || inferAtsType(url);
    const slug = (j.slug || '').trim() || deriveSlug(url, atsType);

    return {
      json: {
        ...j,
        ats_type: atsType,
        slug,
        last_fetch_status: atsType && slug ? 'ready' : 'needs_config',
      },
    };
  });
