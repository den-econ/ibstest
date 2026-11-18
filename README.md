# `ibstest` — Scarring Pipeline **Engine**

This repository is the **engine** of a two-part project that replicates the
Aswicahyono–Hill–Narjoko (**AHN, 2010**) *"six-lens" scarring analysis* of
Indonesian manufacturing, applied to two BPS datasets (**IBS** and **IMK**).

- **`ibstest` (this repo)** prepares the data and *controls* the run.
- **`scarring_industry` (a sibling folder)** holds the analysis do-files and the output.

> **Important:** `scarring_industry/` must sit **next to** `ibstest/` (same parent
> folder). The master files locate it automatically — no path editing needed.
>
> ```
> …/National Economic Council (NEC)/
> ├── ibstest/            ← this repo (engine + data)
> └── scarring_industry/  ← analysis + output (sibling)
> ```

---

## 1. The two-repository design

| Repository | Role | Contains |
|---|---|---|
| **`ibstest`** (this) | **Engine** | path config, the two masters, data-cleaning (`*_prepare`), data generators, **and the `data/` folder** |
| **`scarring_industry`** | **Analysis** | the six analysis lenses (`2a`–`2e` + Sankey) and all results (`output/`, `output_imk/`) |

The masters in `ibstest` set every path, read the data from `ibstest/data/`, call the
analysis do-files in `scarring_industry/`, and write results back into
`scarring_industry/output*`. See [`README_scarring_industry.md`](README_scarring_industry.md).

---

## 2. Background — the six "lenses"

The analysis is **descriptive accounting** (not econometrics). The same six lenses are
computed for both datasets:

| Lens | Question |
|---|---|
| **2a** growth | Did output / value added recover? |
| **2b** jobless growth | Did output recover faster than jobs? (+ unit labour cost) |
| **2c** size mobility | Did firms move between size classes? |
| **2d** entry / exit | How much firm churn? |
| **2e** decomposition | Where did the change come from (within vs between / entry-exit)? |

### The two datasets

| | **IBS** (Industri Besar & Sedang) | **IMK** (VIMK — Industri Mikro & Kecil) |
|---|---|---|
| Firm size covered | 20+ workers | 1–19 workers |
| Real firm panel? | **Yes** (persistent id) | **No** (fresh id each year) |
| Analysis level | **Firm** | **Industry** (2-digit KBLI) |
| Size classes | Small 20–99 · Medium 100–499 · Large 500+ | Micro 1–4 · Small 5–19 |
| Periods | pre 2010–2019 · crisis 2020–2022 | pre 2017–2019 · crisis 2020–2022 · recovery 2023–2025 |
| Index base year | 2019 | 2019 |

---

## 3. Folder structure (`ibstest`)

```
ibstest/
├── codes/
│   ├── SET_FILEPATHS.do            # shared: defines every folder path
│   ├── concordance_kbli_isic2.do   # shared: KBLI↔ISIC Rev.2 crosswalk
│   ├── ibs/
│   │   ├── MASTER.do               # run this for IBS
│   │   ├── 1_prepare.do            # build data/firm_panel.dta
│   │   └── gen_ibs_psid.do         # (one-off) build synthetic IBS sample
│   └── imk/
│       ├── imk_MASTER.do           # run this for IMK
│       ├── imk_1_prepare.do        # build data/imk_firm.dta  (COLUMN MAP here)
│       ├── convert_imk_dta.do      # Excel VIMK → .dta
│       ├── gen_imk_panel.do        # (one-off) build IMK sample
│       └── imk_prepare.do          # (legacy, standalone)
└── data/                           # raw inputs + processed panels (stays here)
```

> Comments in every do-file are written for **Stata beginners** (plain-English,
> one note per command). Block comments `/* */` are intentionally **never** used.

---

## 4. How to run

1. Make sure `scarring_industry/` exists **beside** this repo (see top of this file).
2. Open Stata **in the `ibstest` root folder** (so the working directory is correct).
3. Run whichever pipeline you need:

   ```stata
   do "codes/ibs/MASTER.do"        // IBS  → results in scarring_industry/output/
   do "codes/imk/imk_MASTER.do"    // IMK  → results in scarring_industry/output_imk/
   ```

Each master has **on/off triggers** at the top (`1` = run, `0` = skip). The
data-building steps (Section 0 convert, Section 1 prepare) only need to run **once**;
after `data/firm_panel.dta` / `data/imk_firm.dta` exist, set those triggers to `0`
and re-run only the analysis step you want.

---

## 5. Do-file reference (engine)

### Shared — `codes/`

| File | What it does | Output |
|---|---|---|
| [`SET_FILEPATHS.do`](codes/SET_FILEPATHS.do) | One place that defines all paths (`$root`, `$code`, `$data`, `$raw`, `$output`, `$code_scar`, …). Both masters call it. | — (sets globals) |
| [`concordance_kbli_isic2.do`](codes/concordance_kbli_isic2.do) | Builds a KBLI/ISIC Rev.4 → ISIC Rev.2 crosswalk so IMK can be linked to the old SI surveys (1975/85/95). | `data/concordance_kbli2_isic2rev2.dta` (+ `.csv`) |

