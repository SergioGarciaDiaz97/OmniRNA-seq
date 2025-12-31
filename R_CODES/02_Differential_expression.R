#!/usr/bin/env Rscript


# --- 1. ARGUMENTOS DE ENTRADA ---
cat("📦 Verificando dependencias y cargando argumentos...\n")
if (!requireNamespace("argparse", quietly = TRUE)) {
  install.packages("argparse", repos="http://cran.us.r-project.org")
}
library(argparse)

parser <- ArgumentParser(description='Pipeline DESeq2 automático con QC, análisis funcional y gráficos.')
parser$add_argument('--counting_method', type="character", required=TRUE)
parser$add_argument('--counts_file', type="character", help="Archivo de conteos")
parser$add_argument('--gtf_file', type="character", help="Archivo GTF (compatible)")
parser$add_argument('--metadata_file', type="character", required=TRUE)
parser$add_argument('--design_formula', type="character", required=TRUE)
parser$add_argument('--control_group', type="character", required=TRUE)
parser$add_argument('--organism_db', type="character", required=TRUE)
parser$add_argument('--key_type', type="character", required=TRUE)
parser$add_argument('--strip_gene_version', type="logical", default=FALSE)
parser$add_argument('--output_dir', type="character", required=TRUE)
parser$add_argument('--padj_threshold', type="double", default=0.05)
parser$add_argument('--log2fc_threshold', type="double", default=1.0)
parser$add_argument('--run_kegg', type="logical", default=FALSE)
parser$add_argument('--gprofiler_organism', type="character")
parser$add_argument('--kegg_padj_threshold', type="double", default=0.05)
args <- parser$parse_args()


# --- 2. CARGA DE PAQUETES ---
cat("📚 Cargando paquetes necesarios...\n")
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos="http://cran.us.r-project.org")
}
pkgs <- c("DESeq2", "AnnotationDbi", "GenomicFeatures", "Rsamtools", "GenomicAlignments",
          "vsn", "ggplot2", "pheatmap", "ggrepel", "dplyr", "tibble",
          args$organism_db, "gprofiler2", "RColorBrewer", "biomaRt", "plotly", "htmlwidgets",
          "grid", "gridExtra", "SummarizedExperiment", "tidyr")
for (p in pkgs) if (!requireNamespace(p, quietly=TRUE)) BiocManager::install(p, ask=FALSE, update=FALSE)
suppressPackageStartupMessages({invisible(lapply(pkgs, library, character.only=TRUE))})


# --- 3. CONFIGURACIÓN INICIAL ---
cat(paste("\n✅ Iniciando análisis para la fórmula:", args$design_formula, "\n"))
dir.create(args$output_dir, showWarnings=FALSE, recursive=TRUE)


# --- 4. CARGA DE MATRIZ DE CONTEOS ---
cat("📥 Cargando matriz de conteos...\n")
if (tolower(args$counting_method) == "featurecounts") {
  matriz_completa <- read.table(args$counts_file, header=TRUE, sep="\t", comment.char="#", check.names=FALSE)
  matriz_conteos <- as.matrix(matriz_completa[,7:ncol(matriz_completa)])
  rownames(matriz_conteos) <- matriz_completa$Geneid
  colnames(matriz_conteos) <- gsub("_Aligned.sortedByCoord.out.bam$","",basename(colnames(matriz_conteos)))
} else if (tolower(args$counting_method) == "precomputed_csv") {
  
  # A. DETECTOR DE SEPARADOR (Coma o Tabulador)
  lineas_test <- readLines(args$counts_file, n = 5)
  sep_detectado <- if(any(grepl("\t", lineas_test))) "\t" else ","
  cat(paste0("    -> Formato detectado: ", ifelse(sep_detectado=="\t", "TSV (Tab)", "CSV (Coma)"), "\n"))
  
  # B. CARGA CON LIMPIEZA
  matriz_conteos <- read.table(args$counts_file, header = TRUE, row.names = 1, 
                               sep = sep_detectado, check.names = FALSE, 
                               quote = "\"", fill = TRUE)
} else {
  stop("❌ Método de conteo no reconocido.")
}

# C. LIMPIEZA DE COLUMNAS (Quitar carácteres raros que mete GEO)
colnames(matriz_conteos) <- gsub(" ", "_", colnames(matriz_conteos)) 
colnames(matriz_conteos) <- gsub("-", "_", colnames(matriz_conteos)) 

