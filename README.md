# Gestational diabetes mellitus in Quito, Ecuador

**Authors:** Paola Toapanta-Pinta, Santiago Vasco-Morales, Sara Céspedes-Granda,
Daniela Saes Sartorelli, Elaine Christine Dantas Moisés  
**Status:** Manuscript in preparation

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

## Reproducing the analysis

Requires R 4.5.0 and the R packages `readxl`, `sandwich`, and `lmtest`. From
the repository root, run:

```sh
Rscript -e 'source("scripts/analisis_final_DMG.R", encoding = "UTF-8")'
```

## Data availability

The script expects `BASE PREVALENCIA 15 JULIO .xlsx` (worksheet `1 HEMI`) in
the project directory. It contains individual clinical data and is not
published, under approval CEISH-UCE 017-CEISH.UCE.2021 and Ecuador's Organic
Law on Personal Data Protection. It is available upon reasonable request to
the corresponding author. A local-only data link may be used for analysis; the
Excel file is excluded from version control.
