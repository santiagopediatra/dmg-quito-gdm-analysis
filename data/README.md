# Study data

The individual-level data are **not publicly available** and are not included in
this repository or its history.

## Why the data are not public

- **Ethics approval:** the study was approved by the Human Research Ethics
  Committee of Universidad Central del Ecuador (CEISH-UCE, approval
  017-CEISH.UCE.2021); under this approval, individual data are not published.
- **Law:** the dataset contains health data, a special category of personal
  data under Ecuador's Organic Law on Personal Data Protection (Ley Orgánica de
  Protección de Datos Personales, 2021). Small numbers in some subgroups make
  re-identification possible even without names or ID numbers.

## How to request access

Data are available upon reasonable request, under the conditions set by
CEISH-UCE, from the corresponding author:

**Paola Toapanta-Pinta** — ptoapanta@uce.edu.ec

## Expected file

| Item | Value |
|---|---|
| File | `BASE PREVALENCIA 15 JULIO .xlsx` (Excel) |
| Worksheet `1 HEMI` | 523 rows (one per woman in the analysed cohort); main analysis sheet |
| Worksheet `Hoja2` | 535 rows; read only to identify twin pregnancies |
| Location | Any local path, set in `DMG_DATA_PATH` or `config_local.R` (see the root README) |

## Data dictionary

Variables read by `scripts/analisis_final_DMG.R`. Column names are given exactly
as in the worksheet (Spanish, including original spelling). Types, units and
categories are those implied by the analysis code; **[FALTA]** marks information
the code does not define and that must be completed from the original data
collection forms. No real values are shown.

### Identification and setting

| Column | Type | Unit / categories | Use |
|---|---|---|---|
| *(first column, unnamed)* | Integer | Study code; no link to clinical identifiers in this file; not unique (one repeated value, not among twin pregnancies) | Renamed `id`; links `1 HEMI` with `Hoja2` to exclude twin pregnancies |
| `ZONA` | Text | `CSP2`, `HGOIA` | Recruitment site |

### Maternal characteristics

| Column | Type | Unit / categories | Use |
|---|---|---|---|
| `EDAD` | Numeric | Years | Age |
| `KG INICIAL` | Numeric | kg | Weight at first visit (BMI) |
| `TALLA` | Numeric | m or cm (values < 3 are treated as m and converted to cm) | Height (BMI) |
| `ANTECEDENTES FAMILIARES` | Free text | Any text containing "diab" = family history of diabetes; other content [FALTA] | Family history of diabetes |
| `CODIGO ETNIA MINORITARIA` | Binary | 0/1 (1 = minority ethnicity); groups included [FALTA] | Minority ethnicity |
| `NUMERO GESTAS PREVIAS` | Integer | Count | Previous pregnancies |
| Column ending in `…OS DE ESTUDIO` (years of schooling) | Numeric | Years | Education |
| `CODIGOS CESAREAS` | Numeric | Coding [FALTA]; missing treated as 0 | Previous cesarean (covariate) |
| `F3` | Numeric | Score; scale [FALTA]; standardized (per 1 SD) in the script | "Traditional Ecuadorian" dietary pattern |

### Glucose and GDM

| Column | Type | Unit / categories | Use |
|---|---|---|---|
| `CODIGO DMG` | Binary | 0/1 (1 = GDM recorded in the clinical record) | Definition D1 |
| `GLICEMIA ANTES DE 20 SEMANAS` | Numeric (stored as text with blanks) | mg/dL | Early fasting glucose (D2) |
| `GLICEMIA DESPUES DE 30 SEMANAS` | Numeric | mg/dL | Late fasting glucose (diagnostic pathways only) |
| `AYUNAS` | Numeric | mg/dL | OGTT fasting value |
| `1 HORA` | Numeric | mg/dL | OGTT 1-hour value |
| `2 HORA` | Numeric | mg/dL | OGTT 2-hour value |

### Outcomes

| Column | Type | Unit / categories | Use |
|---|---|---|---|
| `codigo cesarea actual si no` | Binary | 0/1 (1 = cesarean); missing = no delivery data | Cesarean delivery; defines the maternal-outcome population |
| `TRASTORNOS HIPERTENSIVOS` | Binary | 0/1 (1 = yes); disorders included [FALTA] | Hypertensive disorders of pregnancy |
| `KG RN` | Numeric | g (macrosomia = ≥ 4000) | Birth weight |
| `*PESO PARA EDAD` | Text | `PEEG` = large for gestational age; other categories [FALTA]; reference chart [FALTA] | Large for gestational age |
| `CODIGO HIPOGLICEMIA` | Binary | 0/1 (1 = yes); definition [FALTA] | Neonatal hypoglycemia |
| `COIGO POLICITEMIA` | Binary | 0/1 (1 = yes); definition [FALTA] | Neonatal polycythemia |
| `*APGAR 5 MINUTOS` | Numeric | Score 0–10 (< 7 = low) | Apgar score at 5 min |
| `codigo defectos congenitos si no` | Binary | 0/1 (1 = any recorded congenital anomaly) | Congenital anomaly |
| `*EG RN` | Text | Values starting with `Pret` = preterm; other categories [FALTA] | Preterm birth |

### Worksheet `Hoja2`

| Column | Type | Unit / categories | Use |
|---|---|---|---|
| *(first column, unnamed)* | Integer | Same study code as in `1 HEMI` | Link to `1 HEMI` |
| `EMBARAZO GEMELAR` | Text | `SI`, `NO` | Twin pregnancy (n = 7 `SI`); excluded from neonatal outcomes |
