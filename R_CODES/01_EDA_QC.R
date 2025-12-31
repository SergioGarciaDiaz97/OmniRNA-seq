#!/usr/bin/env Rscript


# --- 1. ARGUMENTOS ---
suppressPackageStartupMessages(library(argparse))
parser <- ArgumentParser()
parser$add_argument('--matrix_file', required=TRUE, help="Ruta a la matriz de conteos/TPM")
parser$add_argument('--metadata_file', required=TRUE, help="Ruta a los metadatos")
parser$add_argument('--output_dir', required=TRUE, help="Directorio de salida")
parser$add_argument('--grouping_variable', required=TRUE, help="Columna de grupo en metadatos")
parser$add_argument('--matrix_type', default="TPM", help="Tipo de datos (TPM, Counts)")
parser$add_argument('--top_n_genes', type="integer", default=50, help="Genes para heatmap")
parser$add_argument('--organism_db', required=TRUE, help="Paquete de anotacion (ej: org.Hs.eg.db)")
parser$add_argument('--key_type', required=TRUE, help="Tipo de clave (ej: ENSEMBL)")
args <- parser$parse_args()

# --- 2. LIBRERIAS ---
cat("\n[1/7] 📦 Inicializando entorno analitico...\n")
pkgs <- c("ggplot2", "pheatmap", "RColorBrewer", "dplyr", "tibble", "matrixStats", 
          "ggrepel", "AnnotationDbi", "tidyr", "dendextend", args$organism_db)
suppressPackageStartupMessages({invisible(lapply(pkgs, library, character.only = TRUE))})

# --- 3. DATOS ---
cat("[2/7] 📂 Ingestando y normalizando datos...\n")
dir.create(args$output_dir, showWarnings = FALSE, recursive = TRUE)
tryCatch({
  sep <- ifelse(grepl("\\.tsv$", args$matrix_file), "\t", ",")
  mat <- read.table(args$matrix_file, header=TRUE, sep=sep, row.names=1, check.names=FALSE)
  meta <- read.csv(args$metadata_file, row.names=1, header=TRUE, check.names=FALSE)
}, error = function(e) stop("FATAL ERROR: No se pudieron leer los archivos. ", e$message))

common <- intersect(rownames(meta), colnames(mat))
if(length(common) < 3) stop("FATAL ERROR: N insuficiente (<3 muestras comunes).")
mat <- mat[, common]; meta <- meta[common, , drop=FALSE]
mat_log2 <- log2(mat + 1)

# --- 4. VISUALIZACION BASICA---
cat("[3/7] 📊 Generando metricas de distribucion...\n")
df_long <- as.data.frame(mat_log2) %>% rownames_to_column("g") %>% 
  pivot_longer(-g, names_to="s", values_to="v") %>% left_join(rownames_to_column(meta, "s"), by="s")

# Título dinámico del eje Y
y_lab_str <- paste0("Log2(", args$matrix_type, " + 1)")

p_dist <- ggplot(df_long, aes(x=s, y=v, fill=.data[[args$grouping_variable]])) + 
  geom_violin(trim=FALSE, alpha=0.6) + 
  geom_boxplot(width=0.1, fill="white", outlier.shape=NA) + 
  theme_bw() + 
  theme(axis.text.x=element_text(angle=90, hjust=1, vjust=0.5)) +
  labs(title="Distribucion de Expresion por Muestra", x="Muestra", y=y_lab_str)

ggsave(file.path(args$output_dir, "1_Distribution_Check.pdf"), p_dist, width=12, height=8)

ggsave(file.path(args$output_dir, "2_Variance_Structure.pdf"), 
       ggplot(data.frame(m=rowMeans(mat_log2), s=rowSds(as.matrix(mat_log2))), aes(x=m, y=s)) + geom_point(alpha=0.1) + geom_smooth(color="red") + theme_bw() + labs(title="Tendencia Media-Varianza", x="Media de Expresion (Log2)", y="Desviacion Estandar"))

# --- 5. PCA AUTOMATIZADO ---
cat("[4/7] 🧭 Calculando componentes principales...\n")
vars <- rowVars(as.matrix(mat_log2))
pca <- prcomp(t(mat_log2[vars > 1e-6, ]), scale.=TRUE)
var_exp <- (pca$sdev^2)/sum(pca$sdev^2) * 100 

