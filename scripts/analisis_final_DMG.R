## =====================================================================
## analisis_final_DMG.R — Análisis final: DMG en Quito (cohorte CSP2 + HGOIA, N = 523)
## IMC = peso (kg) / talla (m)^2. D1 = DMG registrada; D2 = definición operacional restringida.
## Ejecutar desde la raíz del repositorio:  source("scripts/analisis_final_DMG.R", encoding = "UTF-8")
## Paquetes: readxl, sandwich, lmtest. No modifica el Excel. Salidas en resultados/final_*.csv
## =====================================================================
suppressPackageStartupMessages({ library(readxl); library(sandwich); library(lmtest) })
## ---------- 0. Datos ----------
## Ruta al Excel privado: variable de entorno DMG_DATA_PATH o config_local.R (no versionado; ver config_local.R.example)
if (file.exists("config_local.R")) source("config_local.R", local = TRUE)
cand <- Sys.getenv("DMG_DATA_PATH", if (exists("DMG_DATA_PATH")) DMG_DATA_PATH else "")
if (!nzchar(cand) || !file.exists(cand))
  stop("No se encontró el Excel de datos (ruta: '", cand, "'). Defina la ruta en la variable de entorno ",
       "DMG_DATA_PATH o en config_local.R (copie config_local.R.example). ",
       "Los datos no son públicos: ver data/README.md.", call. = FALSE)
md5_ini <- unname(tools::md5sum(cand))
d <- as.data.frame(read_excel(cand, sheet = "1 HEMI", .name_repair = "minimal"))
names(d) <- trimws(names(d)); names(d)[1] <- "id"
stopifnot(nrow(d) == 523, sum(d$`CODIGO DMG`) == 75)
## La glucemia <20 semanas se lee como texto (celdas con espacios en blanco): convertir a número
d$`GLICEMIA ANTES DE 20 SEMANAS` <- suppressWarnings(as.numeric(d$`GLICEMIA ANTES DE 20 SEMANAS`))
stopifnot(sum(is.na(d$`GLICEMIA ANTES DE 20 SEMANAS`)) == 4)
dir.create("resultados", showWarnings = FALSE)

## ---------- 1. Variables ----------
talla_cm  <- ifelse(d$TALLA < 3, d$TALLA * 100, d$TALLA)
d$imc <- d$`KG INICIAL` / (talla_cm / 100)^2
stopifnot(sum(is.na(d$imc)) == sum(is.na(d$`KG INICIAL`) | is.na(d$TALLA)))
d$imc_oms  <- cut(d$imc, c(-Inf, 18.5, 25, 30, Inf), right = FALSE,
                  labels = c("Underweight", "Normal", "Overweight", "Obesity"))
d$dmg      <- d$`CODIGO DMG`
ftxt       <- d$`ANTECEDENTES FAMILIARES`
d$fam_dm   <- ifelse(is.na(ftxt), NA, as.integer(grepl("diab", ftxt, ignore.case = TRUE)))
d$etnia_min <- d$`CODIGO ETNIA MINORITARIA`
d$gestas   <- d$`NUMERO GESTAS PREVIAS`
col_educ  <- grep("OS DE ESTUDIO$", names(d), value = TRUE); stopifnot(length(col_educ) == 1)
d$educ     <- d[[col_educ]]
d$hgoia    <- as.integer(d$ZONA == "HGOIA")
d$ces      <- d$`codigo cesarea actual si no`
d$ces_prev <- ifelse(is.na(d$`CODIGOS CESAREAS`), 0, d$`CODIGOS CESAREAS`)
d$hta      <- d$`TRASTORNOS HIPERTENSIVOS`
d$lga      <- ifelse(is.na(d$`*PESO PARA EDAD`), NA, as.integer(trimws(d$`*PESO PARA EDAD`) == "PEEG"))
d$macro    <- as.integer(d$`KG RN` >= 4000)
d$hipo     <- d$`CODIGO HIPOGLICEMIA`
d$poli     <- d$`COIGO POLICITEMIA`
h2 <- as.data.frame(read_excel(cand, sheet = "Hoja2", .name_repair = "minimal")); names(h2) <- trimws(names(h2))
gemelares  <- h2[[1]][trimws(toupper(h2$`EMBARAZO GEMELAR`)) %in% "SI"]   # embarazos gemelares: Hoja2, EMBARAZO GEMELAR = SI
stopifnot(length(gemelares) == 7, all(gemelares %in% d$id))
d$singleton <- as.integer(!d$id %in% gemelares)
## D1 / D2
f1 <- d$`GLICEMIA ANTES DE 20 SEMANAS`
og <- (d$AYUNAS >= 92) | (d$`1 HORA` >= 180) | (d$`2 HORA` >= 153)
og_pos <- !is.na(og) & og |
  (!is.na(d$AYUNAS) & d$AYUNAS >= 92) | (!is.na(d$`1 HORA`) & d$`1 HORA` >= 180) | (!is.na(d$`2 HORA`) & d$`2 HORA` >= 153)
