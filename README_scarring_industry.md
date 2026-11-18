# `scarring_industry` — Scarring Pipeline **Analysis**

This repository holds the **analysis** half of the scarring project: the six
Aswicahyono–Hill–Narjoko (**AHN, 2010**) "lenses" (`2a`–`2e` + a Sankey diagram),
for both the **IBS** (large/medium firms) and **IMK** (micro/small) datasets.

- **`scarring_industry` (this repo)** contains the analysis do-files and all results.
- **`ibstest` (a sibling folder)** is the **engine**: it prepares the data and *runs* this
  analysis. See [`README.md`](README.md).

> **Important:** this folder must sit **next to** `ibstest/` (same parent folder). You do
> **not** run these files directly — the masters in `ibstest` call them, having first set
> all the paths and built the data.
>
> ```
> …/National Economic Council (NEC)/
> ├── ibstest/            ← engine + data
> └── scarring_industry/  ← this repo (analysis + output)
> ```

---

## 1. How this repo is used

The analysis is **driven by the engine**, not run on its own:

1. You run a master in `ibstest` (`codes/ibs/MASTER.do` or `codes/imk/imk_MASTER.do`).
2. The master sets paths, builds the firm/industry panel in `ibstest/data/`, then calls the
   do-files **here** one by one.
3. Results are written **here**, into `output/` (IBS) and `output_imk/` (IMK).

So every analysis do-file simply reads the prepared data via `$data` (which lives in
`ibstest`) and writes to `$output` / `$output_imk` (which live here). The paths are set by
`ibstest/codes/SET_FILEPATHS.do`.

---

## 2. Folder structure (`scarring_industry`)

```
scarring_industry/
├── codes/
│   ├── render_sankey.do        # shared: draw Sankey from the transition tables
│   ├── sankey_mobility.py      # shared: zero-install Python fallback for Sankey
│   ├── ibs/                    # firm-level lenses (needs the IBS firm panel)
│   │   ├── 2a_growth.do
│   │   ├── 2b_jobless_growth.do
│   │   ├── 2c_size_mobility.do
│   │   ├── 2d_entry_exit.do
│   │   └── 2e_decomposition.do
│   └── imk/                    # industry-level lenses (IMK has no firm panel)
│       ├── imk_2a_growth.do
│       ├── imk_2b_jobless_growth.do
│       ├── imk_2c_size_mobility.do
│       ├── imk_2d_entry_exit.do
│       └── imk_2e_decomposition.do
├── output/                     # IBS results (.csv, .xlsx, .png)
└── output_imk/                 # IMK results
```

> `output/` and `output_imk/` are created automatically on first run.

---

## 3. IBS vs IMK — the key difference

| | **IBS** (`codes/ibs/`) | **IMK** (`codes/imk/`) |
|---|---|---|
| Unit of analysis | **Firm** (has a real panel) | **Industry** (2-digit KBLI) |
| 2c mobility | real firm size-class **transitions** | industry size **terciles** + sector→size-band composition |
| 2d churn | real firm **entry / exit** | **net** establishment change (proxy) |
| 2e decomposition | Davis-Haltiwanger-Schuh employment split | within/between **shift-share** of productivity |
| Size classes | Small 20–99 · Medium 100–499 · Large 500+ | Micro 1–4 · Small 5–19 |
| Periods | pre 2010–19 · crisis 2020–22 | pre 2017–19 · crisis 2020–22 · recovery 2023–25 |

IMK differs because it has **no persistent firm id** — firms cannot be followed across
years, so everything is industry-level or a yearly composition.

---

## 4. Do-file reference (analysis)

### Shared — `codes/`

| File | What it does | Output |
|---|---|---|
| [`render_sankey.do`](../scarring_industry/codes/render_sankey.do) | Draws a Sankey for every `*transition_*.csv` / `*sizeflow_*.csv` in the output folder. Native Stata (auto-installs its packages) with a Python fallback. | `*_sankey.png` |
| [`sankey_mobility.py`](../scarring_industry/codes/sankey_mobility.py) | Pure-Python, zero-install, offline fallback that writes an HTML Sankey. Called automatically by `render_sankey.do` only when the Stata package is unavailable. | `*_sankey.html` |

### IBS lenses — `codes/ibs/` (firm level)

