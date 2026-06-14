/**
 * n8n Code node — Fetch iCIMS job
 * Paste this entire file into the Fetch iCIMS job Code node.
 */

const DEBUG = false;

const DAY_MS = 26 * 60 * 60 * 1000;
const cutoff = Date.now() - DAY_MS;

function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function decodeHtml(value) {
  return String(value || '')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&mdash;/gi, '-')
    .replace(/&ndash;/gi, '-')
    .replace(/&rsquo;/gi, "'")
    .replace(/&lsquo;/gi, "'")
    .replace(/&rdquo;/gi, '"')
    .replace(/&ldquo;/gi, '"')
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/&#x([a-f0-9]+);/gi, (_, code) => String.fromCharCode(parseInt(code, 16)));
}

function stripHtml(html) {
  return decodeHtml(String(html || ''))
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|li|ul|ol|h1|h2|h3|h4|h5|h6|tr|dd|dt)>/gi, '\n')
    .replace(/<li[^>]*>/gi, '- ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\r/g, '\n')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n[ \t]+/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function isEnabled(value) {
  return value === true || value === 1 || ['true', '1', 'yes', 'y'].includes(clean(value).toLowerCase());
}

function getConfigValue(rows, key) {
  const row = rows.find((item) => clean(item.json.key).toLowerCase() === key);
  return clean(row?.json.value || '');
}

function splitTerms(value) {
  return clean(value)
    .split(/[,;|\n]/)
    .map((term) => clean(term).toLowerCase())
    .filter(Boolean);
}

function isIcimsRow(row) {
  const atsType = clean(row.ats_type).toLowerCase();
  const url = clean(row.career_page_url || row.endpoint).toLowerCase();
  return atsType === 'icims' || url.includes('.icims.com');
}

function normalizeUrl(url) {
  let raw = decodeHtml(clean(url));
  if (!raw) return '';

  raw = raw.split('#')[0];

  const parts = raw.split('?');
  const base = parts[0];
  const query = parts[1] || '';
  if (!query) return base;

  const removeParams = [
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'mode',
    'iis',
    'iisn',
    'mobile',
    'width',
    'height',
    'bga',
    'needsRedirect',
  ];

  const keptParams = query
    .split('&')
    .filter(Boolean)
    .filter((pair) => !removeParams.includes(pair.split('=')[0]));

  return keptParams.length ? `${base}?${keptParams.join('&')}` : base;
}

function getOrigin(url) {
  const match = clean(url).match(/^(https?:\/\/[^/]+)/i);
  return match ? match[1] : '';
}