d$d2_eval <- !is.na(f1) | !is.na(d$AYUNAS) | !is.na(d$`1 HORA`) | !is.na(d$`2 HORA`)
d$d2 <- ifelse(d$d2_eval, as.integer((!is.na(f1) & f1 >= 92 & f1 < 126) | og_pos), NA)
stopifnot(sum(d$d2, na.rm = TRUE) == 53, sum(d$d2_eval) == 521)
## Diabetes franca (WHO 2013): ayunas >=126 o 2 h >=200 mg/dL en la PTOG -> no se cuenta como DMG en D2
d$overt <- (!is.na(d$AYUNAS) & d$AYUNAS >= 126) | (!is.na(d$`2 HORA`) & d$`2 HORA` >= 200)
stopifnot(sum(d$overt) == 1)
d$d2 <- ifelse(d$d2_eval, as.integer(d$d2 == 1 & !d$overt), NA)
stopifnot(sum(d$d2, na.rm = TRUE) == 52)

## ---------- 2. Funciones ----------
wilson <- function(x, n) { ci <- suppressWarnings(prop.test(x, n, correct = FALSE)$conf.int)
  sprintf("%d/%d (%.1f%%; %.1f–%.1f)", x, n, 100 * x / n, 100 * ci[1], 100 * ci[2]) }
fmt <- function(e) sprintf("%.2f (%.2f–%.2f)", e[1], e[2], e[3])
pois <- function(f, dat, term = "dmg") {
  m <- glm(f, family = poisson(link = "log"), data = dat)
  v <- vcovHC(m, type = "HC0")
  b <- coef(m)[term]; se <- sqrt(diag(v))[term]
  cbind(exp(b), exp(b - 1.959964 * se), exp(b + 1.959964 * se))
}
ces_std <- function(dat, imc, B = 2000) {
  f <- as.formula(paste("ces ~ dmg + ces_prev +", imc, "+ EDAD + gestas"))
  dat <- dat[complete.cases(dat[, all.vars(f)]), ]
  rr <- function(x) { m <- glm(f, family = binomial, data = x)
    mean(predict(m, transform(x, dmg = 1), type = "response")) /
    mean(predict(m, transform(x, dmg = 0), type = "response")) }
  set.seed(2026)
  bt <- replicate(B, rr(dat[sample(nrow(dat), replace = TRUE), ]))
  c(rr(dat), quantile(bt, c(.025, .975)))
}
crude <- function(y, dat) { t1 <- sum(dat[[y]][dat$dmg == 1], na.rm = TRUE); n1 <- sum(!is.na(dat[[y]][dat$dmg == 1]))
  t0 <- sum(dat[[y]][dat$dmg == 0], na.rm = TRUE); n0 <- sum(!is.na(dat[[y]][dat$dmg == 0]))
  rr <- (t1 / n1) / (t0 / n0); se <- sqrt(1 / t1 - 1 / n1 + 1 / t0 - 1 / n0)
  c(rr, rr * exp(-1.959964 * se), rr * exp(1.959964 * se)) }