### IBS — `codes/ibs/`

| File | What it does | Output |
|---|---|---|
| [`MASTER.do`](codes/ibs/MASTER.do) | **Control panel.** Sets options, then runs `1_prepare` + `2a`–`2e` + Sankey. | drives everything; writes `.xlsx` copies |
| [`1_prepare.do`](codes/ibs/1_prepare.do) | Reads each yearly IBS file, standardises column names, stacks all years into one firm-year panel. Detects whether the firm id is usable (raw / panel / auto). | `data/firm_panel.dta` |
| [`gen_ibs_psid.do`](codes/ibs/gen_ibs_psid.do) | **One-off generator.** Builds a *synthetic-but-mergeable* `psid` for the sample (borrows real 2005 ids). | `data/panel_ibs_sintesis/*.dta` |

### IMK — `codes/imk/`

| File | What it does | Output |
|---|---|---|
| [`imk_MASTER.do`](codes/imk/imk_MASTER.do) | **Control panel.** Sets the 3 periods + Micro/Small cut-offs, then runs convert + prepare + `2a`–`2e` + Sankey. | drives everything; `.xlsx` copies |
| [`imk_1_prepare.do`](codes/imk/imk_1_prepare.do) | Maps each year's shifting VIMK column names onto 4 standard variables (`emp`, `output`, `wage`, `input`) + `kbli2` + size class + sector groups. **← edit the COLUMN MAP here for real data.** | `data/imk_firm.dta` |
| [`convert_imk_dta.do`](codes/imk/convert_imk_dta.do) | Converts the raw VIMK `.xlsx` files to `.dta` (2017–2025); folds split-file years (2024/2025) into one row per firm. | `data/raw_imk_sampel/VIMK{YY}.dta` |
| [`gen_imk_panel.do`](codes/imk/gen_imk_panel.do) | **One-off generator.** Builds the industry-level IMK sample keeping all raw variables. | `data/panel_imk_sintesis/*.dta` |
| [`imk_prepare.do`](codes/imk/imk_prepare.do) | **Legacy / standalone.** Merges the 3 VIMK Excel blocks into one row per firm. Superseded by `convert_imk_dta.do` + `imk_1_prepare.do`. | `data/.../vimk{YY}.dta` |

---

## 6. How the paths work

All paths come from `codes/SET_FILEPATHS.do`. You normally never touch them.

| Global | Points to | Notes |
|---|---|---|
| `$root` | the `ibstest` repo | set by the master (hard-coded for the known machine, else current folder) |
| `$code` | `ibstest/codes` | engine do-files |
| `$data` | `ibstest/data` | inputs + processed panels (stays in this repo) |
| `$raw` | `ibstest/data/raw` | real IBS microdata (`mfgYYYY.dta`) |
| `$raw_imk` | `ibstest/data/raw_imk_sampel` | IMK `VIMK{YY}.dta` |
| `$scar_root` | sibling `scarring_industry` | **auto-derived** = parent-of-`$root` + `/scarring_industry` |
| `$code_scar` | `scarring_industry/codes` | the analysis do-files |
| `$output` / `$output_imk` | `scarring_industry/output` / `output_imk` | all results land here |

---

## 7. Running on the **real** data (plug-and-play)

- **IMK:** drop the real `VIMK{YY}.dta` into `data/raw_imk_sampel/` and run. If BPS kept
  the same variable names, nothing changes. If a column was renamed, edit only that
  year's line in the **COLUMN MAP** block of `imk_1_prepare.do`.
- **IBS:** put the real `mfgYYYY.dta` into `data/raw/` and run `MASTER.do`. `1_prepare.do`
  reads **only** `data/raw`, then prints whether the firm id is **valid** or **masked**
  (`link_ok`): if valid, all lenses run; if masked, the link-based lenses (2c/2d/2e) are
  skipped. There is **no** automatic switch to synthetic data, so you always know exactly
  which data you analysed.

---

## 8. Data notes & caveats (sample data)

- **The IBS sample has no real cross-year firm id** (`Kipb` is masked `***`). `1_prepare.do`
  detects this and **skips** the link-based lenses (2c/2d/2e) rather than inventing anything.
  A separate helper, `gen_ibs_psid.do`, can *fabricate* a linkable `psid` for testing the
  machinery, but those synthetic trajectories are **not meaningful** — real mobility /
  entry-exit come only from the owner's actual IBS data.
- **IMK has no firm panel at all** (the id is a fresh UUID each year). Every IMK result is
  therefore **industry-level or a yearly composition**, never firm tracking. "Entry/exit"
  (`imk_2d`) is **net establishment change**, not true gross firm entry/exit.
- Values are **nominal** (no deflator applied).

---

## 9. Where the results go

Nothing is written inside `ibstest` except the processed data in `data/`. All tables and
figures are written to the **sibling** repo:

- `scarring_industry/output/` — IBS results (`.csv`, `.xlsx`, Sankey `.png`)
- `scarring_industry/output_imk/` — IMK results

See [`README_scarring_industry.md`](README_scarring_industry.md) for the full output list.