matriz_conteos <- as.matrix(matriz_conteos)
storage.mode(matriz_conteos) <- "integer"

if (ncol(matriz_conteos) < 2) stop("❌ La matriz no tiene suficientes muestras.")

# --- 5. QC INICIAL DE CONTEOS CRUDOS ---
cat("🔍 Realizando QC de conteos crudos...\n")
metadata_qc <- read.csv(args$metadata_file, header=TRUE)
total_genes <- nrow(matriz_conteos)
stats_per_sample <- data.frame(
  Sample = colnames(matriz_conteos),
  Total_Reads = colSums(matriz_conteos),
  Genes_Detectados = colSums(matriz_conteos > 0),
  Genes_Silenciados = colSums(matriz_conteos == 0),
  Sparsity_Percent = round((colSums(matriz_conteos == 0) / total_genes) * 100, 2)
)

grouping_vars <- all.vars(as.formula(args$design_formula))
sample_col_name <- colnames(metadata_qc)[1]

stats_df <- stats_per_sample %>%
  dplyr::left_join(metadata_qc, by=setNames(sample_col_name, "Sample"))

full_stats <- stats_df %>%
  dplyr::group_by(dplyr::across(dplyr::all_of(grouping_vars))) %>%
  dplyr::summarise(
    Media_Total_Reads = round(mean(Total_Reads, na.rm=TRUE), 0),
    SD_Total_Reads = round(sd(Total_Reads, na.rm=TRUE), 0),
    Media_Genes_Detectados = round(mean(Genes_Detectados, na.rm=TRUE), 0),
    Media_Sparsity = round(mean(Sparsity_Percent, na.rm=TRUE), 2),
    .groups='drop'
  )

# Guardar estadísticas
write.table(full_stats, file=file.path(args$output_dir,"QC_estadisticas_conteos_crudos_agrupado.txt"), sep="\t", row.names=FALSE, quote=FALSE)
write.table(stats_df, file=file.path(args$output_dir,"QC_estadisticas_conteos_crudos_detalle_muestras.txt"), sep="\t", row.names=FALSE, quote=FALSE)

cat("   -> Estadísticas guardadas: Se han generado dos archivos de QC (agrupado y detalle).\n")

# Histogramas y Boxplots
pdf(file.path(args$output_dir,"QC_histograma_conteos_crudos_log10.pdf"))
hist(log10(as.vector(matriz_conteos)+1), breaks=50, main="Histograma de Conteos Crudos (log10)", xlab="log10(Conteos+1)", col="steelblue")
dev.off()

NUM_SAMPLES <- ncol(matriz_conteos)
SAMPLES_PER_PAGE <- 15
num_pages <- ceiling(NUM_SAMPLES / SAMPLES_PER_PAGE)
pdf(file.path(args$output_dir,"QC_boxplot_conteos_crudos_log10.pdf"), width=max(8, SAMPLES_PER_PAGE * 0.5), height=8)
for (i in 1:num_pages) {
  start_index <- (i - 1) * SAMPLES_PER_PAGE + 1
  end_index <- min(i * SAMPLES_PER_PAGE, NUM_SAMPLES)
  matriz_subset <- matriz_conteos[, start_index:end_index, drop=FALSE]
  par(mar=c(10,4,4,2))
  boxplot(log10(matriz_subset+1), las=2, col="lightblue", main=paste0("Boxplot de Conteos Crudos por Muestra (log10) - Muestras ", start_index, " a ", end_index))
}
par(mar=c(5,4,4,2)); 
dev.off()
cat("✅ QC completado.\n")


# --- 6. PREPARACIÓN Y EJECUCIÓN DE DESEQ2 ---

cat("⚙️ [BLOQUE 6] Iniciando preparación del modelo estadístico...\n")

# 1. Cargar metadatos y asegurar que la primera columna sea el ID de la muestra
metadata <- read.csv(args$metadata_file, header=TRUE, stringsAsFactors=FALSE)
sample_col_name <- colnames(metadata)[1]
rownames(metadata) <- metadata[[sample_col_name]]

# 2. Identificar el factor principal de estudio (último término de la fórmula)
main_factor <- tail(all.vars(as.formula(args$design_formula)), 1)
cat(paste0("   -> Factor biológico detectado: '", main_factor, "'\n"))

