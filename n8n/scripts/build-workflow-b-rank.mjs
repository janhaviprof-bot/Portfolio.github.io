import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');

function readCode(file) {
  return fs.readFileSync(path.join(root, 'code', file), 'utf8');
}

function bucketFilterCode(bucket) {
  return readCode('workflow-b-filter-bucket.js').replace(
    /const BUCKET = '(systems|mechanical|controls)';/,
    `const BUCKET = '${bucket}';`
  );
}

function rankCode(bucket, resumeKey) {
  return readCode('workflow-b-rank-openai.js')
    .replace(/const BUCKET = '(systems|mechanical|controls)';/, `const BUCKET = '${bucket}';`)
    .replace(
      /const RESUME_CONFIG_KEY = '(systems|mechanical|controls)_resume_text';/,
      `const RESUME_CONFIG_KEY = '${resumeKey}';`
    );
}

const code = {
  storeConfig: readCode('workflow-b-store-config.js'),
  validateConfig: readCode('workflow-b-validate-config.js'),
  filterRestricted: readCode('workflow-b-filter-restricted.js'),
  sortByScore: readCode('workflow-b-sort-by-score.js'),
  buildEmail: readCode('workflow-b-build-apply-email.js'),
};

const sheetsCred = {
  googleSheetsOAuth2Api: { id: '47TfMO6C0R1sbaT0', name: 'Google Sheets account' },
};
const gmailCred = { gmailOAuth2: { id: 'IS6FuPHVZoQYUNSp', name: 'Gmail account' } };

const docExpr = "={{ $('Set Config B').first().json.spreadsheetId }}";

function gsClearNode(id, name, sheet, pos) {
  return {
    parameters: {
      operation: 'clear',
      documentId: { __rl: true, value: docExpr, mode: 'id' },
      sheetName: { __rl: true, value: sheet, mode: 'name' },
      keepFirstRow: true,
    },
    id,
    name,
    type: 'n8n-nodes-base.googleSheets',
    typeVersion: 4.5,
    position: pos,
    executeOnce: true,
    credentials: sheetsCred,
  };
}

function gsReadNode(id, name, sheet, pos) {
  return {
    parameters: {
      operation: 'read',
      documentId: { __rl: true, value: docExpr, mode: 'id' },
      sheetName: { __rl: true, value: sheet, mode: 'name' },
      options: {},
    },
    id,
    name,
    type: 'n8n-nodes-base.googleSheets',
    typeVersion: 4.5,
    position: pos,
    executeOnce: true,
    credentials: sheetsCred,
  };
}

function codeNode(id, name, jsCode, pos, mode = 'runOnceForAllItems') {
  return {
    parameters: { mode, jsCode },
    id,
    name,
    type: 'n8n-nodes-base.code',
    typeVersion: 2,
    position: pos,
  };
}

function gsAppendNode(id, name, sheet, pos) {
  return {
    parameters: {
      operation: 'append',
      documentId: { __rl: true, value: docExpr, mode: 'id' },
      sheetName: { __rl: true, value: sheet, mode: 'name' },
      columns: {
        mappingMode: 'defineBelow',
        value: {
          rank: '={{ $json.rank }}',
          score: '={{ $json.score }}',
          rank_reason: '={{ $json.rank_reason }}',
          title: '={{ $json.title }}',
          company: '={{ $json.company }}',
          location: '={{ $json.location }}',
          source: '={{ $json.source }}',
          discovery_url: '={{ $json.discovery_url }}',
          apply_url: '={{ $json.apply_url }}',
          posted_at: '={{ $json.posted_at }}',
          full_jd: '={{ $json.full_jd }}',
          bucket_selected: '={{ $json.bucket_selected }}',
          status: '={{ $json.status }}',
          id: '={{ $json.id || $now.toMillis().toString() + "-" + $itemIndex }}',
        },
      },
      options: {},
    },
    id,
    name,
    type: 'n8n-nodes-base.googleSheets',
    typeVersion: 4.5,
    position: pos,
    credentials: sheetsCred,
    continueOnFail: true,
  };
}

function pipeline(bucket, resumeKey, y, ids) {
  return [
    codeNode(ids.filter, `Filter ${bucket} bucket`, bucketFilterCode(bucket), [520, y]),
    codeNode(ids.rank, `Rank ${bucket} jobs`, rankCode(bucket, resumeKey), [760, y]),
    codeNode(ids.sort, `Sort ${bucket} jobs`, code.sortByScore, [1000, y]),
    gsAppendNode(ids.append, `Write ranked_${bucket}`, `ranked_${bucket}`, [1240, y]),
  ];
}

const ids = {
  systems: { filter: 'b1', rank: 'b2', sort: 'b3', append: 'b4' },
  mechanical: { filter: 'b5', rank: 'b6', sort: 'b7', append: 'b8' },
  controls: { filter: 'b9', rank: 'b10', sort: 'b11', append: 'b12' },
};