## ---------- 3. IMC para la Tabla 1 ----------
fp <- function(p) if (p < 0.001) "<0.001" else sprintf("%.3f", p)
mq <- function(x) sprintf("%.1f (%.1f–%.1f)", median(x, na.rm = TRUE), quantile(x, .25, na.rm = TRUE), quantile(x, .75, na.rm = TRUE))
tab_imc <- rbind(
  c("BMI (weight/height²), median (IQR)", mq(d$imc), mq(d$imc[d$dmg == 1]), mq(d$imc[d$dmg == 0]),
    fp(wilcox.test(imc ~ dmg, data = d, exact = FALSE)$p.value)),
  t(sapply(levels(d$imc_oms), function(l) {
    np <- function(v) sprintf("%d (%.1f%%)", sum(v == l, na.rm = TRUE), 100 * mean(v == l, na.rm = TRUE))
    c(paste0("  ", l), np(d$imc_oms), np(d$imc_oms[d$dmg == 1]), np(d$imc_oms[d$dmg == 0]), "")
  })))
tab_imc[2, 5] <- fp(fisher.test(table(d$imc_oms, d$dmg))$p.value)   # Fisher: celda con 0
colnames(tab_imc) <- c("Characteristic", "Overall", "GDM", "No GDM", "p")
print(tab_imc, quote = FALSE)
write.csv(tab_imc, "resultados/final_tabla1_imc.csv", row.names = FALSE)

np <- function(x, n) sprintf("%d/%d (%.1f%%)", x, n, 100 * x / n)
ci3 <- function(m, v, t) exp(coef(m)[t] + c(0, -1, 1) * 1.959964 * sqrt(v[t, t]))
covA <- c("EDAD", "imc", "fam_dm", "etnia_min", "gestas", "educ", "hgoia")
labA <- c("Age (per year)", "BMI (per kg/m²)", "Family history of diabetes", "Minority ethnicity",
          "Previous pregnancies (per pregnancy)", "Education (per year)", "HGOIA vs CSP2")
## ---------- Tabla 2 (incidencia) y tablas de vías diagnósticas ----------
site <- function(sel) c(wilson(sum(d$dmg[sel]), sum(sel)),
                        wilson(sum(d$d2[sel], na.rm = TRUE), sum(d$d2_eval[sel])))
t2 <- data.frame(Definition = c("D1", "D2"), Overall = site(rep(TRUE, nrow(d))),
                 CSP2 = site(d$ZONA == "CSP2"), HGOIA = site(d$ZONA == "HGOIA"))
write.csv(t2, "resultados/final_tabla2_d1d2.csv", row.names = FALSE)
d$d2_cat <- ifelse(!d$d2_eval, "D2 not evaluable", ifelse(d$overt, "Overt-diabetes range", ifelse(d$d2 == 1, "D2 positive", "D2 not positive")))
cx <- as.data.frame.matrix(table(factor(d$dmg, 0:1, c("No", "Yes")),
        factor(d$d2_cat, c("D2 not positive", "D2 positive", "Overt-diabetes range", "D2 not evaluable"))))
cx <- rbind(cx, Total = colSums(cx)); cx$Total <- rowSums(cx)
write.csv(cbind(D1 = rownames(cx), cx), "resultados/final_cruce_d1_d2.csv", row.names = FALSE)
early <- !is.na(f1) & f1 >= 92 & f1 < 126
ogp   <- og_pos & !d$overt
late  <- !is.na(d$`GLICEMIA DESPUES DE 30 SEMANAS`) & d$`GLICEMIA DESPUES DE 30 SEMANAS` >= 92 & d$`GLICEMIA DESPUES DE 30 SEMANAS` < 126
via <- ifelse(early, "Early fasting glucose 92–125 mg/dL", ifelse(d$overt, "OGTT in overt-diabetes range",
        ifelse(ogp, "Positive OGTT (early criterion absent)", ifelse(late, "Late fasting glucose 92–125 mg/dL only", "No criterion met"))))
pv <- as.data.frame.matrix(table(factor(via, c("Early fasting glucose 92–125 mg/dL", "Positive OGTT (early criterion absent)",
        "OGTT in overt-diabetes range", "Late fasting glucose 92–125 mg/dL only", "No criterion met")), factor(d$dmg, 0:1, c("No GDM", "GDM"))))