# 3. SINCRONIZACIÓN: Asegurar que matriz y metadata tengan las mismas muestras
muestras_comunes <- intersect(rownames(metadata), colnames(matriz_conteos))
if (length(muestras_comunes) == 0) {
  stop("❌ ERROR CRÍTICO: No hay muestras comunes. Revisa los IDs del Metadata y de los FASTQ.")
}

metadata <- metadata[muestras_comunes, , drop=FALSE]
matriz_conteos <- matriz_conteos[, muestras_comunes]

# 4. LIMPIEZA DE NIVELES: Forzar Factor y eliminar niveles vacíos

metadata[[main_factor]] <- as.factor(metadata[[main_factor]])
metadata[[main_factor]] <- droplevels(metadata[[main_factor]])

# 5. CONSTRUCCIÓN DEL OBJETO DESeq2
# Redondeamos los conteos por si vienen de herramientas que generan decimales
dds <- DESeq2::DESeqDataSetFromMatrix(
  countData = round(matriz_conteos), 
  colData = metadata, 
  design = as.formula(args$design_formula)
)

# 6. FILTRADO DE PRE-PROCESAMIENTO: Eliminar "ruido" genómico

genes_antes <- nrow(dds)
dds <- dds[rowSums(DESeq2::counts(dds)) >= 10, ]
genes_despues <- nrow(dds)
cat(paste0("   -> Filtrado: de ", genes_antes, " genes, nos quedamos con ", genes_despues, " (con counts >= 10).\n"))

# 7. FIJAR EL NIVEL DE REFERENCIA (CONTROL)

if (!(args$control_group %in% levels(metadata[[main_factor]]))) {
  stop(paste("❌ ERROR: El grupo control", args$control_group, "no existe en la columna", main_factor))
}
dds[[main_factor]] <- relevel(dds[[main_factor]], ref = args$control_group)

# 8. EJECUCIÓN DEL MODELO ESTADÍSTICO
# Calculamos dispersión y Wald Test para todos los niveles de una sola vez
cat("   -> Ejecutando DESeq(). Esto puede tardar unos minutos en humanos...\n")
dds <- DESeq2::DESeq(dds)

cat("✅ [BLOQUE 6] Modelo DESeq2 finalizado. Listo para extraer contrastes.\n")

