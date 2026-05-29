/**
 * n8n Code node — LinkedIn-only Gmail parser (24h fetch is handled by Gmail node query).
 * Output rows include title, company, discovery_url plus safe defaults.
 */

function stripHtml(html) {
  return (html || '')
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<[^>]+>/g, '\n')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function extractLinks(html) {
  const links = [];
  const re = /<a[^>]+href=["']([^"']+)["'][^>]*>/gi;
  let m;
  while ((m = re.exec(html || '')) !== null) {
    const href = m[1];
    if (/linkedin\.com\/jobs/i.test(href)) links.push(href);
  }
  return [...new Set(links)];
}

function pickLinkedInProvider(from) {
  return /linkedin/i.test(String(from || '')) ? 'linkedin_email' : 'email_alert';
}

function base(fields) {
  return {
    found_at: new Date().toISOString(),
    status: 'needs_jd',
    needs_manual_jd: true,
    source: 'linkedin_email',
    apply_url: '',
    description: '',
    fetch_mode: 'gmail_linkedin',
    timestamp_confidence: 'medium',
    ...fields,
  };
}

const out = [];

for (const item of $input.all()) {
  const from = item.json.from?.text || item.json.from || '';
  const subject = item.json.subject || 'LinkedIn alert';
  const html = item.json.html || item.json.textHtml || '';
  const text = stripHtml(html);
  const links = extractLinks(html);
  const provider = pickLinkedInProvider(from);

  // Heuristic parse of "Company" then "Title · Location" lines
  const lines = text.split('\n').map((l) => l.trim()).filter(Boolean);
  let parsedCount = 0;

  for (let i = 0; i < lines.length - 1; i++) {
    const locMatch = lines[i + 1].match(/^(.+?)\s*·\s*(.+)$/);
    if (!locMatch) continue;
    const company = lines[i];
    const title = locMatch[1];
    const location = locMatch[2];
    if (!title || !company) continue;
    if (company.length > 80 || title.length > 140) continue;

    out.push({
      json: base({
        source: provider,
        title,
        company,
        location,
        discovery_url: links[parsedCount % Math.max(links.length, 1)] || '',
        snippet: `${title} at ${company}`,
      }),
    });
    parsedCount += 1;
  }

  // Fallback row when parse is partial/failed
  if (parsedCount === 0) {
    out.push({
      json: base({
        source: provider,
        title: subject,
        company: 'Unknown',
        location: '',
        discovery_url: links[0] || '',
        snippet: text.slice(0, 500),
      }),
    });
  }
}

return out.length ? out : [{ json: base({ title: 'No LinkedIn alerts found', company: 'N/A' }) }];