pv$Total <- rowSums(pv)
write.csv(cbind(Pathway = rownames(pv), pv), "resultados/final_vias.csv", row.names = FALSE)
## Figura 2: disponibilidad y positividad de la PTOG (IC Wilson) por sitio, y conteos por vía diagnóstica
og_av <- !is.na(d$AYUNAS) | !is.na(d$`1 HORA`) | !is.na(d$`2 HORA`)
og_site <- function(lab, sel) data.frame(Measure = c("OGTT values available", "OGTT above GDM thresholds"), Group = lab,
  Count = c(sum(og_av[sel]), sum(og_pos[sel])), Denominator = c(sum(sel), sum(og_av[sel])),
  Estimate = c(wilson(sum(og_av[sel]), sum(sel)), wilson(sum(og_pos[sel]), sum(og_av[sel]))))
fig2 <- rbind(og_site("Overall", rep(TRUE, nrow(d))), og_site("CSP2", d$ZONA == "CSP2"), og_site("HGOIA", d$ZONA == "HGOIA"),
  data.frame(Measure = rep(rownames(pv), each = 3), Group = rep(c("All", "GDM", "No GDM"), nrow(pv)),
             Count = as.vector(rbind(pv$Total, pv$GDM, pv$`No GDM`)), Denominator = nrow(d), Estimate = ""))
stopifnot(fig2$Estimate[1:2] == c("71/523 (13.6%; 10.9–16.8)", "40/71 (56.3%; 44.8–67.3)"),
          fig2$Count[1:6] == c(71, 40, 46, 19, 25, 21), fig2$Denominator[1:6] == c(523, 71, 321, 46, 202, 25),
          pv$Total == c(23, 29, 1, 25, 445), pv$GDM == c(22, 28, 1, 24, 0))
write.csv(fig2, "resultados/final_ogtt_figura2.csv", row.names = FALSE)
print(t2); print(cx); print(pv)

## ---------- Tabla 3: factores asociados ----------
crudo <- sapply(covA, function(t) { dd <- d[!is.na(d[[t]]), ]
  m <- glm(as.formula(paste("dmg ~", t)), family = poisson, data = dd); fmt(ci3(m, vcovHC(m, type = "HC0"), t)) })
fA <- as.formula(paste("dmg ~", paste(covA, collapse = " + ")))
dA <- d[complete.cases(d[, all.vars(fA)]), ]
mA <- glm(fA, family = poisson, data = dA); vA <- vcovHC(mA, type = "HC0")
ajus <- sapply(covA, function(t) fmt(ci3(mA, vA, t)))
t3 <- data.frame(Factor = labA, Crude = crudo, Adjusted = ajus)
stopifnot(nrow(dA) == 521, sum(dA$dmg) == 75)
write.csv(t3, "resultados/final_tabla3.csv", row.names = FALSE)

## Diagnósticos del modelo A
vif <- sapply(covA, function(t) { r2 <- summary(lm(as.formula(paste(t, "~", paste(setdiff(covA, t), collapse = "+"))), data = dA))$r.squared; 1 / (1 - r2) })
diag_A <- data.frame(Factor = labA, VIF = sprintf("%.2f", vif))
pred_gt1_A <- sum(fitted(mA) > 1)
lb <- tryCatch({ glm(fA, family = binomial(link = "log"), data = dA, start = coef(mA)); "converged" },
               error = function(e) "did not converge")
write.csv(diag_A, "resultados/final_vif_modeloA.csv", row.names = FALSE)

## ---------- Tabla 4: desenlaces ----------
mat <- d[!is.na(d$ces), ]; sg <- mat[mat$singleton == 1, ]
stopifnot(nrow(mat) == 517, nrow(sg) == 510)
## Apgar <7 a los 5 min derivado de la puntuación numérica registrada (dato primario; el código clínico es discordante: ver Tabla S5)
sg$apgar5 <- as.integer(sg$`*APGAR 5 MINUTOS` < 7)
sg$anom   <- sg$`codigo defectos congenitos si no`
sg$pret   <- as.integer(grepl("^Pret", sg$`*EG RN`))
cnt <- function(y, dat) c(np(sum(dat[[y]][dat$dmg == 1], na.rm = TRUE), sum(!is.na(dat[[y]][dat$dmg == 1]))),
                          np(sum(dat[[y]][dat$dmg == 0], na.rm = TRUE), sum(!is.na(dat[[y]][dat$dmg == 0]))))