process_and_plot_results <- function(res, dds, contraste_name, args) {
  res_ordered <- res[order(res$padj),]
  res_df <- as.data.frame(res_ordered) %>% tibble::rownames_to_column(var="gene_id")
  res_df$symbol <- NA
  
  # --- LÓGICA DE ANOTACIÓN INTELIGENTE (para levadura)---
  if (args$organism_db == "org.Hs.eg.db") {
    cat("        -> 💬 Anotando genes (humano) con biomaRt...\n")
    tryCatch({
      ids_sin_version <- if (args$strip_gene_version) sub("\\..*$","",res_df$gene_id) else res_df$gene_id
      ensembl <- biomaRt::useMart(biomart="ENSEMBL_MART_ENSEMBL", dataset="hsapiens_gene_ensembl", host="https://www.ensembl.org")
      gene_map <- biomaRt::getBM(attributes=c('ensembl_gene_id','hgnc_symbol'), filters='ensembl_gene_id', values=ids_sin_version, mart=ensembl)
      res_df <- res_df %>%
        dplyr::mutate(ensembl_gene_id_sin_version=sub("\\..*$","",gene_id)) %>%
        dplyr::left_join(gene_map, by=c("ensembl_gene_id_sin_version"="ensembl_gene_id")) %>%
        dplyr::mutate(symbol=ifelse(!is.na(hgnc_symbol)&hgnc_symbol!="",hgnc_symbol,NA_character_)) %>%
        dplyr::select(-ensembl_gene_id_sin_version,-hgnc_symbol)
      cat("        -> ✅ Anotación con biomaRt completada.\n")
    }, error=function(e) { cat(paste("        -> ⚠️ biomaRt falló, continuando sin anotación. Error:", e$message, "\n")) })
  } else {

    ids <- if (args$strip_gene_version) sub("\\..*$","",res_df$gene_id) else res_df$gene_id
    
    # --- DETECCIÓN DINÁMICA DE COLUMNAS ---
    org_db_loaded <- get(args$organism_db)
    available_cols <- columns(org_db_loaded)
    
    # Determinar qué columna usar para el nombre del gen
    target_symbol_col <- "SYMBOL" 
    if (!"SYMBOL" %in% available_cols) {
      if ("GENENAME" %in% available_cols) {
        target_symbol_col <- "GENENAME" # Común en Levadura/Hongos
      } else if ("COMMON" %in% available_cols) {
        target_symbol_col <- "COMMON"
      } else {
        target_symbol_col <- args$key_type 
      }
    }
    
    cat(paste0("        -> ℹ️ Usando columna '", target_symbol_col, "' para nombres de genes (Universal Fix).\n"))
    
    if (args$key_type == "SYMBOL" || args$key_type == "GENENAME") {
      cat("        -> ℹ️ El ID ya es SYMBOL/Nombre. Saltando mapeo de base de datos...\n")
      res_df$symbol <- res_df$gene_id 
    } else {
      cat(paste0("        -> 🧬 Mapeando IDs usando ", args$organism_db, "...\n"))
      org_db_loaded <- get(args$organism_db)
      
      tryCatch({
        res_df$symbol <- AnnotationDbi::mapIds(
          org_db_loaded, 
          keys = ids, 
          column = target_symbol_col, 
          keytype = args$key_type, 
          multiVals = "first"
        )
      }, error = function(e) {
        cat(paste("        -> ⚠️ Falló mapIds. Usando IDs originales. Error:", e$message, "\n"))
        res_df$symbol <- res_df$gene_id
      })
    }
  }
    
  
  
    
  write.table(res_df, file=file.path(args$output_dir, paste0("Resultados_Completos_", contraste_name, ".txt")), sep="\t", quote=FALSE, row.names=FALSE, na="")
  
  res_sig <- res_df %>%
    dplyr::filter(!is.na(padj), padj < args$padj_threshold, abs(log2FoldChange) >= args$log2fc_threshold)
  write.table(res_sig, file=file.path(args$output_dir, paste0("Resultados_Significativos_", contraste_name, ".txt")), sep="\t", quote=FALSE, row.names=FALSE, na="")
  cat(paste0("        -> Encontrados ", nrow(res_sig), " genes significativos para '", contraste_name, "'.\n"))
  
  
  # --- Gráfico MA Plot ---
  res_ma <- res
  res_ma$col <- "gray60"
  sig_indices <- which(!is.na(res_ma$padj) & res_ma$padj < args$padj_threshold & abs(res_ma$log2FoldChange) >= args$log2fc_threshold)
  res_ma$col[sig_indices] <- "#377eb8"
  
  pdf(file.path(args$output_dir, paste0("Plot_MA_", contraste_name, ".pdf")))
  plot(x=log10(res_ma$baseMean), y=res_ma$log2FoldChange, col=res_ma$col, pch=20, main=contraste_name, xlab="Mean of Normalized Counts (log10)", ylab="log2(Fold Change)", ylim=c(-16, 16))
  abline(h=0, col="black", lwd=2)
  abline(h=c(-args$log2fc_threshold, args$log2fc_threshold), col="dodgerblue", lty=2)
  dev.off()

  
  
  # ============================================================================
  #  VOLCANO PLOT INTERACTIVO PROFESIONAL (HTML AUTOCONTENIDO)
  # ============================================================================
  
  cat(paste0("        -> 🎨 Generando Volcano Plot interactivo (Dashboard HTML): ",
             contraste_name, "\n"))
  
  # --- Preparación de datos ---
  min_padj <- min(res_df$padj[res_df$padj > 0], na.rm = TRUE)
  
  volcano_df <- res_df %>%
    dplyr::mutate(
      padj_plot      = ifelse(padj == 0, min_padj, padj),
      neg_log10_padj = -log10(padj_plot),
      regulation = dplyr::case_when(
        log2FoldChange >=  args$log2fc_threshold & padj < args$padj_threshold ~ "Upregulated",
        log2FoldChange <= -args$log2fc_threshold & padj < args$padj_threshold ~ "Downregulated",
        TRUE ~ "Not Significant"
      ),
      hover_text = paste0(
        "<b>🧬 Gen:</b> ", ifelse(!is.na(symbol) & symbol != "", symbol, gene_id), "<br>",
        "━━━━━━━━━━━━━━━━━━<br>",
        "<b>📈 Log2FC:</b> ", round(log2FoldChange, 3), "<br>",
        "<b>🎯 P-ajustada:</b> ", formatC(padj, format = "e", digits = 2), "<br>",
        "<b>📊 Estado:</b> ", regulation, "<br>",
        "<i>BaseMean:</i> ", round(baseMean, 1)
      )
    )
  
  # --- Volcano interactivo con Plotly nativo ---
  volcano_plot <- plotly::plot_ly(
    data  = volcano_df,
    x     = ~log2FoldChange,
    y     = ~neg_log10_padj,
    type  = "scatter",
    mode  = "markers",
    color = ~regulation,
    colors = c(
      "Upregulated"     = "#d73027",
      "Downregulated"   = "#4575b4",
      "Not Significant" = "grey80"
    ),
    marker    = list(size = 6, opacity = 0.75),
    text      = ~hover_text,
    hoverinfo = "text",
    width     = 1100,
    height    = 650
  ) %>%
    plotly::layout(
      title = list(
        text = paste0("<b>Volcano Plot Interactivo</b><br>", contraste_name),
        x    = 0.5
      ),
      xaxis = list(
        title      = "Log2 Fold Change",
        fixedrange = FALSE   
      ),
      yaxis = list(
        title      = "-Log10(P-ajustada)",
        fixedrange = FALSE   
      ),
      shapes = list(
        # Líneas verticales (log2FC)
        list(type = "line",
             x0 =  args$log2fc_threshold, x1 =  args$log2fc_threshold,
             y0 = 0, y1 = max(volcano_df$neg_log10_padj, na.rm = TRUE),
             line = list(dash = "dash", color = "grey50")),
        list(type = "line",
             x0 = -args$log2fc_threshold, x1 = -args$log2fc_threshold,
             y0 = 0, y1 = max(volcano_df$neg_log10_padj, na.rm = TRUE),
             line = list(dash = "dash", color = "grey50")),
        # Línea horizontal (padj)
        list(type = "line",
             x0 = min(volcano_df$log2FoldChange, na.rm = TRUE),
             x1 = max(volcano_df$log2FoldChange, na.rm = TRUE),
             y0 = -log10(args$padj_threshold),
             y1 = -log10(args$padj_threshold),
             line = list(dash = "dash", color = "grey50"))
      ),
      legend = list(title = list(text = "Regulación")),
      hoverlabel = list(
        bgcolor = "white",
        bordercolor = "black",
        font = list(size = 13)
      )
    ) %>%
    plotly::config(
      displayModeBar = TRUE,
      scrollZoom     = TRUE,
      displaylogo    = FALSE,
      modeBarButtonsToRemove = c(
        "toImage",              
        "select2d",           
        "lasso2d",              
        "resetScale2d",       
        "hoverCompareCartesian",
        "toggleSpikelines"
      )
    )
  
  # --- Header HTML con instrucciones detalladas ---
  html_header <- htmltools::HTML(paste0(
    "<div style='font-family: Arial, sans-serif; padding:15px;
             background:#f8f9fa; border-bottom:3px solid #007bff;'>",
    "<h2>🔬 Volcano Plot Interactivo</h2>",
    "<h3>Contraste: <b>", contraste_name, "</b></h3>",
    "<p><b>Parámetros:</b> Log2FC ≥ ±", args$log2fc_threshold, 
    " | P-ajustada < ", args$padj_threshold, "</p>",
    "<hr>",
    "<p><b>ℹ️ Guía de Navegación (Barra Superior):</b></p>",
    "<ul style='line-height: 1.6;'>",
    "<li><b>✋ Pan (Moverse):</b> Selecciona el icono de la <i>mano</i> ('Pan') para arrastrar el gráfico y moverte por el mapa.</li>",
    "<li><b>🔍 Zoom In (+):</b> Si ves muchos genes juntos o superpuestos, usa el botón <b>(+)</b> para acercarte y separarlos.</li>",
    "<li><b>🔎 Zoom Out (-):</b> Usa el botón <b>(-)</b> para alejarte.</li>",
    "<li><b>🏠 Autoscale:</b> Si te pierdes, pulsa el icono de 'Autoscale' (dos flechas cruzadas) para volver a la vista inicial completa.</li>",
    "<li><b>🖱️ Ratón:</b> También puedes hacer zoom con la rueda del ratón y ver detalles pasando el cursor sobre los puntos.</li>",
    "</ul>",
    "</div>"
  ))
  
  volcano_dashboard <- htmlwidgets::prependContent(volcano_plot, html_header)
  
  htmlwidgets::saveWidget(
    widget = volcano_dashboard,
    file   = file.path(
      args$output_dir,
      paste0("VolcanoPlot_Dashboard_", contraste_name, ".html")
    ),
    selfcontained = TRUE
  )
  
  cat("        -> ✅ Volcano Plot HTML interactivo generado correctamente.\n")
  
  # --- Heatmap Top 30 genes significativos ---
  if (nrow(res_sig) >= 2) {
    top <- res_sig %>% dplyr::arrange(padj) %>% head(30)
    mat <- SummarizedExperiment::assay(DESeq2::vst(dds, blind=FALSE))[top$gene_id,]
    rownames(mat) <- dplyr::coalesce(top$symbol, top$gene_id)
    annotation_cols <- as.data.frame(SummarizedExperiment::colData(dds)[,all.vars(as.formula(args$design_formula)),drop=FALSE])
    pheatmap::pheatmap(mat, color=colorRampPalette(rev(RColorBrewer::brewer.pal(9,"RdYlBu")))(255), cluster_rows=TRUE, cluster_cols=TRUE,
                       annotation_col=annotation_cols, scale="row",
                       main=paste("Top 30 Genes Diferenciales -", contraste_name),
                       filename=file.path(args$output_dir,paste0("Plot_Heatmap_",contraste_name,".pdf")),
                       width=10, height=12)
  }
  
  
  # --- ANÁLISIS FUNCIONAL CON G:PROFILER ---
  if(args$run_kegg && nrow(res_sig) > 0) {
    cat("\n        -> Ejecutando análisis funcional con g:Profiler avanzado...\n")
    
    FUENTES_DATOS <- c("GO:MF", "GO:BP", "GO:CC", "KEGG", "REAC")
    STRIP_GENE_VERSION <- args$strip_gene_version
    LOG2FC_THRESHOLD <- args$log2fc_threshold
    
    output_completo_filename <- file.path(args$output_dir, paste0("Analisis_Completo_ORDENADO_", contraste_name, ".txt"))
    output_huerfanos_filename <- file.path(args$output_dir, paste0("genes_huerfanos_", contraste_name, ".txt"))
    ORGANISMO <- args$gprofiler_organism
    
    lista_genes_significativos <- res_sig$gene_id
    if (STRIP_GENE_VERSION) lista_genes_significativos <- sub("\\..*$", "", lista_genes_significativos)
    lista_genes_significativos <- unique(lista_genes_significativos)
    
    gost_results <- tryCatch({
      gprofiler2::gost(query = lista_genes_significativos,
                       organism = ORGANISMO,
                       sources = FUENTES_DATOS,
                       user_threshold = args$kegg_padj_threshold,
                       correction_method = "g_SCS",
                       domain_scope = "annotated",
                       evcodes = TRUE)
    }, error = function(e) {
      cat("❌ ERROR en g:Profiler:", e$message, "\n")
      return(NULL)
    })
    
    if (is.null(gost_results) || is.null(gost_results$result) || nrow(gost_results$result) == 0) {
      cat("❌ g:Profiler no devolvió resultados.\n")
    } else {
      gprofiler_data_correcta <- gost_results$result
      cat(paste("        -> ¡Éxito! g:Profiler encontró", nrow(gprofiler_data_correcta), "términos enriquecidos.\n"))
      
      rutas_expandidas <- gprofiler_data_correcta %>%
        dplyr::select(term_id, term_name, source, intersection) %>%
        tidyr::separate_rows(intersection, sep = ",") %>%
        dplyr::rename(join_key = intersection) %>%
        dplyr::mutate(
          join_key_id = ifelse(startsWith(join_key, "ENS"), trimws(join_key), NA_character_),
          join_key_symbol = ifelse(startsWith(join_key, "ENS"), NA_character_, toupper(trimws(join_key)))
        )
      
      deseq_con_key <- res_sig %>%
        dplyr::mutate(
          log2FoldChange_num = as.numeric(log2FoldChange),
          padj_num = as.numeric(padj),
          join_key_id = gene_id,
          join_key_symbol = toupper(trimws(symbol))
        )
      if (STRIP_GENE_VERSION) {
        deseq_con_key$join_key_id <- sub("\\..*$", "", deseq_con_key$join_key_id)
      }
      
      join_por_id <- rutas_expandidas %>%
        dplyr::filter(!is.na(join_key_id)) %>%
        dplyr::left_join(deseq_con_key, by = "join_key_id")
      
      join_por_symbol <- rutas_expandidas %>%
        dplyr::filter(!is.na(join_key_symbol)) %>%
        dplyr::left_join(deseq_con_key, by = "join_key_symbol")
      
      datos_finales_ordenados <- dplyr::bind_rows(join_por_id, join_por_symbol) %>%
        dplyr::filter(!is.na(gene_id)) %>% 
        dplyr::select(source, term_id, term_name, gene_id, symbol,
                      log2FoldChange_num, padj_num, baseMean) %>%
        dplyr::mutate(Regulacion = ifelse(log2FoldChange_num > LOG2FC_THRESHOLD, "UP", "DOWN")) %>%
        dplyr::arrange(padj_num) %>%
        dplyr::distinct()
      
      cat("✅ Datos finales de análisis funcional (enriquecimiento) listos.\n")
      
      tryCatch({
        datos_finales_para_txt <- datos_finales_ordenados %>%
          dplyr::left_join(gprofiler_data_correcta %>% dplyr::select(term_name, p_value), by = "term_name") %>%
          dplyr::arrange(source, p_value) %>%
          dplyr::mutate(
            log2FoldChange = round(log2FoldChange_num, 3),
            padj_gene = format(padj_num, scientific = TRUE, digits = 3),
            baseMean = round(as.numeric(baseMean), 1)
          ) %>%
          dplyr::select(source, term_id, term_name, gene_id, symbol, Regulacion,
                        log2FoldChange, padj_gene, baseMean)
        
        write.table(datos_finales_para_txt, output_completo_filename, row.names = FALSE, na = "", sep = "\t", quote = FALSE)
        cat(paste("        -> TXT Completo Ordenado guardado en", output_completo_filename, "\n"))
      }, error = function(e) {
        cat("⚠️ Error al guardar TXT:", e$message, "\n")
      })
      
      
      
      # --- 1. Guardar Analisis_Rutas_Enriquecidas.txt (El resumen de g:Profiler) ---
      output_rutas_filename <- file.path(args$output_dir, paste0("Analisis_Rutas_Enriquecidas_", contraste_name, ".txt"))
      tryCatch({

        resumen_rutas <- gprofiler_data_correcta %>%
          dplyr::select(source, term_id, term_name, p_value, query_size, term_size, intersection_size, intersection) %>%
          dplyr::arrange(source, p_value)
        
        write.table(resumen_rutas, output_rutas_filename, row.names = FALSE, na = "", sep = "\t", quote = FALSE)
        cat(paste("        -> TXT Resumen de Rutas guardado en", output_rutas_filename, "\n"))
      }, error = function(e) {
        cat("⚠️ Error al guardar TXT de Resumen de Rutas:", e$message, "\n")
      })
      
      # --- 2. Guardar Informe Resumen de Vías Significativas  ---
      output_resumen_filename <- file.path(args$output_dir, paste0("Informe_Resumen_Vias_", contraste_name, ".txt"))
      tryCatch({
        old_max_print <- options(max.print = 99999) 
        on.exit(options(old_max_print), add = TRUE) 
        
        # Contar vías por fuente
        resumen_conteo <- gprofiler_data_correcta %>%
          dplyr::group_by(source) %>%
          dplyr::summarise(Vias_Significativas = n()) %>%
          dplyr::arrange(source)
        
        # Obtener TODAS las vías, ordenadas por p-valor
        todas_las_vias_ordenadas <- gprofiler_data_correcta %>%
          dplyr::arrange(p_value) %>%
          dplyr::select(term_name, source, p_value) %>%
          dplyr::mutate(p_value = format(p_value, scientific = TRUE, digits = 3))
        
        # Escribir el informe resumen
        sink(output_resumen_filename)
        cat("====================================================\n")
        cat(paste("INFORME RESUMEN DE VÍAS SIGNIFICATIVAS\n"))
        cat(paste("Contraste:", contraste_name, "\n"))
        cat(paste("Fecha:", Sys.Date(), "\n"))
        cat("====================================================\n\n")
        
        cat(paste("Total de genes significativos analizados:", length(lista_genes_significativos), "\n"))
        cat(paste("Total de vías enriquecidas encontradas:", nrow(gprofiler_data_correcta), "\n\n"))
        
        cat("--- Conteo de Vías por Fuente ---\n")
        print(as.data.frame(resumen_conteo), row.names = FALSE)
        cat("\n")
        
        cat("--- Todas las Vías Significativas (Ordenadas por p-valor) ---\n")
        print(as.data.frame(todas_las_vias_ordenadas), row.names = FALSE)
        cat("\n")
        
        sink()
        
        cat(paste("        -> Informe Resumen TXT (versión completa) guardado en", output_resumen_filename, "\n"))
      }, error = function(e) {
        cat("⚠️ Error al guardar el Informe Resumen TXT:", e$message, "\n")
      })
      
      
      
      cat(paste("        -> Buscando genes huérfanos...\n"))
      genes_mapeados_en_rutas <- unique(datos_finales_ordenados$gene_id)
      sig_genes_data_con_key <- res_sig
      if (STRIP_GENE_VERSION) {
        sig_genes_data_con_key$gene_id_sin_version <- sub("\\..*$", "", sig_genes_data_con_key$gene_id)
      } else {
        sig_genes_data_con_key$gene_id_sin_version <- sig_genes_data_con_key$gene_id
      }
      ids_huerfanos <- setdiff(sig_genes_data_con_key$gene_id_sin_version, genes_mapeados_en_rutas)
      tabla_huerfanos_completa <- sig_genes_data_con_key %>%
        dplyr::filter(gene_id_sin_version %in% ids_huerfanos) %>%
        dplyr::select(-gene_id_sin_version) 
      
      total_huerfanos <- nrow(tabla_huerfanos_completa)
      sin_simbolo <- sum(is.na(tabla_huerfanos_completa$symbol) | tabla_huerfanos_completa$symbol == "")
      simbolo_raro <- sum(grepl("^(LOC|si:|zgc:)", tabla_huerfanos_completa$symbol))
      anotados_reales <- total_huerfanos - sin_simbolo - simbolo_raro
      total_genes_originales <- length(lista_genes_significativos)
      total_genes_mapeados <- length(genes_mapeados_en_rutas)
      
      cat(paste("        -> ¡Encontrados!", total_huerfanos, "genes huérfanos.\n"))
      cat(paste("              - Sin símbolo:", sin_simbolo, "\n"))
      cat(paste("              - Símbolo no informativo (LOC/si/zgc):", simbolo_raro, "\n"))
      cat(paste("              - Con símbolo real (pero en rutas no enriquecidas):", anotados_reales, "\n"))
      
      tryCatch({
        write.table(tabla_huerfanos_completa, output_huerfanos_filename, row.names = FALSE, na = "", sep = "\t", quote = FALSE)
        cat(paste("        -> Tabla de huérfanos guardada en:", output_huerfanos_filename, "\n"))
      }, error = function(e) {
        cat("⚠️ Error al guardar tabla de huérfanos:", e$message, "\n")
      })
    }
  }
}

