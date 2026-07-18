# Case Study — RA-CS-003 (draft)

## CMS field: Title
Critical Minerals Market Intelligence

## CMS field: Subtitle / one-line summary
A Snowflake data warehouse and Power BI reporting layer tracking price, production, and supply concentration across four critical battery minerals.

## CMS field: Client
**Internal capability build — not a named client engagement.** (Flag: this is the honest label to use. Do not present as a delivered client project; see note at bottom.)

## CMS field: Industry
Mining & Critical Minerals — **new tag, not currently in the Industries collection.** Needs adding, or this case study sits outside the industry filter until it does. Flagging rather than deciding silently, since Industries is a structural CMS collection you've been particular about.

## CMS field: Expertise area tags
Data Foundation, Data Automation

## CMS field: Headline stats (for homepage/case-study card treatment, matching the Apex "250 distributors / 7 product categories" pattern)
- 4 commodities tracked — Lithium, Graphite, Manganese, Cobalt
- 14 producing countries modeled across supply chains
- 3-schema warehouse (raw → core → reporting) built for least-privilege BI access

## CMS field: Challenge
Procurement and strategy teams tracking battery-grade minerals typically pull price and supply data from scattered sources — exchange feeds, government trade data, individual mine disclosures — with no shared warehouse and no live reporting layer. Analysts rebuild the same spreadsheet every reporting cycle, and supply-concentration risk (a single country or supplier dominating a mineral's production) is easy to miss without a purpose-built view.

## CMS field: Approach
RUSA built a three-layer Snowflake warehouse: a raw landing zone mirroring source structure, a core star schema (commodity, geography, and supplier dimensions against a unified market fact table), and a reporting schema exposing only pre-aggregated, business-ready views. Power BI connects via DirectQuery against those views only, through a read-only service role scoped to the reporting schema — the semantic model never touches raw or core data. Report measures include year-over-year price movement and a Herfindahl-Hirschman Index (HHI) read on supply concentration, giving a standard, defensible risk metric rather than an ad hoc "looks concentrated" judgment call.

## CMS field: Outcome
A reporting layer that updates on the same cadence as the source feed with no separate refresh schedule to manage, a security boundary enforced once (at the warehouse role) rather than duplicated in the BI tool, and a supply-concentration view that surfaces single-country dependency risk automatically rather than requiring a manual scan.

## CMS field: Tech stack
Snowflake (warehouse, RBAC, DirectQuery-optimized views) · Power BI (native Snowflake connector, DAX) · SQL

---

### Notes for LR (not for CMS)

1. **Honesty framing is the important part.** This was built as a demo, not delivered work — the copy above says so explicitly ("Internal capability build"). If your site's existing case study pattern (Apex) doesn't have a way to visually flag "capability demo" vs. "client engagement," worth adding one — otherwise this reads as equivalent proof-of-work to a real client deliverance, which isn't accurate and cuts against your proof-first principle.
2. **Industry tag gap.** Mining & Critical Minerals isn't one of your five target industries (CPG, Retail, Finance, Healthcare, Insurance). Two options: add it as a sixth industry tag (reasonable, if you want commodities/mining as a target vertical), or don't industry-tag this case study at all and let it stand purely on the expertise tags (Data Foundation, Data Automation). Your call — I didn't want to silently expand your industry taxonomy.
3. **Generative AI / AI Operations gap is still open.** This case study doesn't touch it — it's a Data Foundation/Automation story. Worth planning a separate build for those two areas next.