| File | What it does | Output |
|---|---|---|
| [`2a_growth.do`](../scarring_industry/codes/ibs/2a_growth.do) | National totals (output, value added) per year; YoY growth; averaged by period and by sector. | `2a_va_by_year.csv`, `2a_growth_by_period.csv`, `2a_growth_by_sector.csv` |
| [`2b_jobless_growth.do`](../scarring_industry/codes/ibs/2b_jobless_growth.do) | Indexes output / VA / employment / labour productivity to base = 100; computes ULC (labour cost / VA). | `2b_index.csv`, `2b_summary.csv`, `2b_ulc.csv`, `2b_jobless_growth.png` |
| [`2c_size_mobility.do`](../scarring_industry/codes/ibs/2c_size_mobility.do) | Firm transition matrix across Small / Medium / Large, start→end of each period. | `2c_transition_pre.csv`, `2c_transition_crisis.csv` (feed the Sankey) |
| [`2d_entry_exit.do`](../scarring_industry/codes/ibs/2d_entry_exit.do) | Firm entry & exit per consecutive-year pair, as a share of firms present the year before. | `2d_entry_exit.csv`, `2d_entry_exit.png` |
| [`2e_decomposition.do`](../scarring_industry/codes/ibs/2e_decomposition.do) | Davis-Haltiwanger-Schuh split of employment change into entry / expansion / contraction / exit. | `2e_decomp.csv` |

### IMK lenses — `codes/imk/` (industry level)

| File | What it does | Output |
|---|---|---|
| [`imk_2a_growth.do`](../scarring_industry/codes/imk/imk_2a_growth.do) | Output & employment growth by industry, over the 3 periods and per industry. | `imk_2a_totals.csv`, `imk_2a_growth_by_period.csv`, `imk_2a_growth_by_industry.csv` |
| [`imk_2b_jobless_growth.do`](../scarring_industry/codes/imk/imk_2b_jobless_growth.do) | Indexes output / employment / productivity to 100; ULC. | `imk_2b_index.csv`, `imk_2b_ulc.csv`, `imk_2b_jobless.png` |
| [`imk_2c_size_mobility.do`](../scarring_industry/codes/imk/imk_2c_size_mobility.do) | (A) Micro/Small composition per year; (B) industry terciles T1/T2/T3 transitions; (C) sector-group → size-band composition. | `imk_2c_sizeshare.csv`, `imk_2c_transition_*.csv`, `imk_2c_sizeflow_{A,B}_*.csv` (feed the Sankey) |
| [`imk_2d_entry_exit.do`](../scarring_industry/codes/imk/imk_2d_entry_exit.do) | Net establishment-count dynamics per industry (a net-churn proxy — **not** true firm entry/exit). | `imk_2d_establishments.csv`, `imk_2d_establishments.png` |
| [`imk_2e_decomposition.do`](../scarring_industry/codes/imk/imk_2e_decomposition.do) | Within/between (shift-share) decomposition of labour-productivity growth. | `imk_2e_decomp.csv` |

---

## 5. Outputs produced

All files land in `output/` (IBS) or `output_imk/` (IMK). Each result table is written as
`.csv` **and** `.xlsx`; Sankey diagrams are `.png` (or `.html` from the Python fallback).

| Lens | IBS files | IMK files |
|---|---|---|
| 2a | `2a_va_by_year`, `2a_growth_by_period`, `2a_growth_by_sector` | `imk_2a_totals`, `imk_2a_growth_by_period`, `imk_2a_growth_by_industry` |
| 2b | `2b_index`, `2b_summary`, `2b_ulc`, `2b_jobless_growth.png` | `imk_2b_index`, `imk_2b_ulc`, `imk_2b_jobless.png` |
| 2c | `2c_transition_pre/crisis` + `*_sankey.png` | `imk_2c_sizeshare`, `imk_2c_transition_*`, `imk_2c_sizeflow_{A,B}_*` + `*_sankey.png` |
| 2d | `2d_entry_exit` + `.png` | `imk_2d_establishments` + `.png` |
| 2e | `2e_decomp` | `imk_2e_decomp` |

---

## 6. Caveats to keep in mind

- **IBS on the sample data:** the firm panel is *synthetic* (fabricated `psid`), so the 2c
  transitions and 2d entry/exit are **illustrative only** on the sample — valid only once
  the real IBS data (with a genuine firm id) is used. See [`README.md`](README.md).
- **IMK is always industry-level** (no firm panel). The 2c "terciles" rank *industries* by
  mean firm size; every firm is still Micro/Small (1–19 workers).
- Figures are **nominal** (no deflator).
- These do-files are **not** standalone: run them through the `ibstest` masters so the paths
  and the prepared data are in place.