const nodes = [
  {
    parameters: {},
    id: 'trig1',
    name: 'Start Workflow B',
    type: 'n8n-nodes-base.manualTrigger',
    typeVersion: 1,
    position: [-920, 420],
  },
  {
    parameters: {
      assignments: {
        assignments: [
          { name: 'spreadsheetId', value: '={{ $env.SPREADSHEET_ID }}', type: 'string' },
          { name: 'reminderEmail', value: '={{ $env.REMINDER_EMAIL }}', type: 'string' },
          { name: 'sheetUrl', value: '={{ $env.SHEET_URL }}', type: 'string' },
        ],
      },
      options: {},
    },
    id: 'cfg1',
    name: 'Set Config B',
    type: 'n8n-nodes-base.set',
    typeVersion: 3.4,
    position: [-700, 420],
  },
  gsReadNode('cfgread', 'Read config tab B', 'config', [-480, 320]),
  codeNode('storecfg', 'Store ranking config', code.storeConfig, [-280, 320]),
  codeNode('validcfg', 'Validate config', code.validateConfig, [-120, 320]),
  gsReadNode('jobsread', 'Read unique_jobs tab', 'unique_jobs', [-120, 520]),
  codeNode('filtrest', 'Filter restricted jobs', code.filterRestricted, [-40, 420]),
  gsClearNode('clr1', 'Clear ranked_systems', 'ranked_systems', [0, 120]),
  gsClearNode('clr2', 'Clear ranked_mechanical', 'ranked_mechanical', [0, 420]),
  gsClearNode('clr3', 'Clear ranked_controls', 'ranked_controls', [0, 720]),
  ...pipeline('systems', 'systems_resume_text', 120, ids.systems),
  ...pipeline('mechanical', 'mechanical_resume_text', 420, ids.mechanical),
  ...pipeline('controls', 'controls_resume_text', 720, ids.controls),
  {
    parameters: { numberInputs: 3 },
    id: 'merge1',
    name: 'Merge pipelines done',
    type: 'n8n-nodes-base.merge',
    typeVersion: 3,
    position: [1480, 420],
  },
  codeNode('email1', 'Build apply now email', code.buildEmail, [1700, 420]),
  {
    parameters: {
      sendTo: '={{ $json.to }}',
      subject: '={{ $json.subject }}',
      emailType: 'text',
      message: '={{ $json.message }}',
      options: {},
    },
    id: 'gmail1',
    name: 'Send apply now email',
    type: 'n8n-nodes-base.gmail',
    typeVersion: 2.1,
    position: [1920, 420],
    executeOnce: true,
    credentials: gmailCred,
  },
];

const connections = {
  'Start Workflow B': { main: [[{ node: 'Set Config B', type: 'main', index: 0 }]] },
  'Set Config B': {
    main: [[
      { node: 'Read config tab B', type: 'main', index: 0 },
      { node: 'Clear ranked_systems', type: 'main', index: 0 },
      { node: 'Clear ranked_mechanical', type: 'main', index: 0 },
      { node: 'Clear ranked_controls', type: 'main', index: 0 },
    ]],
  },
  'Read config tab B': {
    main: [[{ node: 'Store ranking config', type: 'main', index: 0 }]],
  },
    'Store ranking config': {
      main: [[{ node: 'Validate config', type: 'main', index: 0 }]],
    },
    'Validate config': {
      main: [[{ node: 'Read unique_jobs tab', type: 'main', index: 0 }]],
    },
  'Read unique_jobs tab': {
    main: [[{ node: 'Filter restricted jobs', type: 'main', index: 0 }]],
  },
  'Filter restricted jobs': {
    main: [[
      { node: 'Filter systems bucket', type: 'main', index: 0 },
      { node: 'Filter mechanical bucket', type: 'main', index: 0 },
      { node: 'Filter controls bucket', type: 'main', index: 0 },
    ]],
  },
  'Filter systems bucket': { main: [[{ node: 'Rank systems jobs', type: 'main', index: 0 }]] },
  'Rank systems jobs': { main: [[{ node: 'Sort systems jobs', type: 'main', index: 0 }]] },
  'Sort systems jobs': { main: [[{ node: 'Write ranked_systems', type: 'main', index: 0 }]] },
  'Write ranked_systems': { main: [[{ node: 'Merge pipelines done', type: 'main', index: 0 }]] },
  'Filter mechanical bucket': { main: [[{ node: 'Rank mechanical jobs', type: 'main', index: 0 }]] },
  'Rank mechanical jobs': { main: [[{ node: 'Sort mechanical jobs', type: 'main', index: 0 }]] },
  'Sort mechanical jobs': { main: [[{ node: 'Write ranked_mechanical', type: 'main', index: 0 }]] },
  'Write ranked_mechanical': { main: [[{ node: 'Merge pipelines done', type: 'main', index: 1 }]] },
  'Filter controls bucket': { main: [[{ node: 'Rank controls jobs', type: 'main', index: 0 }]] },
  'Rank controls jobs': { main: [[{ node: 'Sort controls jobs', type: 'main', index: 0 }]] },
  'Sort controls jobs': { main: [[{ node: 'Write ranked_controls', type: 'main', index: 0 }]] },
  'Write ranked_controls': { main: [[{ node: 'Merge pipelines done', type: 'main', index: 2 }]] },
  'Merge pipelines done': { main: [[{ node: 'Build apply now email', type: 'main', index: 0 }]] },
  'Build apply now email': { main: [[{ node: 'Send apply now email', type: 'main', index: 0 }]] },
};

function writeWorkflow(name, fileName) {
  const wf = {
    name,
    nodes,
    connections,
    active: false,
    settings: { executionOrder: 'v1' },
    meta: { templateCredsSetupCompleted: true },
  };
  const outPath = path.join(root, 'workflows', fileName);
  fs.writeFileSync(outPath, JSON.stringify(wf, null, 2));
  console.log(`Wrote ${outPath} (${nodes.length} nodes)`);
}

writeWorkflow('workflow-b-rank', 'workflow-b-rank.json');
writeWorkflow('PipelineB', 'PipelineB.json');