# ============================================================================
# --- 8. BUCLE DE CONTRASTES MULTI-GRUPO (MODO PLANO - SIN SUBCARPETAS) ---
# ============================================================================
cat("\n🚀 [BLOQUE 8] Extrayendo resultados (Modo Plano: todo al mismo directorio)...\n")

# 1. Identificar el factor y los tratamientos
main_factor <- tail(all.vars(as.formula(args$design_formula)), 1)
todos_los_niveles <- levels(dds[[main_factor]])
control_ref <- args$control_group

# Filtramos: comparamos todos los niveles contra el Control
comparaciones <- todos_los_niveles[todos_los_niveles != control_ref]

cat(paste0("   -> Control: ", control_ref, "\n"))
cat(paste0("   -> Tratamientos a procesar: ", paste(comparaciones, collapse=", "), "\n"))

# 2. BUCLE: Un análisis por cada tratamiento
for (cond in comparaciones) {
  
  # Nombre del contraste para los archivos 
  contraste_id <- paste0(cond, "_vs_", control_ref)
  contraste_id <- gsub("[^A-Za-z0-9_]", "_", contraste_id) 
  
  cat(paste0("\n📊 [GENERANDO ARCHIVOS PARA]: ", contraste_id, "\n"))
  
  # --- A. EXTRAER RESULTADOS ---
  res <- DESeq2::results(dds, contrast = c(main_factor, cond, control_ref))
  
  tryCatch({
    process_and_plot_results(res, dds, contraste_id, args)
    cat(paste0("   -> ✅ Archivos de '", cond, "' generados en el directorio principal.\n"))
  }, error = function(e) {
    cat(paste0("   -> ❌ ERROR en contraste ", cond, ": ", e$message, "\n"))
  })
}

cat("\n================================================================\n")
cat("🎯 [FINALIZADO] Todos los archivos .txt y .html están listos.\n")
cat("================================================================\n")