function absolutizeUrl(url, baseUrl) {
  const raw = decodeHtml(clean(url));
  if (!raw) return '';

  if (/^https?:\/\//i.test(raw)) return normalizeUrl(raw);

  const origin = getOrigin(baseUrl);
  if (!origin) return raw;

  if (raw.startsWith('/')) return normalizeUrl(origin + raw);

  const basePath = clean(baseUrl).replace(/[#?].*$/, '').replace(/\/[^/]*$/, '/');
  return normalizeUrl(basePath + raw);
}

function getIcimsSearchBase(row) {
  const rawUrl = clean(row.career_page_url || row.endpoint);
  if (!rawUrl) return '';

  const noHash = rawUrl.split('#')[0];

  if (/\/jobs\/search/i.test(noHash)) return noHash.split('?')[0];

  const match = noHash.match(/^(https?:\/\/[^/]+)\/?/i);
  return match ? `${match[1]}/jobs/search` : '';
}

function buildSearchUrl(searchBase, page) {
  const base = clean(searchBase).split('?')[0];
  return `${base}?pr=${encodeURIComponent(String(page))}&searchRelation=keyword_all&in_iframe=1`;
}

function getBestMatch(title, terms) {
  let bestTerm = '';
  let bestScore = 0;

  for (const term of terms) {
    const score = titleSimilarity(title, term);
    if (score > bestScore) {
      bestScore = score;
      bestTerm = term;
    }
  }

  return { term: bestTerm, score: bestScore };
}

function matchesRole(title, terms, keywordTerms) {
  if (!terms.length) return false;

  const titleText = clean(title).toLowerCase();
  const best = getBestMatch(title, terms);
  if (best.score >= TITLE_THRESHOLD) return true;

  if (terms.some((term) => {
    const t = clean(term).toLowerCase();
    if (!t) return false;
    if (t.length >= 3 && titleText.includes(t)) return true;
    return tokenize(t).some((word) => word.length >= 3 && titleText.includes(word));
  })) {
    return true;
  }

  const keywords = Array.isArray(keywordTerms) ? keywordTerms : [];
  if (/engineer/i.test(titleText) && keywords.some((term) => {
    const t = clean(term).toLowerCase();
    return t && (titleText.includes(t) || tokenize(t).some((word) => word.length >= 3 && titleText.includes(word)));
  })) {
    return true;
  }

  return false;
}

function tokenize(value) {
  return clean(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .split(/\s+/)
    .filter((word) => word.length >= 3);
}

function jaccardSimilarity(a, b) {
  const aTokens = new Set(tokenize(a));
  const bTokens = new Set(tokenize(b));

  if (!aTokens.size || !bTokens.size) return 0;

  let intersection = 0;
  for (const token of aTokens) {
    if (bTokens.has(token)) intersection += 1;
  }

  const union = new Set([...aTokens, ...bTokens]).size;
  return intersection / union;
}

function titleSimilarity(title, reference) {
  const titleText = clean(title).toLowerCase();
  const referenceText = clean(reference).toLowerCase();

  if (!titleText || !referenceText) return 0;

  if (titleText.includes(referenceText) || referenceText.includes(titleText)) {
    return 1;
  }

  return jaccardSimilarity(titleText, referenceText);
}

function getBucket(title, buckets) {
  let bestBucket = '';
  let bestScore = 0;

  for (const bucket of buckets) {
    for (const referenceTitle of bucket.terms) {
      const score = titleSimilarity(title, referenceTitle);

      if (score > bestScore) {
        bestScore = score;
        bestBucket = bucket.name;
      }
    }
  }

  // Tune this if needed. 0.25 catches things like:
  // "Mechanical Commissioning Engineer" vs "Mechanical Engineer"
  // "Systems Integration Engineer" vs "Systems Engineer"
  return bestScore >= TITLE_THRESHOLD ? bestBucket : '';
}

function locationMatchesAllowedCountries(location, allowedCountries) {
  if (!allowedCountries.length) return true;

  const raw = clean(location);
  const value = raw.toLowerCase();
  if (!value) return false;

  const usStates = /\b(AL|AK|AZ|AR|CA|CO|CT|DE|FL|GA|HI|IA|ID|IL|IN|KS|KY|LA|MA|MD|ME|MI|MN|MO|MS|MT|NC|ND|NE|NH|NJ|NM|NV|NY|OH|OK|OR|PA|RI|SC|SD|TN|TX|UT|VA|VT|WA|WI|WV|WY|DC)\b/;

  function hasUsMarker(text) {
    const t = clean(text).toLowerCase();
    return (
      t.includes('united states') ||
      t.includes('usa') ||
      t.includes('u.s.') ||
      t.includes('united states of america') ||
      usStates.test(clean(text))
    );
  }

  const normalizedAllowed = allowedCountries.map((country) => clean(country).toLowerCase());
  const wantsUsa = normalizedAllowed.some((country) =>
    ['usa', 'us', 'u.s.', 'united states', 'united states of america'].includes(country)
  );

  const isRemoteLike = /\b(remote|hybrid|work from home|wfh|distributed)\b/i.test(value);
  if (isRemoteLike) {
    return wantsUsa ? hasUsMarker(raw) : normalizedAllowed.some((country) => value.includes(country));
  }

  if (wantsUsa && hasUsMarker(raw)) return true;

  if (normalizedAllowed.includes('uk')) {
    if (
      value.includes('united kingdom') ||
      value.includes('uk') ||
      value.includes('england') ||
      value.includes('scotland') ||
      value.includes('wales')
    ) {
      return true;
    }
  }

  if (normalizedAllowed.includes('canada')) {
    const canadaProvinces = /\b(ON|BC|QC|AB|MB|SK|NS|NB|NL|PE|YT|NT|NU)\b/;
    if (value.includes('canada') || canadaProvinces.test(raw)) return true;
  }

  return normalizedAllowed.some((country) => value.includes(country));
}

function parsePostedAt(value) {
  const raw = clean(value);
  if (!raw) return { timestamp: 0, display: '' };

  let timestamp = new Date(raw).getTime();

  if (Number.isNaN(timestamp)) {
    const relativeMatch = raw.toLowerCase().match(/(\d+)\s+(hour|hours|day|days)\s+ago/);
    if (relativeMatch) {
      const amount = Number(relativeMatch[1]);
      const unit = relativeMatch[2];
      timestamp = Date.now() - amount * (unit.startsWith('hour') ? 60 * 60 * 1000 : DAY_MS);
    }
  }

  if (Number.isNaN(timestamp)) return { timestamp: 0, display: raw };

  return { timestamp, display: raw };
}

function extractJobLinksFromSearch(html, baseUrl) {
  const links = new Set();
  const source = String(html || '');
  const hrefRegex = /href=["']([^"']*\/jobs\/\d+\/[^"']*)["']/gi;
  let match;

  while ((match = hrefRegex.exec(source)) !== null) {
    let url = absolutizeUrl(match[1], baseUrl);

    if (url && /\/jobs\/\d+\//i.test(url)) {
      // iCIMS needs in_iframe=1 to return the actual job detail content.
      if (!/[?&]in_iframe=1\b/i.test(url)) {
        url += url.includes('?') ? '&in_iframe=1' : '?in_iframe=1';
      }

      links.add(url);
    }
  }

  return [...links];
}

function extractJsonLd(html) {
  const source = String(html || '');
  const scripts = source.match(/<script[^>]*type=["']application\/ld\+json["'][^>]*>[\s\S]*?<\/script>/gi) || [];

  for (const script of scripts) {
    const jsonText = script
      .replace(/^<script[^>]*>/i, '')
      .replace(/<\/script>$/i, '')
      .trim();

    try {
      const data = JSON.parse(jsonText);
      if (data && (data.title || data.datePosted || data.jobLocation)) return data;
    } catch (error) {}
  }

  return {};
}

function extractBetween(html, patterns) {
  const source = String(html || '');

  for (const pattern of patterns) {
    const match = source.match(pattern);
    if (match?.[1]) return stripHtml(match[1]);
  }

  return '';
}

function extractHeaderField(html, label) {
  const source = String(html || '');
  const escapedLabel = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

  const patterns = [
    new RegExp(`<dt[^>]*>\\s*${escapedLabel}\\s*<\\/dt>\\s*<dd[^>]*>([\\s\\S]*?)<\\/dd>`, 'i'),
    new RegExp(`<span[^>]*class=["'][^"']*field-label[^"']*["'][^>]*>\\s*${escapedLabel}\\s*<\\/span>\\s*<span[^>]*>([\\s\\S]*?)<\\/span>`, 'i'),
  ];

  return extractBetween(source, patterns);
}

function extractTitle(html) {
  const jsonLd = extractJsonLd(html);

  return clean(
    jsonLd.title ||
    extractBetween(html, [
      /<h1[^>]*class=["'][^"']*(?:job-title|iCIMS_Header)[^"']*["'][^>]*>([\s\S]*?)<\/h1>/i,
      /<h1[^>]*>([\s\S]*?)<\/h1>/i,
      /property=["']og:title["'][^>]*content=["']([^"']+)["']/i,
      /<title[^>]*>([\s\S]*?)<\/title>/i,
    ]).replace(/\s+in\s+.*$/i, '').replace(/\s+-\s+.*$/i, '')
  );
}

function extractLocation(html) {
  const jsonLd = extractJsonLd(html);
  const locations = Array.isArray(jsonLd.jobLocation) ? jsonLd.jobLocation : [jsonLd.jobLocation].filter(Boolean);

  const jsonLocation = locations
    .map((loc) => {
      const address = loc?.address || loc || {};
      return clean([
        address.addressLocality,
        address.addressRegion,
        address.addressCountry,
      ].filter(Boolean).join(', '));
    })
    .filter(Boolean)
    .join(' | ');

  return clean(
    jsonLocation ||
    extractHeaderField(html, 'Location') ||
    extractHeaderField(html, 'Job Location') ||
    extractHeaderField(html, 'Job Location(s)') ||
    extractBetween(html, [
      /<span[^>]*class=["'][^"']*location[^"']*["'][^>]*>([\s\S]*?)<\/span>/i,
    ])
  );
}

function extractPostedAt(html) {
  const jsonLd = extractJsonLd(html);

  return clean(
    jsonLd.datePosted ||
    extractHeaderField(html, 'Posted Date') ||
    extractHeaderField(html, 'Date Posted') ||
    extractHeaderField(html, 'Posted') ||
    extractBetween(html, [
      /<span[^>]*title=["']([^"']+)["'][^>]*>\s*\d+\s+(?:hour|hours|day|days)\s+ago/i,
      /<span[^>]*class=["'][^"']*posted[^"']*["'][^>]*>([\s\S]*?)<\/span>/i,
    ])
  );
}

function extractFullJd(html) {
  const jsonLd = extractJsonLd(html);

  if (jsonLd.description) {
    return stripHtml(jsonLd.description);
  }

  return extractBetween(html, [
    /<h2[^>]*class=["'][^"']*iCIMS_InfoField_Job[^"']*["'][^>]*>[\s\S]*?<\/h2>\s*<div[^>]*class=["'][^"']*iCIMS_InfoMsg_Job[^"']*["'][^>]*>([\s\S]*?)<div[^>]*id=["']icims-social-share/i,
    /<div[^>]*class=["'][^"']*iCIMS_InfoMsg_Job[^"']*["'][^>]*>([\s\S]*?)<\/div>\s*<h2/i,
    /<div[^>]*class=["'][^"']*iCIMS_JobContent[^"']*["'][^>]*>([\s\S]*?)<div[^>]*id=["']icims-social-share/i,
    /<div[^>]*class=["'][^"']*iCIMS_JobContent[^"']*["'][^>]*>([\s\S]*?)<\/main>/i,
    /<section[^>]*class=["'][^"']*job-description[^"']*["'][^>]*>([\s\S]*?)<\/section>/i,
    /<div[^>]*id=["']job-description["'][^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]*class=["'][^"']*description[^"']*["'][^>]*>([\s\S]*?)<\/div>/i,
  ]);
}

function getCompaniesFromInput(isRow) {
  try {
    return $('Read companies tab').all().map((item) => item.json);
  } catch (error) {
    return $input.all().map((item) => item.json).filter((row) => isRow(row));
  }
}

function debugRow(title, company, discoveryUrl, message) {
  return {
    json: {
      title,
      company: company || '',
      location: '',
      apply_url: '',
      discovery_url: discoveryUrl || '',
      posted_at: '',
      needs_manual_jd: true,
      full_jd: message || '',
      status: 'debug',
      source: 'icims',
      bucket_selected: '',
      score: '',
      rank_reason: '',
    },
  };
}

const configRows = $('Read config tab').all();

const TITLE_THRESHOLD = (() => {
  const value = parseFloat(getConfigValue(configRows, 'title_similarity_threshold'));
  return Number.isFinite(value) && value > 0 && value <= 1 ? value : 0.1;
})();
const companies = getCompaniesFromInput(isIcimsRow);

const allowedCountries = splitTerms(getConfigValue(configRows, 'allowed_countries'));

const systemsTerms = [...splitTerms(getConfigValue(configRows, 'systems_title_references')), ...splitTerms(getConfigValue(configRows, 'systems_jd_keywords') || getConfigValue(configRows, 'systems_keywords'))];
const mechanicalTerms = [...splitTerms(getConfigValue(configRows, 'mechanical_title_references')), ...splitTerms(getConfigValue(configRows, 'mechanical_jd_keywords') || getConfigValue(configRows, 'mechanical_keywords'))];
const controlsTerms = [...splitTerms(getConfigValue(configRows, 'controls_title_references')), ...splitTerms(getConfigValue(configRows, 'controls_jd_keywords') || getConfigValue(configRows, 'controls_keywords'))];

const buckets = [
  { name: 'systems', terms: systemsTerms },
  { name: 'mechanical', terms: mechanicalTerms },
  { name: 'controls', terms: controlsTerms },
];

const configuredTerms = [...new Set([...systemsTerms, ...mechanicalTerms, ...controlsTerms])];

const keywordTerms = [...new Set([
  ...splitTerms(getConfigValue(configRows, 'systems_jd_keywords') || getConfigValue(configRows, 'systems_keywords')),
  ...splitTerms(getConfigValue(configRows, 'mechanical_jd_keywords') || getConfigValue(configRows, 'mechanical_keywords')),
  ...splitTerms(getConfigValue(configRows, 'controls_jd_keywords') || getConfigValue(configRows, 'controls_keywords')),
])];

const fallbackTerms = [
  'systems engineer',
  'system engineer',
  'mechanical engineer',
  'controls engineer',
  'control systems engineer',
  'automation engineer',
  'mechatronics engineer',
  'manufacturing engineer',
  'electrical engineer',
  'test engineer',
  'field service engineer',
];

const titleTerms = configuredTerms.length ? configuredTerms : fallbackTerms;
const icimsCompanies = companies.filter((row) => isEnabled(row.enabled) && isIcimsRow(row));

const out = [];

if (DEBUG) {
  out.push(debugRow(
    'DEBUG iCIMS input',
    '',
    '',
    `input_rows=${companies.length}; enabled_icims_rows=${icimsCompanies.length}; allowed_countries=${allowedCountries.join(', ')}; strict_26h=true`
  ));
}

for (const companyRow of icimsCompanies) {
  const company = clean(companyRow.company);
  const searchBase = getIcimsSearchBase(companyRow);

  if (!searchBase) continue;

  const jobLinks = new Set();

  for (let page = 0; ; page++) {
    const searchUrl = buildSearchUrl(searchBase, page);

    let html = '';
    try {
      html = await this.helpers.httpRequest({
        method: 'GET',
        url: searchUrl,
        headers: {
          Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent': 'Mozilla/5.0',
        },
        timeout: 30000,
      });
    } catch (error) {
      if (DEBUG) out.push(debugRow(`iCIMS search failed: ${company}`, company, searchUrl, clean(error.message || error)));
      break;
    }

    const links = extractJobLinksFromSearch(html, searchUrl);
    links.forEach((link) => jobLinks.add(link));

    if (!links.length) break;
  }

  if (DEBUG) {
    out.push(debugRow(`DEBUG iCIMS links: ${company}`, company, searchBase, `links_found=${jobLinks.size}`));
  }

  const skip = {
    noTitle: 0,
    role: 0,
    location: 0,
    date: 0,
    fetch: 0,
  };

  let emitted = 0;

  for (const jobUrl of jobLinks) {
    let detailHtml = '';

    try {
      detailHtml = await this.helpers.httpRequest({
        method: 'GET',
        url: jobUrl,
        headers: {
          Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent': 'Mozilla/5.0',
        },
        timeout: 30000,
      });
    } catch (error) {
      skip.fetch += 1;
      continue;
    }

    const title = extractTitle(detailHtml);
    if (!title) {
      skip.noTitle += 1;
      continue;
    }

    if (!matchesRole(title, titleTerms, keywordTerms)) {
      skip.role += 1;
      continue;
    }

    const location = extractLocation(detailHtml);
    if (!locationMatchesAllowedCountries(location, allowedCountries)) {
      skip.location += 1;
      continue;
    }

    const posted = parsePostedAt(extractPostedAt(detailHtml));
    if (!posted.timestamp || posted.timestamp < cutoff) {
      skip.date += 1;
      continue;
    }

    const fullJd = extractFullJd(detailHtml);
    const bucketSelected = getBucket(title, buckets);

    emitted += 1;

    out.push({
      json: {
        title,
        company,
        location,
        apply_url: jobUrl,
        discovery_url: jobUrl,
        posted_at: posted.display,
        needs_manual_jd: !fullJd,
        full_jd: fullJd,
        status: fullJd ? 'ready' : 'needs_jd',
        source: 'icims',
        bucket_selected: bucketSelected,
        score: '',
        rank_reason: '',
      },
    });
  }

  if (DEBUG) {
    out.push(debugRow(
      `DEBUG iCIMS parsed: ${company}`,
      company,
      searchBase,
      `emitted=${emitted}; skipped_fetch=${skip.fetch}; skipped_no_title=${skip.noTitle}; skipped_role=${skip.role}; skipped_location=${skip.location}; skipped_date=${skip.date}`
    ));
  }
}

return out;
