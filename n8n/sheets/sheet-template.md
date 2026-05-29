# Google Sheet template

Create one spreadsheet with tabs: `jobs`, `unique_jobs`, `ranked_systems`, `ranked_mechanical`, `ranked_controls`, `companies`, `config`, `archive`.

The `archive` tab uses the **same headers as `jobs`** (copy row 1 from `jobs`).

## Tab: `jobs` (row 1 = headers)

```
id	found_at	status	title	company	location	source	discovery_url	apply_url	posted_at	updated_at	timestamp_confidence	fetch_mode	snippet	description	full_jd	needs_manual_jd	apply_hint	normalized_apply_url	dedupe_status	merged_sources	bucket_selected	systems_score	systems_rank_reason	mechanical_score	mechanical_rank_reason	controls_score	controls_rank_reason	score	rank_reason	systems_ai_summary	mechanical_ai_summary	controls_ai_summary
```

### Filter views (create in Google Sheets UI)

1. **Top Systems** — `bucket_selected` = `systems`, sort `systems_score` Z→A  
2. **Top Mechanical** — `bucket_selected` = `mechanical`, sort `mechanical_score` Z→A  
3. **Top Controls** — `bucket_selected` = `controls`, sort `controls_score` Z→A  
4. **Needs JD** — `needs_manual_jd` = `TRUE`, `status` = `needs_jd`  
5. **Ready to rank** — `status` = `ready`

## Tab: `unique_jobs`

Same headers as `jobs` (Workflow A output). Workflow B reads this tab.

## Tab: `ranked_systems` / `ranked_mechanical` / `ranked_controls`

Row 1 headers (same for all three ranked tabs):

```
rank	score	rank_reason	title	company	location	source	discovery_url	apply_url	posted_at	full_jd	bucket_selected	status	id
```

Sort in sheet by `rank` ascending (rank 1 = highest score) or `score` descending.

## Tab: `companies` (example rows)

| company | career_page_url | ats_type | slug | enabled | keyword_filter | department_filter | tier | last_fetch_status |
|---------|-----------------|----------|------|---------|----------------|-------------------|------|-------------------|
| Example Co (Greenhouse) | https://boards.greenhouse.io/example | greenhouse | example | TRUE | | | 1 | |
| Example Co (Lever) | https://jobs.lever.co/example | lever | example | TRUE | | | 1 | |
| Example Co (Recruitee) | https://example.recruitee.com | recruitee | example | TRUE | | | 1 | |

Replace with real career page URLs. Leave `ats_type` / `slug` empty to auto-derive in Workflow A.

## Tab: `config` (key / value columns)

**Important:** Row 1 must be headers `key` and `value` in columns A and B. Workflow B reads this tab with Google Sheets operation **read**; resume rows must use exact keys below (paste full resume text in column B, not a link).

| key | value |
|-----|-------|
| systems_title_references | Systems Engineer, Systems Integration Engineer, MBSE Engineer |
| mechanical_title_references | Mechanical Engineer, Mechanical Design Engineer |
| controls_title_references | Control Systems Engineer, Controls Engineer, GNC Engineer |
| title_similarity_threshold | 0.35 |
| similarity_method | tfidf |
| systems_jd_keywords | MBSE |
| mechanical_jd_keywords | mechanical engineering, mechanical design |
| controls_jd_keywords | control systems, PLC, feedback, instrumentation |
| openai_model | gpt-4o-mini |
| llm_rank_provider | openai |
| llm_rank_prompt | (your rubric: score 0-100, rank_reason, optional ai_summary) |
| blocklist | ITAR, export control, US citizen, citizenship required, secret clearance |
| systems_resume_text | (paste full systems engineering resume) |
| mechanical_resume_text | (paste full mechanical engineering resume) |
| controls_resume_text | (paste full controls engineering resume) |
| systems_rank_prompt | (optional custom OpenAI prompt; supports {{resume}} {{title}} {{company}} {{location}} {{full_jd}} {{bucket}}) |
| mechanical_rank_prompt | (optional) |
| controls_rank_prompt | (optional) |
| location_preferences | |
| sheet_url | (paste your Sheet URL for reminder emails) |
| reminder_email | (your email) |