pdf(file.path(args$output_dir, "3_PCA_Analysis.pdf"), width=10, height=8)
print(ggplot(data.frame(PC=1:10, V=var_exp[1:10]), aes(x=factor(PC), y=V)) + geom_col(fill="#2E86C1") + labs(title="Varianza Explicada por PC", y="% Varianza"))

pca_d <- as.data.frame(pca$x) %>% rownames_to_column("s") %>% left_join(rownames_to_column(meta, "s"), by="s")
for(i in 1:min(4, ncol(pca$x)-1)) {
  xlab_str <- sprintf("PC%d (%.1f%%)", i, var_exp[i])
  ylab_str <- sprintf("PC%d (%.1f%%)", i+1, var_exp[i+1])
  
  p <- ggplot(pca_d, aes(x=.data[[paste0("PC",i)]], y=.data[[paste0("PC",i+1)]], color=.data[[args$grouping_variable]], label=s)) +
    geom_point(size=4, alpha=0.8) + 
    stat_ellipse(level=0.95, linetype=2, alpha=0.5, show.legend = FALSE) + 
    geom_text_repel(max.overlaps=15) + 
    theme_bw() + 
    labs(title=paste0("Mapa Espacial: PC",i," vs PC",i+1), x=xlab_str, y=ylab_str)
  print(p)
}
dev.off()

# --- 6. CLUSTERING & HEATMAPS ---
cat("[5/7] Analizando similitud global...\n")
dist_mat <- dist(t(mat_log2))
dend <- as.dendrogram(hclust(dist_mat, method="complete"))
grps <- unique(meta[[args$grouping_variable]])
cols <- setNames(brewer.pal(max(3, length(grps)), "Set1")[1:length(grps)], grps)
labels_colors(dend) <- cols[meta[labels(dend), args$grouping_variable]]

pdf(file.path(args$output_dir, "4_Dendrogram.pdf"), width=12, height=8)
par(mar=c(10,4,4,8), xpd=TRUE)
plot(dend, main="Jerarquia de Muestras (con Distancias)", ylab="Distancia Euclidea")
axis(2)

tryCatch({
  xy <- get_nodes_xy(dend)
  h_vals <- get_nodes_attr(dend, "height")
  idx <- h_vals > 0.1 
  if(sum(idx) > 0) {
    text(xy[idx, 1], xy[idx, 2], labels = round(h_vals[idx], 2), pos = 3, offset = 0.4, col = "blue", cex = 0.7, font = 2)
  }
}, error=function(e) cat("No se pudieron añadir etiquetas de altura: ", e$message))

legend("topright", inset=c(-0.08,0), legend=names(cols), fill=cols, bty="n", title="Grupo")
dev.off()

pheatmap(cor(mat_log2), annotation_col=meta[args$grouping_variable], filename=file.path(args$output_dir, "5_Sample_Correlation.pdf"))

top <- mat_log2[head(order(vars, decreasing=T), args$top_n_genes), ]
nm <- rownames(top); cl <- gsub("\\..*", "", nm)
sym <- tryCatch(mapIds(get(args$organism_db), keys=cl, column="SYMBOL", keytype=args$key_type, multiVals="first"), error=function(e) cl)
rownames(top) <- make.unique(ifelse(is.na(sym), cl, sym))

# Heatmap 
pheatmap(top, scale="row", annotation_col=meta[args$grouping_variable], fontsize_row=5, border_color=NA, treeheight_row=20, filename=file.path(args$output_dir, "6_Top_Variable_Genes.pdf"))

# --- 7. AUDITORIA outliers---
cat("[6/7] 🧠 Generando Reporte Detallado de Calidad...\n")

pca_audit <- pca_d
pca_audit$Group <- meta[pca_audit$s, args$grouping_variable]
outfile <- file.path(args$output_dir, "7_QC_Report_Automated.txt")
sink(outfile)

cat("==============================================================\n")
cat("   REPORTE DE CALIDAD AUTOMATIZADO (PLATINUM v7.6)\n")
cat("==============================================================\n")
cat("METODO ADAPTATIVO: El script elige la matematica segun la 'N' del grupo.\n\n")
cat("1. Para N < 5 (Grupos Pequenos/Triplicados):\n")
cat("   - Metodo: Clasico (Media y Desviacion Estandar - SD).\n")
cat("   - Logica: Se usan umbrales mas estrictos (2 SD) porque la media es sensible.\n\n")
cat("2. Para N >= 5 (Grupos Grandes):\n")
cat("   - Metodo: Robusto (Mediana y MAD).\n")
cat("   - Logica: Se usan umbrales estandar (3 MAD) porque la mediana es estable.\n\n")

