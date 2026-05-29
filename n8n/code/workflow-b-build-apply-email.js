/**
 * n8n Code node — Workflow B
 * One summary email after all 3 ranking pipelines finish.
 */

function clean(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function getRows(nodeName) {
  try {
    return $(nodeName).all();
  } catch (error) {
    return [];
  }
}

function topLines(rows, limit) {
  return rows
    .slice(0, limit)
    .map((item, index) => {
      const job = item.json || {};
      return `${index + 1}. [${Number(job.score) || 0}] ${clean(job.title)} @ ${clean(job.company)}`;
    })
    .join('\n');
}

const config = $('Set Config B').first().json;
const systemsRows = getRows('Sort systems jobs');
const mechanicalRows = getRows('Sort mechanical jobs');
const controlsRows = getRows('Sort controls jobs');

const body = [
  'Your ranked apply lists are ready.',
  '',
  `Systems jobs ranked: ${systemsRows.length}`,
  topLines(systemsRows, 5) || '- none',
  '',
  `Mechanical jobs ranked: ${mechanicalRows.length}`,
  topLines(mechanicalRows, 5) || '- none',
  '',
  `Controls jobs ranked: ${controlsRows.length}`,
  topLines(controlsRows, 5) || '- none',
  '',
  'Open these tabs in your sheet:',
  '- ranked_systems',
  '- ranked_mechanical',
  '- ranked_controls',
  '',
  `Sheet: ${clean(config.sheetUrl)}`,
  '',
  'You can apply now.',
].join('\n');

return [{
  json: {
    to: clean(config.reminderEmail),
    subject: 'Ranked jobs ready — you can apply now',
    message: body,
  },
}];
