# IMK scarring pipeline — how it works & how to run on real data

Parallel to the IBS pipeline, but **everything is at INDUSTRY level (2-digit KBLI)**
because IMK has no persistent firm id (firms cannot be followed across years).
Size uses the **BPS worker definition**: Micro = 1–4, Small = 5–19 workers.

## Run order — ONE command
```stata
do "code/imk_MASTER.do"
```
That's it. The master runs everything in order, each step guarded so a missing file
or offline machine never crashes the run:
  - **Section 0** converts the Excel VIMK{YY} files to `.dta` (skips any absent year),
  - **Section 1** harmonizes all years -> `data/imk_firm.dta`,
  - **2a-2e** run the analyses and write `output_imk/` (CSV + XLSX + PNG),
  - the **Sankey** step renders natively in Stata (auto-installing its packages).
All switches live at the top of `imk_MASTER.do`. Sections 0 and 1 are "run once":
turn their triggers off to re-run only an analysis step (each is self-contained).

## Files
| File | Does |
|---|---|
| `convert_imk_dta.do` | Excel -> .dta; folds split 2024/2025 detail blocks into the firm row |
| `imk_1_prepare.do` | harmonize all years -> `data/imk_firm.dta` (**column map lives here**) |
| `imk_2a_growth.do` | output & employment growth, by period & industry |
| `imk_2b_jobless_growth.do` | output vs employment index, labour productivity, ULC |
| `imk_2c_size_mobility.do` | **(A)** Micro/Small composition over time (+ chart); **(B)** industry terciles T1/T2/T3 transition matrices (Sankey); **(C)** firm composition by **sector group** -> size band (Micro 1-4 / Small 5-9 / 10-19), snapshot 2019/2022/2025 (Sankey). Two sector schemes: `secgroupA` end-use (5), `secgroupB` factor-intensity (4), both built in `imk_1_prepare.do` and reusable in any chart |
| `imk_2d_entry_exit.do` | establishment-count dynamics (net churn proxy) |
| `imk_2e_decomposition.do` | within/between (shift-share) productivity decomposition |
| `render_sankey.do` | **(shared IMK+IBS)** native Stata Sankey of any `*transition_*.csv`; auto-installs packages, Python fallback |
| `sankey_mobility.py` | zero-install SVG Sankey — the offline fallback for `render_sankey.do` |

## PLUG-AND-PLAY: the one thing to edit for real data
`imk_1_prepare.do` harmonizes 4 standard variables onto cryptic yearly columns:
`emp` (workers), `output` (revenue), `wage` (labour cost), `input` (materials+fuel).
The mapping is a **single clearly-marked block** (`COLUMN MAP`, one line per year). If
the real VIMK files use the same variable names (they should — the sample mirrors the
real layout), **nothing needs changing**: drop the real `VIMK{YY}.dta` in
`data/raw_imk/` and run. If BPS renamed a column, edit only that year's line.
The code is existence-guarded: a missing column prints a warning and continues.

## Data caveats (verified on the sample)
- **No firm panel.** Firms cannot be tracked across years, so nothing follows a firm.
  2c/2d/2e are industry dynamics or yearly composition, never firm trajectories.
  "Entry/exit" (2d) is NET establishment change, not gross firm entry/exit.
- **2c is deliberately non-panel, two parts:** (A) **Micro/Small composition** = count
  firms by BPS class each year (a snapshot, robust, the dependable lens); (B) **industry
  terciles T1/T2/T3** = the 23 industries ranked by mean firm size. T1/T2/T3 are NOT firm
  classes — every IMK firm is Micro/Small (1–19); industry mean firm size just spans a
  narrow ~1–5.5 band, so (B) is **illustrative, not statistically precise**. This is
  structural (IMK is capped at 19 workers), so the full dataset would not change it.
- **Sample adequacy:** ~8,000–9,250 firms/yr across 23 industries (median ~110–200
  firms/industry) — robust for aggregates. A few tail industries have <10 firms/yr.
- **Wage** is ~0 for most firms (IMK are largely **unpaid family businesses** — a real 0,
  not missing). ⚠️ 2020 & 2021 show anomalously high wage coverage/levels (a vintage/
  extract quirk) → read ULC for 2020–2021 with caution.
- **Input** is **unreliable for 2024 & 2025** (material detail sits in separate block
  files only partly merged). All core analyses use `output` and `emp` (not `input`/VA),
  so this does not affect 2a/2b/2c/2e; only the raw `input` column in 2a totals is thin
  for those two years.
- Values are **nominal** (no deflator applied).

## Periods
pre 2017–2019 · crisis 2020–2022 · recovery 2023–2025 (base year 2019 = 100). Set in
`imk_MASTER.do`.

## Sankey — `render_sankey.do` (shared by IMK and IBS)
One generic file draws a Sankey for every `*transition_*.csv` in whatever folder it is
pointed at (IMK: `output_imk/` with the T1/T2/T3 terciles; IBS: `output/` with the real
firm classes Small/Medium/Large = 20–99 / 100–499 / 500+ — real flows, since IBS has a
firm panel). It runs **natively in Stata** and **auto-installs** its packages
(`sankey` + `palettes` + `colrspace` + `graphfunctions`) the first time, so you install
nothing by hand. Both masters call it automatically and write
`<folder>/<tablename>_sankey.png`.

Fallback chain (so it never hard-fails on the owner's laptop):
1. native Stata `sankey` (auto-install needs internet once);
2. if SSC is blocked/offline -> `sankey_mobility.py` (pure Python + inline SVG, **no
   installs, no internet**) writes an HTML Sankey per transition table;
3. if Python is also absent -> skips with a message (the `*transition_*.csv`
   tables are still written, so no analysis is lost).

You do **not** run the Python file yourself — it is only the automatic fallback.