cesA <- ces_std(mat, "imc")
t4 <- rbind(
  c("Cesarean delivery", "Mothers", cnt("ces", mat), fmt(cesA), "Adjusted^a"),
  c("Hypertensive disorders", "Mothers", cnt("hta", mat), fmt(pois(hta ~ dmg + imc + EDAD + gestas, mat)), "Adjusted^b"),
  c("Large for gestational age", "Singletons", cnt("lga", sg), fmt(pois(lga ~ dmg + imc + EDAD, sg)), "Adjusted^c"),
  c("Macrosomia (≥4000 g)", "Singletons", cnt("macro", sg), fmt(pois(macro ~ dmg + imc + EDAD, sg)), "Adjusted^c"),
  c("Neonatal hypoglycemia", "Singletons", cnt("hipo", sg), fmt(crude("hipo", sg)), "Crude, exploratory"),
  c("Neonatal polycythemia", "Singletons", cnt("poli", sg), fmt(crude("poli", sg)), "Crude, exploratory"),
  c("Apgar score <7 at 5 min", "Singletons", cnt("apgar5", sg), "Not estimated", ""),
  c("Congenital anomaly (any recorded)", "Singletons", cnt("anom", sg), "Not estimated", ""),
  c("Preterm birth", "Singletons", cnt("pret", sg), "Not estimated", ""))
colnames(t4) <- c("Outcome", "Population", "GDM", "NoGDM", "RR", "Type")
write.csv(t4, "resultados/final_tabla4.csv", row.names = FALSE)

## ---------- Suplemento ----------
## S-b: modelo B (+ patrón F3 por 1 DE)
d$F3z <- as.numeric(scale(d$F3))
fB <- update(fA, . ~ . + F3z); dB <- d[complete.cases(d[, all.vars(fB)]), ]
mB <- glm(fB, family = poisson, data = dB); vB <- vcovHC(mB, type = "HC0")
tB <- data.frame(Factor = c(labA, "“Traditional Ecuadorian” dietary score (per 1 SD)"),
                 RR = sapply(c(covA, "F3z"), function(t) fmt(ci3(mB, vB, t))))
write.csv(tB, "resultados/final_modeloB.csv", row.names = FALSE)

## S-c: cesárea Poisson vs logística estandarizada; diagnósticos
mP <- glm(ces ~ dmg + ces_prev + imc + EDAD + gestas, family = poisson, data = mat)
ces_cmp <- rbind(c("Modified Poisson (HC0)", fmt(pois(ces ~ dmg + ces_prev + imc + EDAD + gestas, mat)), sum(fitted(mP) > 1)),
                 c("Logistic regression + marginal standardization", fmt(cesA), "0"))
colnames(ces_cmp) <- c("Method", "RR", "Pred_gt1")
write.csv(ces_cmp, "resultados/final_cesarea_metodos.csv", row.names = FALSE)
dg <- data.frame(Model = c("GDM model A", "Hypertensive disorders", "LGA (singletons)", "Macrosomia (singletons)"),
  Pred_gt1 = c(pred_gt1_A,
    sum(fitted(glm(hta ~ dmg + imc + EDAD + gestas, family = poisson, data = mat)) > 1),
    sum(fitted(glm(lga ~ dmg + imc + EDAD, family = poisson, data = sg)) > 1),
    sum(fitted(glm(macro ~ dmg + imc + EDAD, family = poisson, data = sg)) > 1)))
dg$LogBinomial <- c(lb, "", "", "")
write.csv(dg, "resultados/final_diagnosticos.csv", row.names = FALSE)

## S-d: ajuste secuencial GEG / macrosomía
seqt <- do.call(rbind, lapply(c("lga", "macro"), function(y) rbind(
  c(y, "None", fmt(pois(as.formula(paste(y, "~ dmg")), sg))),
  c(y, "BMI", fmt(pois(as.formula(paste(y, "~ dmg + imc")), sg))),
  c(y, "BMI and age", fmt(pois(as.formula(paste(y, "~ dmg + imc + EDAD")), sg))))))
colnames(seqt) <- c("Outcome", "Adjustment", "RR")
write.csv(seqt, "resultados/final_secuencial.csv", row.names = FALSE)

cat("\n== Tabla 3\n"); print(t3, row.names = FALSE)
cat("\n== Tabla 4\n"); print(t4, quote = FALSE)