cat("--- DIAGNOSTICO DETALLADO POR GRUPO ---\n\n")

for(g in unique(pca_audit$Group)){
  sub <- pca_audit[pca_audit$Group == g, ]
  if(nrow(sub) < 3) {
    cat(sprintf("⚠️  GRUPO '%s': N=%d. Datos insuficientes para estadistica.\n", g, nrow(sub)))
    next
  }
  use_robust <- nrow(sub) >= 5
  if(use_robust) {
    method_name <- "ROBUSTO (Mediana/MAD)"
    cx <- median(sub$PC1); cy <- median(sub$PC2)
    dists <- sqrt((sub$PC1 - cx)^2 + (sub$PC2 - cy)^2)
    dispersion <- mad(dists)
    if(dispersion == 0) dispersion <- sd(dists) 
    center_val <- median(dists)
    limit_warn <- center_val + (2.5 * dispersion)
    limit_fail <- center_val + (3.0 * dispersion)
    formula_warn <- "Mediana + 2.5 * MAD"
    formula_fail <- "Mediana + 3.0 * MAD"
  } else {
    method_name <- "CLASICO (Media/SD)"
    cx <- mean(sub$PC1); cy <- mean(sub$PC2)
    dists <- sqrt((sub$PC1 - cx)^2 + (sub$PC2 - cy)^2)
    dispersion <- sd(dists)
    center_val <- mean(dists)
    limit_warn <- center_val + (1.5 * dispersion) 
    limit_fail <- center_val + (2.0 * dispersion)
    formula_warn <- "Media + 1.5 * SD"
    formula_fail <- "Media + 2.0 * SD"
  }
  
  cat(sprintf(">>> GRUPO: %s (N=%d)\n", g, nrow(sub)))
  cat("    [CRITERIOS DE CLASIFICACION PARA ESTE GRUPO]\n")
  cat(sprintf("    - Metodo Usado: %s\n", method_name))
  cat(sprintf("    - Dispersion del grupo (Sigma/MAD): %.2f\n", dispersion))
  cat("    - Definicion de Colores:\n")
  cat(sprintf("      ✅ VERDE:   Distancia < %.2f\n", limit_warn))
  cat(sprintf("      🟠 NARANJA: Distancia entre %.2f y %.2f (Formula: %s)\n", limit_warn, limit_fail, formula_warn))
  cat(sprintf("      ❌ ROJO:    Distancia > %.2f             (Formula: %s)\n", limit_fail, formula_fail))
  cat("    ---------------------------------------------------------------\n")
  
  for(i in 1:nrow(sub)){
    s_name <- sub$s[i]
    d_val <- dists[i]
    if(d_val > limit_fail) {
      icon <- "❌"
      label_text <- "ROJO (Outlier)"
      advice <- " -> ACCION: Eliminar (Causa distorsion grave)."
    } else if (d_val > limit_warn) {
      icon <- "🟠"
      label_text <- "NARANJA (Alerta)"
      advice <- " -> ACCION: Revisar reads/calidad. Mantener si es posible."
    } else {
      icon <- "✅"
      label_text <- "VERDE (Optimo)"
      advice <- ""
    }
    cat(sprintf("    %s Muestra: %s\n", icon, s_name))
    cat(sprintf("        • Valor de Distancia: %.2f\n", d_val))
    cat(sprintf("        • Clasificacion:      %s%s\n", label_text, advice))
  }
  cat("\n")
}

cat("--- DISTANCIAS BIOLOGICAS (CENTROIDES) ---\n")
if(length(unique(pca_audit$Group))>1){
  pairs <- combn(unique(pca_audit$Group), 2, simplify=F)
  for(p in pairs){
    g1 <- pca_audit[pca_audit$Group==p[1],]; g2 <- pca_audit[pca_audit$Group==p[2],]
    dc <- sqrt((median(g1$PC1)-median(g2$PC1))^2 + (median(g1$PC2)-median(g2$PC2))^2)
    cat(sprintf("• %s vs %s: %.2f\n", p[1], p[2], dc))
  }
}

sink()
cat(paste0("\n✅ REPORTE EDUCATIVO GENERADO: ", outfile, "\n"))