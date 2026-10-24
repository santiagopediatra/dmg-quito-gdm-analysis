# Gestational diabetes mellitus in Quito, Ecuador — analysis code

Analysis code for the manuscript *"Gestational diabetes mellitus detected under
routine risk-based screening in Quito, Ecuador"*.

**Authors:** Paola Toapanta-Pinta, Santiago Vasco-Morales, Sara Céspedes-Granda,
Daniela Saes Sartorelli, Elaine Christine Dantas Moisés  
**Version:** 1.0.0 · **DOI:** [FALTA: Zenodo DOI] · **License:** MIT (code)

## Purpose

This repository contains the code that produces every estimate, table and
figure of the manuscript from the study dataset. The individual-level data are
not included (see [Data availability](#data-availability)).

## Study

Prospective cohort at CSP2 and HGOIA in Quito, Ecuador (2021–2023; N = 523).
Gestational diabetes mellitus (GDM) is described as recorded in the clinical
record (D1) and by a restricted operational definition (D2): early fasting
glucose 92–125 mg/dL or oral glucose tolerance test (OGTT) values of
≥92/≥180/≥153 mg/dL (fasting/1-hour/2-hour). Late fasting glucose and values in
the overt-diabetes range are excluded from D2. BMI is weight/height².

Modified Poisson regression with robust HC0 variance is used for risk ratios.
Cesarean delivery is analysed with logistic regression and marginal
standardization (2,000 bootstrap resamples; seed 2026).

## Repository structure

```
.
├── scripts/
│   ├── analisis_final_DMG.R     # Full statistical analysis → resultados/
│   ├── figura1_flujo.gv         # Figure 1 source (Graphviz)
│   ├── figura2_vias.gv          # Figure 2 source (Graphviz)
│   ├── render_frontiers.R       # Renders Figures 1–2 → figures/
│   └── set_pdf_page.py          # Helper called by render_frontiers.R
├── resultados/                  # Aggregate result tables (CSV)
├── figures/                     # Figures 1–2 (SVG, PDF, 600-dpi TIFF)
├── data/README.md               # Data access and data dictionary (no data)
├── config_local.R.example       # Template for the local data path
├── renv.lock, renv/, .Rprofile  # Reproducible R package environment
├── sessionInfo.txt              # R session of the verified run
├── CITATION.cff, .zenodo.json   # Citation and archive metadata
└── LICENSE
```

## Requirements

- R 4.5.0
- R packages, pinned in `renv.lock`: `readxl` 1.5.0.1, `sandwich` 3.1-1,
  `lmtest` 0.9-40 (and their dependencies)
- For the figures only: Graphviz, the R packages `magick`, `xml2` and `rsvg`,
  and Python with `pikepdf` (versions below)

Restore the package environment once, from the repository root:

```r
renv::restore()
```

### System dependencies (figures only)

The R packages `magick` and `rsvg`, used only by `scripts/render_frontiers.R`,
need system libraries to build from source. On Debian/Ubuntu:

```sh
sudo apt install libmagick++-dev librsvg2-dev
```

The statistical analysis (`scripts/analisis_final_DMG.R`) does not need them.
Without these libraries, restore only the analysis packages with
`renv::restore(exclude = c("magick", "rsvg"))`.

## Running the analysis

1. **Data path.** Set the local path to the private data file in one of two ways
   (the environment variable takes precedence):
   - environment variable `DMG_DATA_PATH`, or
   - a file `config_local.R` in the repository root (copy
     `config_local.R.example`; `config_local.R` is excluded from version control).

2. **Analysis.** From the repository root:

   ```sh
   Rscript -e 'source("scripts/analisis_final_DMG.R", encoding = "UTF-8")'
   ```

   The script stops with an error if the data file is missing, if internal
   consistency checks fail, or if the key results differ from the published
   values. It does not modify the data file (checked by MD5).

3. **Figures** (independent of step 2):

   ```sh
   Rscript scripts/render_frontiers.R
   ```

4. **Session information** (optional): `sessionInfo.txt` was produced by running
   `writeLines(capture.output(sessionInfo()), "sessionInfo.txt")` in the same
   session as step 2.

## Outputs

### `scripts/analisis_final_DMG.R` → `resultados/`

| File | Content | Manuscript |
|---|---|---|
| `final_tabla1_imc.csv` | BMI, median and WHO categories, by GDM | Table 1 (BMI rows) |
| `final_tabla2_d1d2.csv` | Cumulative incidence by definition (D1, D2) and site | Table 2 |
| `final_cruce_d1_d2.csv` | Cross-classification of D1 and D2 | Supplementary material |
| `final_vias.csv` | First glucose criterion met, by recorded GDM | Figure 2 |
| `final_ogtt_figura2.csv` | OGTT availability and positivity by site (Wilson 95% CI); pathway counts by recorded GDM | Figure 2; Results |
| `final_tabla3.csv` | Factors associated with GDM, crude and adjusted RR | Table 3 |
| `final_vif_modeloA.csv` | Variance inflation factors, model A | Supplementary material |
| `final_tabla4.csv` | Maternal and neonatal outcomes by GDM | Table 4 |
| `final_modeloB.csv` | Model A plus dietary pattern score | Supplementary material |
| `final_cesarea_metodos.csv` | Cesarean RR: modified Poisson vs standardization | Supplementary material |
| `final_diagnosticos.csv` | Model diagnostics (predictions > 1, log-binomial) | Supplementary material |
| `final_secuencial.csv` | Sequential adjustment, LGA and macrosomia | Supplementary material |
| `final_sens_definicion.csv` | Outcomes under alternative GDM definitions and site adjustment | Table S9 |
| `final_loo.csv` | Leave-one-out range of RR, LGA and macrosomia | Supplementary material |

### `scripts/render_frontiers.R` → `figures/`

| File | Source | Content |
|---|---|---|
| `Figure1.svg/.pdf/.tif` | `scripts/figura1_flujo.gv` | Flow of participants |
| `Figure2.svg/.pdf/.tif` | `scripts/figura2_vias.gv` | Diagnostic pathways (D1/D2) |

The figures do not read the data file; their numbers are written in the `.gv`
sources. The Figure 2 numbers match `resultados/final_ogtt_figura2.csv`,
`final_vias.csv` and `final_tabla2_d1d2.csv`; the analysis script stops if the
pathway counts or OGTT figures change. The recruitment counts in Figure 1
(629 invited, 36 declined, 11 excluded, 59 without follow-up) come from the
recruitment records and are not in the analysis dataset.

Versions used for the figures:

| Tool | Version |
|---|---|
| Graphviz (`dot`) | 2.42.4 |
| R package `magick` | 2.8.5 (ImageMagick 7.1.1.39) |
| R package `xml2` | 1.6.0 |
| R package `rsvg` | 2.6.1 |
| Python | 3.13.5 |
| Python package `pikepdf` (used by `scripts/set_pdf_page.py`) | 9.5.2 |

## Data availability

The individual data file (`BASE PREVALENCIA 15 JULIO .xlsx`, worksheets
`1 HEMI` and `Hoja2`) is not published, under approval CEISH-UCE
017-CEISH.UCE.2021 and Ecuador's Organic Law on Personal Data Protection. It is
available upon reasonable request to the corresponding author, Paola
Toapanta-Pinta (ptoapanta@uce.edu.ec). See `data/README.md` for the reasons and
the data dictionary.

## Citation

Please cite this software using the metadata in `CITATION.cff` and the version
DOI from Zenodo.

## License

The code is released under the MIT License (see `LICENSE`).