## ---------- Sensibilidad: definición de DMG en los modelos de desenlaces ----------
## (a) D1 excluyendo el caso en rango de diabetes franca; (b) D2 positiva vs D2 no positiva (evaluables, sin diabetes franca)
sens_def <- function(dat) {
  mt <- dat[!is.na(dat$ces), ]; s <- mt[mt$singleton == 1, ]
  ev <- function(y, x) sprintf("%d/%d vs %d/%d", sum(x[[y]][x$dmg == 1], na.rm = TRUE), sum(!is.na(x[[y]][x$dmg == 1])),
                               sum(x[[y]][x$dmg == 0], na.rm = TRUE), sum(!is.na(x[[y]][x$dmg == 0])))
  rbind(c("Cesarean delivery", ev("ces", mt), fmt(ces_std(mt, "imc"))),
        c("Hypertensive disorders", ev("hta", mt), fmt(pois(hta ~ dmg + imc + EDAD + gestas, mt))),
        c("Macrosomia (≥4000 g)", ev("macro", s), fmt(pois(macro ~ dmg + imc + EDAD, s))),
        c("Large for gestational age", ev("lga", s), fmt(pois(lga ~ dmg + imc + EDAD, s))))
}
dA_ <- d[!d$overt, ]
dB_ <- d[d$d2_eval & !d$overt, ]; dB_$dmg <- dB_$d2
sdef <- cbind(sens_def(dA_), sens_def(dB_)[, 2:3])
## (c) D1 con ajuste adicional por establecimiento de captación
mt_ <- d[!is.na(d$ces), ]; s_ <- mt_[mt_$singleton == 1, ]
ces_site <- function(dat, B = 2000) {
  f <- ces ~ dmg + ces_prev + imc + EDAD + gestas + hgoia
  dat <- dat[complete.cases(dat[, all.vars(f)]), ]
  rr <- function(x) { m <- glm(f, family = binomial, data = x)
    mean(predict(m, transform(x, dmg = 1), type = "response")) / mean(predict(m, transform(x, dmg = 0), type = "response")) }
  set.seed(2026); bt <- replicate(B, rr(dat[sample(nrow(dat), replace = TRUE), ]))
  c(rr(dat), quantile(bt, c(.025, .975))) }
site_rr <- c(fmt(ces_site(mt_)), fmt(pois(hta ~ dmg + imc + EDAD + gestas + hgoia, mt_)),
             fmt(pois(macro ~ dmg + imc + EDAD + hgoia, s_)), fmt(pois(lga ~ dmg + imc + EDAD + hgoia, s_)))
sdef <- cbind(sdef, site_rr)
colnames(sdef) <- c("Outcome", "D1_noovert_events", "D1_noovert_RR", "D2_events", "D2_RR", "D1_site_RR")
write.csv(sdef, "resultados/final_sens_definicion.csv", row.names = FALSE)
print(sdef, quote = FALSE)
## Estabilidad con pocos eventos: RR al excluir uno a uno los recién nacidos con el evento (D1, modelo principal)
loo <- function(y) { ids <- s_$id[!is.na(s_[[y]]) & s_[[y]] == 1]
  r <- sapply(ids, function(i) pois(as.formula(paste(y, "~ dmg + imc + EDAD")), s_[s_$id != i, ])[1])
  sprintf("%.2f–%.2f", min(r), max(r)) }
loo_tab <- data.frame(Outcome = c("Macrosomia (≥4000 g)", "Large for gestational age"), LOO_range = c(loo("macro"), loo("lga")))
write.csv(loo_tab, "resultados/final_loo.csv", row.names = FALSE)
print(loo_tab)

## ---------- Verificación de resultados finales ----------
stopifnot(t2$Overall[2] == "52/521 (10.0%; 7.7–12.9)", t3$Adjusted[3] == "1.66 (1.11–2.49)",
          t4[1, "RR"] == "1.31 (1.03–1.63)", t4[3, "RR"] == "6.14 (2.35–16.02)", t4[4, "RR"] == "8.28 (3.32–20.64)")
stopifnot("El Excel cambió" = unname(tools::md5sum(cand)) == md5_ini)
cat("\nListo. Archivos en resultados/final_*.csv\n")