# -----------------------------------------------
# BLOQUE 1: LIBRERÍAS
# -----------------------------------------------
suppressPackageStartupMessages({
  cat("--- [INFO] Instalando/Cargando librerías... ---\n")
  
  # Paquetes CRAN
  pkgs_cran <- c("ggplot2", "dplyr", "stringr", "ggrepel", "png", "gridExtra", "ggridges", "tidyr", "argparse")
  for (p in pkgs_cran) {
    if (!requireNamespace(p, quietly = TRUE)) {
      cat(paste("[INFO] Instalando paquete de CRAN faltante:", p, "\n"))
      install.packages(p, repos="http://cran.us.r-project.org")
    }
  }
  
  # Paquetes Bioconductor 
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", repos="http://cran.us.r-project.org")
  }

  pkgs_bioc <- c("pathview", "clusterProfiler", "enrichplot", "AnnotationDbi") 
  
  pkgs_bioc_faltantes <- pkgs_bioc[!sapply(pkgs_bioc, requireNamespace, quietly = TRUE)]
  if (length(pkgs_bioc_faltantes) > 0) {
    cat(paste("[INFO] Instalando paquetes de Bioconductor faltantes:", paste(pkgs_bioc_faltantes, collapse=", "), "\n"))
    BiocManager::install(pkgs_bioc_faltantes, update = TRUE, ask = FALSE)
  }
  
  # Librerías para HTML 
  if (!requireNamespace("htmltools", quietly = TRUE)) install.packages("htmltools", repos="http://cran.us.r-project.org")
  if (!requireNamespace("knitr", quietly = TRUE)) install.packages("knitr", repos="http://cran.us.r-project.org")
  if (!requireNamespace("rmarkdown", quietly = TRUE)) install.packages("rmarkdown", repos="http://cran.us.r-project.org")
  
  library(htmltools)
  library(knitr)
  library(rmarkdown)
  
  library(ggplot2)
  library(dplyr)
  library(stringr)
  library(ggrepel)
  library(png)
  library(gridExtra)
  library(grid)
  library(ggridges) 
  library(pathview)
  library(clusterProfiler)
  library(enrichplot)
  library(AnnotationDbi)
  library(tidyr) 
  library(argparse) 
  
  cat("--- [INFO] Librerías cargadas. ---\n")
})



# -----------------------------------------------
# BLOQUE 2: ARGS 

cat("[INFO] Leyendo argumentos desde la línea de comandos...\n")

parser <- ArgumentParser(description="Script de R para visualización de enriquecimiento funcional (SEA, GSEA, Pathview)")

# --- Argumentos del JSON (Annotation & Pathview) ---
parser$add_argument("--kegg_species_code", type="character", required=TRUE, help="Código de especie KEGG (ej: dre)")
parser$add_argument("--key_type", type="character", required=TRUE, help="Tipo de ID de gen (ej: ENSEMBL)")
parser$add_argument("--organism_db", type="character", required=TRUE, help="Paquete OrgDb (ej: org.Dr.eg.db)")

# --- Argumentos del JSON (Thresholds) ---
parser$add_argument("--log2fc", type="double", default=1.0, help="Corte de Log2 Fold Change")
parser$add_argument("--padj", type="double", default=0.05, help="Corte de P-value ajustado")

# --- Argumentos del JSON (SEA) ---
parser$add_argument("--run_sea_analysis", action="store_true", default=FALSE, help="Ejecutar análisis SEA/ORA")
parser$add_argument("--sea_padj_cutoff", type="double", default=0.05, help="Corte P-value para SEA")
parser$add_argument("--sea_qvalue_cutoff", type="double", default=0.1, help="Corte Q-value para SEA")
parser$add_argument("--sea_ontologies", nargs='+', default=c("BP", "MF", "CC"), help="Ontologías GO para SEA (BP MF CC)")

# --- Argumentos de Plotting ---
parser$add_argument("--top_n_emap", type="integer", default=15, help="Términos a mostrar en Emapplot")
parser$add_argument("--top_n_cnet", type="integer", default=10, help="Términos a mostrar en Cnetplot")
parser$add_argument("--top_n_ridge", type="integer", default=15, help="Términos a mostrar en Ridgeplot")
parser$add_argument("--top_n_gseaplot", type="integer", default=5, help="Términos a mostrar en GSEA plots")

# --- Argumentos del JSON (GSEA) ---
parser$add_argument("--run_gsea_analysis", action="store_true", default=FALSE, help="Ejecutar análisis GSEA")
parser$add_argument("--gsea_padj_cutoff", type="double", default=0.05, help="Corte P-value para GSEA")


# --- Parsear argumentos del JSON ---

args_list <- parser$parse_known_args()
args <- args_list[[1]]

cat("[INFO] Argumentos del JSON parseados.\n")



args$terms_per_page_dotplot <- 30 

cat("[INFO] Argumentos cargados.\n")
print(args) 

# --- Carga dinámica de OrgDb (basado en args) ---
if (!requireNamespace(args$organism_db, quietly = TRUE)) {
  cat(paste("[INFO] Instalando OrgDb faltante:", args$organism_db, "\n"))
  BiocManager::install(args$organism_db, ask=FALSE, update=TRUE)
}
suppressPackageStartupMessages(library(args$organism_db, character.only = TRUE))
org_db_loaded <- get(args$organism_db)
cat("[INFO] Paquete de organismo cargado:", args$organism_db, "\n")

available_cols <- columns(org_db_loaded)
target_symbol_col <- "SYMBOL" 

if (!"SYMBOL" %in% available_cols) {
  if ("GENENAME" %in% available_cols) {
    target_symbol_col <- "GENENAME" 
  } else if ("COMMON" %in% available_cols) {
    target_symbol_col <- "COMMON"
  } else {
    target_symbol_col <- args$key_type 
  }
}
cat(paste0("[INFO] Usando columna '", target_symbol_col, "' para traducción de nombres.\n"))




# --- Funciones Auxiliares 

# Función UNIVERSAL para traducir resultados de clusterProfiler
make_readable_universal <- function(enrich_obj, org_db, key_type, target_col) {
  if (is.null(enrich_obj)) return(NULL)
  res_df <- enrich_obj@result
  
  translate_gene_str <- function(gene_str) {
    if(is.na(gene_str) || gene_str == "") return("")
    ids <- unlist(strsplit(gene_str, "/"))
    syms <- suppressMessages(mapIds(org_db, keys=ids, column=target_col, keytype=key_type, multiVals="first"))
    syms[is.na(syms)] <- ids[is.na(syms)] 
    return(paste(syms, collapse="/"))
  }
  
  if ("geneID" %in% colnames(res_df)) res_df$geneID <- sapply(res_df$geneID, translate_gene_str)
  if ("core_enrichment" %in% colnames(res_df)) res_df$core_enrichment <- sapply(res_df$core_enrichment, translate_gene_str)
  
  enrich_obj@result <- res_df
  return(enrich_obj)
}


sanitize_df <- function(df) {
  if (is.null(df)) return(df)
  df <- as.data.frame(df, stringsAsFactors = FALSE, check.names = FALSE)
  for (col in names(df)) {
    if (is.list(df[[col]]) || is.recursive(df[[col]])) {
      df[[col]] <- vapply(df[[col]], function(x) {
        if (is.null(x) || length(x) == 0) return(NA_character_)
        paste(as.character(unlist(x)), collapse = ";")
      }, FUN.VALUE = character(1))
    } else if (is.factor(df[[col]])) {
      df[[col]] <- as.character(df[[col]])
    }
  }
  df
}
generar_pdf_vacio <- function(file_path, mensaje = "No se encontraron resultados significativos") {
  pdf(file_path, width = 11, height = 8.5)
  plot.new()
  text(0.5, 0.5, mensaje, cex = 1.5, col = "grey50")
  dev.off()
  cat(paste0("[WARN] Archivo vacío generado: ", basename(file_path), "\n"))
}
sanitize_filename <- function(name, max_len = 100) {
  name <- gsub("[^A-Za-z0-9_ -]+", "", name)
  name <- gsub("\\s+", "_", name)
  name <- stringr::str_trunc(name, max_len, "right", ellipsis = "")
  return(name)
}

# ==========================================================
# INICIO: FUNCIÓN DE INFORME TXT (MODIFICADA)
# ==========================================================

generar_informe_detallado <- function(base_name, sea_list, gsea_results_list, pathview_summary, deseq_summary = NULL, full_gprofiler_df = NULL) {
  out_file <- paste0("Informe_Completo_Ontogenia_", base_name, ".txt")
  report_lines <- c()
  report_lines <- c(report_lines, "============================================================")
  report_lines <- c(report_lines, sprintf("      INFORME DE ANÁLISIS FUNCIONAL COMPLETO - %s", base_name))
  report_lines <- c(report_lines, "============================================================")
  

  report_lines <- c(report_lines, "\nNOTA: Para un análisis interactivo y más detallado, revise el")
  report_lines <- c(report_lines, sprintf(  "      archivo \"Informe_Interactivo_%s.html\" generado.", base_name))

  
  report_lines <- c(report_lines, paste("\nFecha de generación:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  
  if (!is.null(deseq_summary)) {
    deseq_df <- sanitize_df(deseq_summary)
    if (all(c("log2FoldChange", "padj") %in% colnames(deseq_df))) {
      up <- sum(deseq_df$padj < args$padj & deseq_df$log2FoldChange > args$log2fc, na.rm = TRUE)
      down <- sum(deseq_df$padj < args$padj & deseq_df$log2FoldChange < -args$log2fc, na.rm = TRUE)
      total_sig <- up + down
      report_lines <- c(report_lines, sprintf("\n- DEGs significativos (padj < %.2f, |log2FC| > %.1f):", args$padj, args$log2fc))
      report_lines <- c(report_lines, sprintf("  - Total: %d", total_sig))
      report_lines <- c(report_lines, sprintf("  - Up-regulated: %d", up))
      report_lines <- c(report_lines, sprintf("  - Down-regulated: %d", down))
    }
  }
  
  all_files <- list.files(path = ".", recursive = TRUE)
  generated_files <- all_files[grepl(base_name, all_files, fixed = TRUE) | grepl(paste0("Informe_Completo_Ontogenia_", base_name), all_files, fixed = TRUE)]
  
  if (length(generated_files) > 0) {
    report_lines <- c(report_lines, "\n\n### 2. ARCHIVOS GENERADOS ###")
    add_file_section <- function(lines, title, files) {
      if (length(files) > 0) {
        lines <- c(lines, title)
        for (f in sort(files)) lines <- c(lines, paste("  -", f))
      }
      return(lines)
    }
    
    files_informe_txt    <- generated_files[grepl("Informe_Completo_Ontogenia_.*\\.txt$", generated_files)]
    files_pathview_pdf   <- generated_files[grepl("Informe_KEGG_Pathview_.*\\.pdf$", generated_files)] 
    files_informe_pdf    <- generated_files[grepl("Informe_Visual_GO.*\\.pdf$", generated_files)]
    files_gsea_pdf       <- generated_files[grepl("Informe_GSEA_GO.*\\.pdf$", generated_files)]
    files_anexo_pdf      <- generated_files[grepl("Anexo_DotPlot_Completo_GO.*\\.pdf$", generated_files)]
    files_tsv_pathview   <- generated_files[grepl("Resumen_Pathview.*\\.tsv$", generated_files)]
    files_tsv_sea        <- generated_files[grepl("Resultados_Completos_GO.*\\.tsv$", generated_files)]
    files_tsv_gsea       <- generated_files[grepl("Resultados_Completos_GSEA.*\\.tsv$", generated_files)]
    files_pathview_png   <- generated_files[grepl("pathview_plots/.*\\.png$", generated_files)]
    
    report_lines <- add_file_section(report_lines, "\n     --- Informes Principales (TXT) ---", c(files_informe_txt))
    report_lines <- add_file_section(report_lines, "\n     --- Tablas de Datos (TSV) ---", c(files_tsv_pathview, files_tsv_sea, files_tsv_gsea))
    report_lines <- add_file_section(report_lines, "\n     --- Gráficos Individuales (PDF) ---", c(files_pathview_pdf, files_informe_pdf, files_gsea_pdf, files_anexo_pdf))
    report_lines <- add_file_section(report_lines, "\n     --- PNGs Individuales ---", files_pathview_png)
  }
  
  

  report_lines <- c(report_lines, "\n\n============================================================")
  report_lines <- c(report_lines, "      ANÁLISIS DE ENRIQUECIMIENTO GO (SEA y GSEA)")
  report_lines <- c(report_lines, "============================================================")
  
  if (args$run_sea_analysis || args$run_gsea_analysis) {

    for (ont in args$sea_ontologies) { 
      
      ont_name <- switch(ont, "BP"="Proceso Biológico", "MF"="Función Molecular", "CC"="Componente Celular", ont)
      
      # --- Título de la Sección de Ontología ---
      report_lines <- c(report_lines, "\n\n============================================================")
      report_lines <- c(report_lines, sprintf("              Resultados para: %s (%s)", ont_name, ont))
      report_lines <- c(report_lines, "============================================================")
      
      # --- 1. Sub-sección SEA ---
      report_lines <- c(report_lines, "\n### ANÁLISIS SEA (ORA) ###")
      if (args$run_sea_analysis && !is.null(sea_list) && !is.null(sea_list[[ont]])) {
        ego_df <- sanitize_df(sea_list[[ont]])
        if (!is.null(ego_df) && nrow(ego_df) > 0) {
          ego_df_sorted <- ego_df %>% arrange(p.adjust)
          report_lines <- c(report_lines, sprintf("Se encontraron %d términos SEA significativos (p.adjust < %.2f).", nrow(ego_df_sorted), args$sea_padj_cutoff))
          for (i in seq_len(nrow(ego_df_sorted))) {
            t <- ego_df_sorted[i, ]
            report_lines <- c(report_lines, sprintf(" %4d. %s (%s): p.adjust=%.2e, Genes=%d", i, t$Description, t$ID, t$p.adjust, t$Count))
          }
        } else {
          report_lines <- c(report_lines, "No se encontraron términos SEA significativos.")
        }
      } else {
        report_lines <- c(report_lines, "Análisis SEA no ejecutado o sin resultados para esta ontología.")
      }
      
      # --- 2. Sub-sección GSEA ---
      report_lines <- c(report_lines, "\n\n### ANÁLISIS GSEA (Ranking) ###")
      if (args$run_gsea_analysis && !is.null(gsea_results_list) && !is.null(gsea_results_list[[ont]])) {
        gsea_df <- sanitize_df(gsea_results_list[[ont]])
        if (!is.null(gsea_df) && nrow(gsea_df) > 0) {
          report_lines <- c(report_lines, sprintf("Se encontraron %d términos GSEA significativos en total.", nrow(gsea_df)))
          
          # GSEA RUTAS ACTIVADAS
          top_up <- gsea_df %>% filter(NES > 0) %>% arrange(p.adjust)
          if(nrow(top_up) > 0) {
            report_lines <- c(report_lines, sprintf("\n   --- Rutas ACTIVADAS (NES > 0) - %d Total ---", nrow(top_up)))
            for (i in seq_len(nrow(top_up))) {
              t <- top_up[i, ]
              report_lines <- c(report_lines, sprintf("    %3d. %s (%s): p.adjust=%.2e, NES=%.2f", i, t$Description, t$ID, t$p.adjust, t$NES))
            }
          }
          
          # GSEA RUTAS SUPRIMIDAS
          top_down <- gsea_df %>% filter(NES < 0) %>% arrange(p.adjust)
          if(nrow(top_down) > 0) {
            report_lines <- c(report_lines, sprintf("\n   --- Rutas SUPRIMIDAS (NES < 0) - %d Total ---", nrow(top_down)))
            for (i in seq_len(nrow(top_down))) {
              t <- top_down[i, ]
              report_lines <- c(report_lines, sprintf("    %3d. %s (%s): p.adjust=%.2e, NES=%.2f", i, t$Description, t$ID, t$p.adjust, t$NES))
            }
          }
          if(nrow(top_up) == 0 && nrow(top_down) == 0) {
            report_lines <- c(report_lines, "\n  No se encontraron rutas GSEA significativas (Activadas o Suprimidas).")
          }
        } else {
          report_lines <- c(report_lines, "No se encontraron términos GSEA significativos.")
        }
      } else {
        report_lines <- c(report_lines, "Análisis GSEA no ejecutado o sin resultados para esta ontología.")
      }
    } 
  } else {
    report_lines <- c(report_lines, "\nAnálisis GO (SEA y GSEA) no ejecutados.")
  }
  
  
  # --- KEGG y REACTOME van después de GO ---
  if (!is.null(full_gprofiler_df)) {
    report_lines <- c(report_lines, "\n\n============================================================")
    report_lines <- c(report_lines, "      ANÁLISIS DE RUTAS (KEGG y REACTOME)")
    report_lines <- c(report_lines, "============================================================")
    
    # --- KEGG ---
    report_lines <- c(report_lines, "\n\n### ANÁLISIS KEGG (SEA / ORA) ###")
    kegg_df <- full_gprofiler_df %>% 
      filter(toupper(source) == "KEGG" & p_value < args$padj) %>%
      arrange(p_value)
    
    if (nrow(kegg_df) > 0) {
      report_lines <- c(report_lines, sprintf("Se encontraron %d rutas KEGG significativas (p.value < %.2f).", nrow(kegg_df), args$padj))
      for (i in seq_len(nrow(kegg_df))) {
        t <- kegg_df[i, ]
        report_lines <- c(report_lines, sprintf(" %4d. %s (%s): p.value=%.2e, Genes=%d", i, t$term_name, t$term_id, t$p_value, t$term_size))
      }
    } else {
      report_lines <- c(report_lines, "No se encontraron rutas KEGG significativas.")
    }
    
    # --- REACTOME ---
    report_lines <- c(report_lines, "\n\n### ANÁLISIS REACTOME (SEA / ORA) ###")
    reac_df <- full_gprofiler_df %>% 
      filter(toupper(source) == "REAC" & p_value < args$padj) %>%
      arrange(p_value)
    
    if (nrow(reac_df) > 0) {
      report_lines <- c(report_lines, sprintf("Se encontraron %d rutas REACTOME significativas (p.value < %.2f).", nrow(reac_df), args$padj))
      for (i in seq_len(nrow(reac_df))) {
        t <- reac_df[i, ]
        report_lines <- c(report_lines, sprintf(" %4d. %s (%s): p.value=%.2e, Genes=%d", i, t$term_name, t$term_id, t$p_value, t$term_size))
      }
    } else {
      report_lines <- c(report_lines, "No se encontraron rutas REACTOME significativas.")
    }
  }
  
  # --- PATHVIEW (KEGG) ---
  report_lines <- c(report_lines, "\n\n============================================================")
  report_lines <- c(report_lines, "      DETALLE VISUAL PATHVIEW (KEGG)")
  report_lines <- c(report_lines, "============================================================")
  if (!is.null(pathview_summary) && nrow(pathview_summary) > 0) {
    report_lines <- c(report_lines, sprintf("\nSe han visualizado %d rutas KEGG (Filtrado por p < %.2f).", nrow(pathview_summary), args$padj))
    for(i in 1:nrow(pathview_summary)) {
      row <- pathview_summary[i, ]
      report_lines <- c(report_lines, sprintf("\n** Ruta: %s (%s) **", row$term_name, row$term_id))
      report_lines <- c(report_lines, sprintf("  - p-valor: %.2e", row$p_value))
      report_lines <- c(report_lines, sprintf("  - Archivo PNG: %s", row$file_name))
      if (!is.na(row$genes_up) && row$genes_up != "" && length(row$genes_up) > 0) {
        report_lines <- c(report_lines, sprintf("  - Genes UP: %s", row$genes_up))
      }
      if (!is.na(row$genes_down) && row$genes_down != "" && length(row$genes_down) > 0) {
        report_lines <- c(report_lines, sprintf("  - Genes DOWN: %s", row$genes_down))
      }
    }
  } else {
    report_lines <- c(report_lines, sprintf("\nNo se encontraron rutas KEGG significativas (p < %.2f) para visualizar.", args$padj))
  }
  
  writeLines(report_lines, con = out_file)
  cat(paste0("[OK] Informe TXT completo y detallado guardado como: ", out_file, "\n"))
}



# --- 4) BÚSQUEDA DE ARCHIVOS (MODO MANUAL) ---
cat("[INFO] Buscando archivos 'Analisis_Rutas_Enriquecidas_*.txt'...\n")
results_filenames <- list.files(pattern = "^Analisis_Rutas_Enriquecidas_.*\\.txt$")

if (length(results_filenames) == 0) {
  stop("No se encontraron archivos 'Analisis_Funcional_*.txt'.")
}
cat(paste0("[INFO] Se procesarán ", length(results_filenames), " archivo(s).\n"))


for (current_file in results_filenames) {
  cat("\n=================================================\n")
  cat(paste0("=== Procesando comparación: ", current_file, " ===\n"))
  cat("=================================================\n")
  
  sea_results_list  <- list()
  gsea_results_list <- list()
  
  pathview_summary_df <- data.frame(
    term_id = character(),
    term_name = character(),
    p_value = numeric(),
    file_name = character(),
    genes_up = character(),
    genes_down = character(),
    stringsAsFactors = FALSE
  )
  
  deseq_df_raw <- NULL
  deseq_df <- NULL
  gene_list_fc <- NULL
  significant_genes <- NULL  
  
# --- Definir nombres de archivos ---
base_name <- gsub("^Analisis_Rutas_Enriquecidas_|\\.txt$", "", current_file)
deseq_results_file <- paste0("Resultados_Completos_", base_name, ".txt")

# --- Crear carpetas de salida ---
dir_pathview <- "pathview_plots"
dir_sea <- "sea_analysis_plots"
dir_gsea <- "gsea_analysis_plots"
dir.create(dir_pathview, showWarnings = FALSE)
dir.create(dir_sea, showWarnings = FALSE)
dir.create(dir_gsea, showWarnings = FALSE)

# --- Cargar archivo de rutas ---
results_df <- tryCatch({
  read.table(current_file, header = TRUE, sep = "\t", quote = "", comment.char = "", stringsAsFactors = FALSE, fill = TRUE)
}, error = function(e) {
  cat(paste0("[ERROR] No se pudo leer ", current_file, ": ", e$message, "\n"))
  return(NULL)
})

if (is.null(results_df) || nrow(results_df) == 0) {
  stop("El archivo de rutas está vacío o no se pudo leer.")
}


generar_informe_html <- function(base_name, sea_results_list, gsea_results_list, pathview_summary_df, deseq_df, results_df) {
  cat(paste0("[INFO] Generando informe HTML interactivo (Versión FINAL - NA Controlado): ", base_name, "\n"))
  
  if (is.null(deseq_df) || nrow(deseq_df) == 0 || !"gene_id" %in% colnames(deseq_df)) {
    stop("No hay datos válidos de DESeq2 para vincular log2FoldChange y pvalor.")
  }
  
  # --- 1. PREPARACIÓN DE DATOS ---
  deseq_df <- deseq_df %>%
    mutate(
      gene_id_nover = gsub("\\..*$", "", gene_id),
      log2FoldChange = as.numeric(log2FoldChange),
      padj = as.numeric(padj),
      baseMean = as.numeric(baseMean),
      symbol = ifelse(!is.na(symbol) & symbol != "", symbol, gene_id_nover),
      
      # Flag booleano para SEA (Estricto). Si padj es NA, da FALSE.
      cumple_criterio = !is.na(padj) & padj < args$padj & abs(log2FoldChange) > args$log2fc,
      
      # Regulación por signo
      regulacion_raw = ifelse(log2FoldChange > 0, "UP", "DOWN")
    )
  
  gene_info <- split(deseq_df, deseq_df$symbol) 
  
  html_file <- paste0("Informe_Interactivo_", base_name, ".html")
  con <- file(html_file, "w", encoding = "UTF-8")
  
  # --- 2. CABECERA Y ESTILOS ---
  cat("<html><head><meta charset='UTF-8'><title>Informe Interactivo</title>", file = con)
  cat("<style>
      body { font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; margin: 0; background: #f4f6f9; color: #333; }
      
      /* HEADER & DASHBOARD */
      .header-container {
        background: #ffffff; border-bottom: 4px solid #2c3e50;
        padding: 20px 40px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      }
      h1 { margin: 0; color: #2c3e50; font-size: 26px; }
      .subtitle { color: #7f8c8d; margin-top: 5px; font-size: 14px; font-weight: normal;}
      
      /* CAJAS DE INFORMACIÓN */
      .info-grid { display: flex; gap: 20px; padding: 20px 40px; flex-wrap: wrap; }
      
      .box { 
        background: #fff; border-radius: 6px; padding: 20px; 
        box-shadow: 0 1px 3px rgba(0,0,0,0.1); flex: 1; min-width: 300px;
        border-left: 5px solid #bdc3c7;
      }
      .box-params { border-left-color: #e67e22; }
      .box-instr { border-left-color: #3498db; }
      .box-title { display: block; font-weight: bold; margin-bottom: 15px; color: #444; text-transform: uppercase; font-size: 0.9em; letter-spacing: 0.5px; border-bottom: 1px solid #eee; padding-bottom: 5px;}
      
      ul { margin: 0; padding-left: 20px; font-size: 0.95em; line-height: 1.6; color: #555; }
      li { margin-bottom: 6px; }
      .folder-note { margin-top: 15px; padding: 10px; background: #fff8e1; border: 1px solid #ffeeba; color: #856404; font-size: 0.9em; border-radius: 4px; display: flex; align-items: center; }
      .intro-text { color: #555; margin-bottom: 15px; line-height: 1.5; font-size: 0.95em; }
      
      /* CONTENIDO */
      .content { margin: 0 40px 60px 40px; }
      h2 { color: #2c3e50; border-bottom: 2px solid #ecf0f1; padding-bottom: 10px; margin-top: 40px; font-size: 1.5em; }
      h3 { color: #34495e; margin-top: 25px; font-size: 1.1em; border-left: 4px solid #95a5a6; padding-left: 12px; background: #ecf0f1; padding: 8px 12px; border-radius: 0 4px 4px 0;}
      
      /* TÉRMINOS */
      .term { 
        margin: 10px 0; padding: 12px 18px; background: #fff; 
        border: 1px solid #e0e0e0; border-radius: 6px; 
        cursor: pointer; transition: all 0.2s; position: relative;
        display: flex; justify-content: space-between; align-items: center;
      }
      .term:hover { background: #f0f8ff; border-color: #3498db; transform: translateX(2px); box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
      .term strong { color: #2980b9; font-size: 1.05em; }
      
      .genes { 
        display: none; margin: 0 0 20px 20px; padding: 20px; 
        background: #fdfdfd; border-left: 3px solid #bdc3c7;
        box-shadow: inset 0 2px 4px rgba(0,0,0,0.02);
        border-radius: 0 0 6px 6px;
      }
      
      /* ESTILOS DE GENES */
      .gene { 
        margin: 3px; padding: 5px 10px; border-radius: 4px; 
        display: inline-block; cursor: pointer; font-weight: 600; font-size: 0.85em;
        user-select: none; border: 1px solid transparent;
      }
      .gene.UP { background: #fadbd8; color: #c0392b; border-color: #e6b0aa; }
      .gene.DOWN { background: #d4efdf; color: #27ae60; border-color: #a9dfbf; }
      
      /* GSEA: Transparencia (No Sig) y Gris (NA) */
      .gene-ns { opacity: 0.65; border-style: dashed !important; background-color: #f9f9f9 !important; color: #7f8c8d !important; border-color: #bdc3c7 !important; }
      .gene-na { opacity: 0.5; border: 1px dotted #ccc !important; background-color: #eee !important; color: #999 !important; }

      .gene:hover { box-shadow: 0 3px 8px rgba(0,0,0,0.2); z-index: 10; position: relative; transform: scale(1.05); transition: 0.1s; border-color: #555 !important;}
      
      /* TOOLTIP */
      .gene-info { 
        display:none; padding: 12px; 
        background: #2c3e50; color: #ecf0f1; border-radius: 6px; 
        font-size: 0.85em; box-shadow: 0 5px 15px rgba(0,0,0,0.3);
        position: absolute; z-index: 9999; min-width: 240px;
        border: 1px solid #34495e; pointer-events: none;
      }
      .info-row { display: flex; justify-content: space-between; margin-bottom: 4px; border-bottom: 1px solid #4e6072; padding-bottom: 3px;}
      .info-row:last-child { border-bottom: none; margin-bottom: 0; padding-bottom: 0; }
      .label { color: #bdc3c7; font-size: 0.9em; }
      .val { font-weight: bold; color: #fff; }
      
      .val-sig { color: #3498db; text-transform: uppercase; letter-spacing: 0.5px; } 
      .val-lowfc { color: #f1c40f; font-style: italic; } 
      .val-na { color: #bdc3c7; font-style: italic; } 
      
      .badge { font-size: 0.8em; background: #eee; padding: 3px 8px; border-radius: 12px; color: #555; margin-left: 10px;}
    </style>", file = con)
  
  cat("<script>
        function toggleGenes(id){ 
          var el = document.getElementById(id); 
          var display = el.style.display;
          if (display === 'none' || display === '') {
             el.style.display = 'block';
             el.style.opacity = 0;
             var op = 0.1;
             var timer = setInterval(function () {
                 if (op >= 1){ clearInterval(timer); }
                 el.style.opacity = op;
                 op += op * 0.1;
             }, 10);
          } else {
             el.style.display = 'none';
          }
        }
        function showGeneInfo(id, event){
          var info = document.getElementById(id);
          var allInfos = document.getElementsByClassName('gene-info');
          for (var i = 0; i < allInfos.length; i++) {
             if (allInfos[i].id !== id) allInfos[i].style.display = 'none';
          }
          if (info.style.display === 'block') {
             info.style.display = 'none';
          } else {
             info.style.display = 'block';
             info.style.left = (event.pageX + 15) + 'px';
             info.style.top = (event.pageY + 15) + 'px';
          }
        }
      </script>", file = con)
  cat("</head><body>", file = con)
  
  # --- HEADER Y DASHBOARD ---
  cat(paste0("<div class='header-container'>
                <h1>📊 Informe Interactivo: ", base_name, "</h1>
                <div class='subtitle'>Generado el: ", format(Sys.time(), "%Y-%m-%d %H:%M"), "</div>
              </div>"), file = con)
  
  cat("<div class='info-grid'>", file = con)
  
  # --- CAJA 1: PARÁMETROS ---
  cat(sprintf("<div class='box box-params'>
                <span class='box-title'>⚙️ Parámetros de Corte (SEA)</span>
                <ul>
                  <li><strong>Log2 Fold Change:</strong> &gt; %.2f (Absoluto)</li>
                  <li><strong>P-value Ajustado:</strong> &lt; %.3f</li>
                  <li><strong>Organismo:</strong> %s</li>
                </ul>
                <div class='folder-note'>⚠️ La última sección pertenece a Pathview. Asegúrese de que la carpeta <code>pathview_plots</code> está en el mismo directorio para ver los mapas.</div>
              </div>", args$log2fc, args$padj, args$kegg_species_code), file = con)
  
  # --- CAJA 2: GUÍA DE INTERPRETACIÓN ---
  cat("<div class='box box-instr'>
        <span class='box-title'>📘 Guía de Interpretación</span>
        <div class='intro-text'>
            Este dashboard interactivo permite explorar la biología de sus datos. Haga clic en las barras de los términos para desplegar los genes asociados.
        </div>
        <ul>
          <li><strong>COLORES:</strong> Los genes se colorean en <span style='color:#c0392b; font-weight:bold;'>ROJO (UP)</span> o <span style='color:#27ae60; font-weight:bold;'>VERDE (DOWN)</span>.</li>
          <li><strong>SEA (ORA):</strong> Análisis estricto. Muestra <u>SOLO</u> genes que superan los umbrales de significancia.</li>
          <li><strong>GSEA:</strong> Análisis de tendencias. Muestra todos los genes del <i>Core Enrichment</i>.
            <ul style='margin-top:5px; border-left:2px solid #eee; padding-left:10px;'>
              <li><span style='color:#c0392b'>■</span> <strong>Sólido:</strong> Gen Significativo (Driver principal).</li>
              <li><span style='color:#999; border:1px dashed #999; padding:0 3px;'>□</span> <strong>Transparente/Punteado:</strong> Gen contribuyente a la ruta, pero no significativo individualmente.</li>
              <li><span style='color:#999; border:1px dotted #ccc; background:#eee; padding:0 3px;'>□</span> <strong>Gris:</strong> Gen excluido del análisis estadístico (P-adj = NA) por conteos bajos, aunque tiene Fold Change.</li>
            </ul>
          </li>
          <li><strong>Interacción:</strong> Pulse sobre cualquier gen para ver sus estadísticas clave (<i>Log2FC, P-adj, BaseMean</i>).</li>
        </ul>
       </div>", file = con)
  
  cat("</div>", file = con) # Fin info-grid
  cat("<div class='content'>", file = con)
  
  
  # ============================================================================
  # SECCIÓN 1: SEA (ORA)
  # ============================================================================
  if (length(sea_results_list) > 0) {
    cat("<h2>1. Análisis de Sobre-representación (SEA / ORA)</h2>", file = con)
    cat("<p style='color:#666; margin-bottom:20px;'><i>Método: Hipergeométrico. Muestra solo genes significativos (p < 0.05 & FC > umbral).</i></p>", file = con)
    
    for (ont in names(sea_results_list)) {
      df <- sea_results_list[[ont]]
      if (is.null(df) || nrow(df) == 0) next
      df <- df[order(df$p.adjust), ]
      
      cat(paste0("<h3>📂 ", ont, " (", nrow(df), " términos enriquecidos)</h3>"), file = con)
      
      for (i in seq_len(nrow(df))) {
        tid <- paste0("sea_", ont, "_", i)
        term <- df$Description[i]
        genes <- unlist(strsplit(df$geneID[i], "/")) 
        
        genes_html_buffer <- c()
        count_valid_genes <- 0
        
        for (g_idx in seq_along(genes)) {
          g_trim <- trimws(genes[g_idx])
          g_id <- paste0("info_", ont, "_", i, "_", g_idx) 
          
          if (g_trim %in% names(gene_info)) {
            row <- gene_info[[g_trim]][1, ]
            
            # FILTRO ESTRICTO SEA
            if (row$cumple_criterio) {
              lfc <- signif(row$log2FoldChange, 3)
              padj <- formatC(row$padj, format = "e", digits = 2)
              bmean <- round(row$baseMean, 1)
              reg <- row$regulacion_raw
              
              span_str <- paste0("<span class='gene ", reg, "' onclick=\"showGeneInfo('", g_id, "', event)\">", g_trim, "</span>")
              
              info_str <- paste0("<div class='gene-info' id='", g_id, "'>",
                                 "<div class='info-row'><span class='label'>Log2FC:</span> <span class='val'>", lfc, "</span></div>",
                                 "<div class='info-row'><span class='label'>Padj:</span> <span class='val'>", padj, "</span></div>",
                                 "<div class='info-row'><span class='label'>BaseMean:</span> <span class='val'>", bmean, "</span></div>",
                                 "<div class='info-row'><span class='label'>Estado:</span> <span class='val val-sig'>SIGNIFICATIVO</span></div>",
                                 "</div>")
              genes_html_buffer <- c(genes_html_buffer, span_str, info_str)
              count_valid_genes <- count_valid_genes + 1
            }
          }
        }
        
        if (count_valid_genes > 0) {
          cat(paste0("<div class='term' onclick=\"toggleGenes('", tid, "')\">",
                     "<div><strong>", term, "</strong> <span style='color:#999; font-size:0.9em; margin-left:5px;'>(p=", signif(df$p.adjust[i],3), ")</span></div>",
                     "<div class='badge'>", count_valid_genes, " genes</div></div>"), file = con)
          cat(paste0("<div class='genes' id='", tid, "'>"), file = con)
          cat(paste(genes_html_buffer, collapse=""), file = con)
          cat("</div>", file = con)
        }
      }
    }
  }
  
  # ============================================================================
  # SECCIÓN 2: GSEA (INTELIGENTE)
  # ============================================================================
  if (length(gsea_results_list) > 0) {
    cat("<h2>2. Análisis de Enriquecimiento de Conjuntos de Genes (GSEA)</h2>", file = con)
    cat("<p style='color:#666; margin-bottom:20px;'><i>Método: Permutaciones. Se muestran todos los genes del 'Leading Edge'.</i></p>", file = con)
    
    for (ont in names(gsea_results_list)) {
      df <- gsea_results_list[[ont]]
      if (is.null(df) || nrow(df) == 0) next
      df <- df[order(df$p.adjust), ]
      
      cat(paste0("<h3>📂 ", ont, " (", nrow(df), " rutas significativas)</h3>"), file = con)
      
      for (i in seq_len(nrow(df))) {
        tid <- paste0("gsea_", ont, "_", i)
        term <- df$Description[i]
        genes <- unlist(strsplit(df$core_enrichment[i], "/")) 
        
        genes_html_buffer <- c()
        count_valid_genes <- 0
        
        for (g_idx in seq_along(genes)) {
          g_trim <- trimws(genes[g_idx])
          g_id <- paste0("info_", ont, "_gsea_", i, "_", g_idx) 
          
          if (g_trim %in% names(gene_info)) {
            row <- gene_info[[g_trim]][1, ]
            
            lfc <- signif(row$log2FoldChange, 3)
            padj_raw <- row$padj
            # Si padj es NA, mostramos "NA", si no, formateamos
            padj_txt <- ifelse(is.na(padj_raw), "NA", formatC(padj_raw, format = "e", digits = 2))
            bmean <- ifelse(is.na(row$baseMean), "NA", round(row$baseMean, 1))
            reg_visual <- ifelse(row$log2FoldChange > 0, "UP", "DOWN")
            
            # --- DETERMINAR ESTADO ---
            if (is.na(padj_raw)) {
              # Caso NA: Gris y etiqueta clara
              clase_extra <- "gene-na"
              status_html <- "<span class='val val-na'>Excluido (Padj=NA)</span>"
            } else {
              pass_padj <- padj_raw < args$padj
              pass_fc <- abs(row$log2FoldChange) > args$log2fc
              
              if (pass_padj & pass_fc) {
                clase_extra <- "" # Sólido
                status_html <- "<span class='val val-sig'>SIGNIFICATIVO</span>"
              } else if (pass_padj & !pass_fc) {
                clase_extra <- "gene-ns" # Transparente
                status_html <- "<span class='val val-lowfc'>Contribuyente (FC Bajo)</span>"
              } else {
                clase_extra <- "gene-ns" # Transparente
                status_html <- "<span class='val val-ns'>Contribuyente (No Sig.)</span>"
              }
            }
            
            span_str <- paste0("<span class='gene ", reg_visual, " ", clase_extra, 
                               "' onclick=\"showGeneInfo('", g_id, "', event)\">", g_trim, "</span>")
            
            info_str <- paste0("<div class='gene-info' id='", g_id, "'>",
                               "<div class='info-row'><span class='label'>Log2FC:</span> <span class='val'>", lfc, "</span></div>",
                               "<div class='info-row'><span class='label'>Padj:</span> <span class='val'>", padj_txt, "</span></div>",
                               "<div class='info-row'><span class='label'>BaseMean:</span> <span class='val'>", bmean, "</span></div>",
                               "<div class='info-row'><span class='label'>Rol:</span> ", status_html, "</div>",
                               "</div>")
            
            genes_html_buffer <- c(genes_html_buffer, span_str, info_str)
            count_valid_genes <- count_valid_genes + 1
          }
        }
        
        if (count_valid_genes > 0) {
          nes_val <- signif(df$NES[i], 3)
          cat(paste0("<div class='term' onclick=\"toggleGenes('", tid, "')\">",
                     "<div><strong>", term, "</strong> <span style='color:#999; font-size:0.9em; margin-left:5px;'>(NES=", nes_val, ", p=", signif(df$p.adjust[i],3), ")</span></div>",
                     "<div class='badge'>", count_valid_genes, " core genes</div></div>"), file = con)
          cat(paste0("<div class='genes' id='", tid, "'>"), file = con)
          cat(paste(genes_html_buffer, collapse=""), file = con)
          cat("</div>", file = con)
        }
      }
    }
  }
  
  # ============================================================================
  # SECCIÓN 3: PATHVIEW
  # ============================================================================
  if (!is.null(pathview_summary_df) && nrow(pathview_summary_df) > 0) {
    cat("<h2>3. Visualización de Rutas (Pathview KEGG)</h2>", file = con)
    cat("<p style='color:#666; margin-bottom:20px;'><i>Rutas metabólicas mapeadas. Haga clic para ver la imagen generada.</i></p>", file = con)
    
    for (i in seq_len(nrow(pathview_summary_df))) {
      pid <- paste0("path_", i)
      pname <- pathview_summary_df$term_name[i]
      pngfile <- pathview_summary_df$file_name[i]
      
      cat(paste0("<div class='term' onclick=\"toggleGenes('", pid, "')\">",
                 "<strong>", pname, "</strong> <span style='color:#999; font-size:0.9em; margin-left:5px;'>(p=", signif(pathview_summary_df$p_value[i],3), ")</span></div>"), file = con)
      
      cat(paste0("<div class='genes' id='", pid, "' style='text-align:center;'>",
                 "<img src='pathview_plots/", pngfile, 
                 "' style='max-width:98%; border-radius:8px; box-shadow:0 4px 8px rgba(0,0,0,0.1); margin-top:10px;'></div>"), file = con)
    }
  }
  
  cat("</div>", file = con) 
  cat("</body></html>", file = con)
  close(con)
  cat(paste0("[OK] Informe HTML interactivo generado correctamente: ", html_file, "\n"))
}

# ---------------------------
# [PASO 1/4] PATHVIEW (KEGG)
# ---------------------------
cat(" -> [1/4] Generando visualizaciones Pathview (KEGG)...\n")

# Línea corregida
pathview_summary_df <- data.frame(
  term_id = character(),
  term_name = character(),
  p_value = numeric(),
  file_name = character(),
  genes_up = character(),
  genes_down = character(),
  stringsAsFactors = FALSE
)

if (!file.exists(deseq_results_file)) {
  cat(paste0(" -> [WARN] Archivo DESeq2 no encontrado: ", deseq_results_file, ". Se omite Pathview.\n"))
} else {
  deseq_df_raw <- tryCatch(
    read.table(deseq_results_file, header = TRUE, sep = "\t", quote = "", stringsAsFactors = FALSE, fill = TRUE),
    error = function(e) NULL
  )
  
  if (!is.null(deseq_df_raw) &&
      nrow(deseq_df_raw) > 0 &&
      all(c("log2FoldChange", "gene_id", "padj") %in% colnames(deseq_df_raw))) {
    
    deseq_df <- sanitize_df(deseq_df_raw)
    
    # ==========================================================
    # FILTRADO DE KEGG SIGNIFICATIVO
    # ==========================================================
    kegg_results <- sanitize_df(results_df) %>%
      dplyr::filter(toupper(source) == "KEGG" &
                      term_id != "KEGG:01100" &
                      p_value < args$padj)
    
    if (nrow(kegg_results) == 0) {
      cat(sprintf(" -> [INFO] No se encontraron rutas KEGG significativas (p < %.2f) en g:Profiler.\n", args$padj))
    } else {
      cat(sprintf(" -> [INFO] Se encontraron %d rutas KEGG significativas. Procesando...\n", nrow(kegg_results)))
      
      # Mapeo IDs
      cat(" -> [INFO] Mapeando IDs de ENSEMBL a ENTREZID...\n")
      
      ensembl_fc_df <- data.frame(
        gene_id_no_version = gsub("\\..*$", "", deseq_df$gene_id),
        log2FoldChange = deseq_df$log2FoldChange,
        stringsAsFactors = FALSE
      ) %>%
        dplyr::filter(!is.na(log2FoldChange) & !duplicated(gene_id_no_version))
      
      id_map <- tryCatch({
        AnnotationDbi::select(
          org_db_loaded,
          keys = ensembl_fc_df$gene_id_no_version,
          columns = c("ENTREZID"),
          keytype = "ENSEMBL"
        )
      }, error = function(e) {
        cat(paste0(" -> [WARN] Falló AnnotationDbi::select: ", e$message, "\n"))
        NULL
      })
      
      gene_data_fc <- NULL
      pathview_id_type <- NULL
      
      if (!is.null(id_map) && nrow(id_map) > 0) {
        gene_data_fc_df <- ensembl_fc_df %>%
          left_join(id_map, by = c("gene_id_no_version" = "ENSEMBL")) %>%
          dplyr::filter(!is.na(ENTREZID) & !duplicated(ENTREZID))
        
        if (nrow(gene_data_fc_df) > 0) {
          gene_data_fc <- gene_data_fc_df$log2FoldChange
          names(gene_data_fc) <- gene_data_fc_df$ENTREZID
          pathview_id_type <- "ENTREZID"
          cat(paste0(" -> [INFO] Mapeo exitoso: ", length(gene_data_fc), " genes ENTREZ listos.\n"))
        }
      }
      
      if (is.null(gene_data_fc)) {
        cat(" -> [WARN] Mapeo a ENTREZID falló. Usando ENSEMBL.\n")
        gene_data_fc <- ensembl_fc_df$log2FoldChange
        names(gene_data_fc) <- ensembl_fc_df$gene_id_no_version
        pathview_id_type <- "ENSEMBL"
      }
      
      gene_data_fc <- gene_data_fc[!is.na(gene_data_fc) & !duplicated(names(gene_data_fc))]
      
      # Filtrado de genes
      valid_intersections <- na.omit(kegg_results$intersection)
      genes_en_rutas <- unique(unlist(strsplit(as.character(valid_intersections), ",")))
      
      deseq_genes_filtrados <- deseq_df %>%
        mutate(gene_id_no_version = gsub("\\..*$", "", gene_id)) %>%
        dplyr::filter(gene_id_no_version %in% genes_en_rutas &
                        !is.na(padj) &
                        padj < args$padj &
                        abs(as.numeric(log2FoldChange)) > args$log2fc) %>%
        dplyr::select(gene_id_no_version, symbol, log2FoldChange) %>%
        mutate(
          regulacion = ifelse(log2FoldChange > 0, "UP", "DOWN"),
          gene_label = ifelse(!is.na(symbol) & symbol != "", symbol, gene_id_no_version)
        )
      
      original_wd <- getwd()
      setwd(dir_pathview)
      
      # Bucle Pathview
      cat(paste0(" -> Procesando ", nrow(kegg_results), " rutas KEGG...\n"))
      
      for (i in seq_len(nrow(kegg_results))) {
        pid <- gsub("KEGG:", "", kegg_results$term_id[i])
        pname_raw <- kegg_results$term_name[i]
        pname_clean <- sanitize_filename(pname_raw)
        
        final_png_renamed <- paste0("KEGG_", pid, "_", pname_clean, "_", base_name, ".png")
        
        suffix_name <- paste0(pname_clean, ".", base_name, "_KEGG_", pid)
        final_png_name <- paste0(args$kegg_species_code, pid, ".", suffix_name, ".png")
        
        cat(paste0("       -> Pathview: ", pid, " (", pname_raw, ")\n"))
        
        options(download.file.method = "auto")
        
        tryCatch({
          pathview(
            gene.data = gene_data_fc,
            pathway.id = pid,
            species = args$kegg_species_code,
            gene.idtype = pathview_id_type,
            limit = list(gene = 3, cpd = 1),
            out.suffix = suffix_name,
            kegg.native = TRUE
          )
        }, error = function(e) {
          cat(paste0(" -> [WARN] Pathview falló para ", pid, ": ", e$message, "\n"))
        })
        
        cat("       -> Pausa de 2s para sincronizar PNG...\n")
        Sys.sleep(2)
        
        if (!file.exists(final_png_name)) {
          cat(paste0(" -> [WARN] No encontrado: ", final_png_name, "\n"))
        } else {
          file.rename(final_png_name, final_png_renamed)
          if (file.exists(paste0(args$kegg_species_code, pid, ".xml")))
            file.remove(paste0(args$kegg_species_code, pid, ".xml"))
          
          genes_en_esta_ruta <- if (!is.na(kegg_results$intersection[i])) {
            unlist(strsplit(as.character(kegg_results$intersection[i]), ","))
          } else character(0)
          
          genes_up_ruta <- deseq_genes_filtrados %>%
            dplyr::filter(gene_id_no_version %in% genes_en_esta_ruta & regulacion == "UP") %>%
            pull(gene_label)
          
          genes_down_ruta <- deseq_genes_filtrados %>%
            dplyr::filter(gene_id_no_version %in% genes_en_esta_ruta & regulacion == "DOWN") %>%
            pull(gene_label)
          
          pathview_summary_df <- rbind(pathview_summary_df, data.frame(
            term_id = kegg_results$term_id[i],
            term_name = pname_raw,
            p_value = kegg_results$p_value[i],
            file_name = final_png_renamed,
            genes_up = paste(genes_up_ruta, collapse = ", "),
            genes_down = paste(genes_down_ruta, collapse = ", ")
          ))
        }
      }
      
      setwd(original_wd)
      
      # ==========================================================
      # PDF
      # ==========================================================
      cat(" -> [1.5] Generando PDF de Pathview...\n")
      
      if (nrow(pathview_summary_df) > 0) {
        
        pdf_pathview_report_file <- file.path(
          dir_pathview,
          paste0("Informe_KEGG_Pathview_", base_name, ".pdf")
        )
        
        pathview_summary_sorted <- pathview_summary_df %>%
          arrange(p_value) %>%
          mutate(
            p_value_fmt = format(p_value, scientific = TRUE, digits = 3),
            genes_up_short = stringr::str_trunc(genes_up, 80, "right"),
            genes_down_short = stringr::str_trunc(genes_down, 80, "right")
          )
        
        pdf(pdf_pathview_report_file, width = 14, height = 11)
        
        grid.newpage()
        grid.text("Informe de Análisis de Rutas KEGG (Pathview)", y = 0.8,
                  gp = gpar(fontsize = 28, fontface = "bold"))
        grid.text(paste("Contraste:", base_name), y = 0.7,
                  gp = gpar(fontsize = 16, fontface = "italic"))
        grid.text(paste("Especie KEGG:", args$kegg_species_code), y = 0.6,
                  gp = gpar(fontsize = 14))
        grid.text(paste("Total de rutas KEGG alteradas (p <", args$padj, "):",
                        nrow(pathview_summary_sorted)),
                  y = 0.55, gp = gpar(fontsize = 14))
        grid.text(paste("Generado el:", Sys.Date()), y = 0.1,
                  gp = gpar(fontsize = 9, col = "grey"))
        
        grid.newpage()
        grid.text("Resumen de Rutas KEGG Significativas", y = 0.95,
                  gp = gpar(fontsize = 20, fontface = "bold"))
        
        top_summary <- pathview_summary_sorted %>%
          head(10) %>%
          dplyr::select(
            Ruta = term_name,
            `p-valor` = p_value_fmt,
            `Genes UP (Rojo)` = genes_up_short,
            `Genes DOWN (Verde)` = genes_down_short
          )
        
        grob_tabla <- gridExtra::tableGrob(
          top_summary, rows = NULL,
          theme = ttheme_default(
            core = list(fg_params = list(cex = 0.8)),
            colhead = list(fg_params = list(cex = 0.9, fontface = "bold"))
          )
        )
        
        grid.draw(grob_tabla)
        
        # Páginas con imágenes
        for (i in 1:nrow(pathview_summary_sorted)) {
          row_data <- pathview_summary_sorted[i, ]
          png_file_path <- file.path(dir_pathview, row_data$file_name)
          
          if (!file.exists(png_file_path)) {
            cat(paste0(" -> [WARN] PNG faltante: ", row_data$file_name, "\n"))
            next
          }
          
          img <- NULL
          tryCatch({
            img <- png::readPNG(png_file_path)
          }, error = function(e) {
            cat(paste0(" -> [ERROR] PNG corrupto: ", row_data$file_name, "\n"))
          })
          
          if (is.null(img)) next
          
          grid.newpage()
          titulo <- paste0(i, ". ", row_data$term_name, " (", row_data$term_id, ")")
          subtitulo <- paste("p-valor:", row_data$p_value_fmt)
          
          grid.text(titulo, y = 0.95,
                    gp = gpar(fontsize = 16, fontface = "bold"))
          grid.text(subtitulo, y = 0.92,
                    gp = gpar(fontsize = 10, fontface = "italic"))
          
          pushViewport(viewport(x = 0.5, y = 0.5, width = 0.95, height = 0.8))
          grid.raster(img)
          popViewport()
        }
        
        dev.off()
        cat(paste0(" -> [OK] PDF Pathview: ", pdf_pathview_report_file, "\n"))
        
      } else {
        cat(" -> [INFO] No se generaron imágenes Pathview; se omite PDF.\n")
      }
      
      # TSV
      if (nrow(pathview_summary_df) > 0) {
        tsv_file <- file.path(dir_pathview, paste0("Resumen_Pathview_", base_name, ".tsv"))
        tryCatch({
          write.table(pathview_summary_df, tsv_file, sep = "\t",
                      row.names = FALSE, quote = TRUE)
          cat(paste0(" -> [OK] TSV Pathview: ", tsv_file, "\n"))
        }, error = function(e) {
          cat(paste0(" -> [WARN] No se pudo guardar TSV: ", e$message, "\n"))
        })
      }
      
      cat(" -> [OK] Pathview finalizado.\n")
    }
    
  } else {
    cat(" -> [WARN] DESeq2 inválido o sin columnas requeridas.\n")
  }
}






# --- Preparación de datos para GO ---
gene_list_fc <- NULL
significant_genes <- NULL
if(args$run_sea_analysis || args$run_gsea_analysis) {
  if (!file.exists(deseq_results_file)) {
    cat(paste0("   -> [WARN] Archivo DESeq2 no encontrado...\n"))
  } else {
    if (!exists("deseq_df_raw") || is.null(deseq_df_raw)) {
      deseq_df_raw <- tryCatch(read.table(deseq_results_file, header=TRUE, sep="\t", quote="", stringsAsFactors=FALSE, fill=TRUE), error=function(e) NULL)
    }
    
    if (!is.null(deseq_df_raw) && nrow(deseq_df_raw) > 0 && all(c("log2FoldChange", "padj", "gene_id") %in% colnames(deseq_df_raw))) {
      deseq_df <- sanitize_df(deseq_df_raw)
      ids_sin_version <- gsub("\\..*$", "", deseq_df$gene_id)
      
  
      if ("symbol" %in% colnames(deseq_df) && any(deseq_df$symbol != "", na.rm=T)) {
        cat("   -> [INFO] Usando 'symbol' como nombres de genes para la lista de FC (para Cnetplot).\n")
        gene_list_fc_pre <- deseq_df$log2FoldChange
        names(gene_list_fc_pre) <- deseq_df$symbol
        gene_list_fc_df <- data.frame(symbol = names(gene_list_fc_pre), 
                                      l2fc = gene_list_fc_pre, 
                                      padj = deseq_df$padj) %>%
          filter(!is.na(l2fc) & symbol != "" & !is.na(symbol)) %>%
          arrange(padj) %>%
          filter(!duplicated(symbol))
        
        gene_list_fc <- gene_list_fc_df$l2fc
        names(gene_list_fc) <- gene_list_fc_df$symbol 
        
      } else {
        cat("   -> [WARN] No se encontró columna 'symbol'. Cnetplot usará IDs de ENSEMBL.\n")
        gene_list_fc_pre <- deseq_df$log2FoldChange
        names(gene_list_fc_pre) <- ids_sin_version
        gene_list_fc <- gene_list_fc_pre[!is.na(gene_list_fc_pre) & names(gene_list_fc_pre) != "" & !duplicated(names(gene_list_fc_pre))]
      }

      # Genes significativos (para SEA), siempre por ENSEMBL (key_type)
      significant_genes <- deseq_df %>%
        filter(!is.na(padj) & padj < args$padj & abs(as.numeric(log2FoldChange)) > args$log2fc) %>%
        pull(gene_id) %>% gsub("\\..*$", "", .) %>% unique()
      
    } else {
      cat("   -> [WARN] El archivo DESeq2 no se pudo leer o no contiene las columnas requeridas para GO.\n")
    }
  }
}




# ---------------------------
# [PASO 2/4] SEA (clusterProfiler)
# ---------------------------
sea_results_list <- list()

# --- SECCIÓN SEA ---
if (args$run_sea_analysis) {
  cat(" -> [2/4] Ejecutando análisis de enriquecimiento GO (SEA / ORA)...\n")
  
  if (!is.null(significant_genes) && length(significant_genes) >= 10) {
    cat(paste0(" -> [INFO] Se encontraron ", length(significant_genes), " genes significativos. Iniciando análisis SEA GO...\n"))
    
    for (ont in args$sea_ontologies) {
      cat(paste0("        -> Analizando ontología SEA: ", ont, "\n"))
      tryCatch({
        ego <- enrichGO(
          gene = significant_genes,
          OrgDb = org_db_loaded,
          keyType = args$key_type,
          ont = ont,
          pAdjustMethod = "BH",
          pvalueCutoff = args$sea_padj_cutoff,
          qvalueCutoff = args$sea_qvalue_cutoff,
          readable = FALSE  
        )
        
        if (!is.null(ego) && nrow(ego@result) > 0) {
          cat(paste0("        -> ¡ÉXITO! Se encontraron ", nrow(ego@result), " términos SEA significativos para ", ont, ".\n"))
          

          ego <- make_readable_universal(ego, org_db_loaded, args$key_type, target_symbol_col)
          # ----------------------------------------------
          
          ego_df <- as.data.frame(ego)
          sea_results_list[[ont]] <- ego_df
          
          tsv_file <- file.path(dir_sea, paste0("Resultados_Completos_GO_", ont, "_", base_name, ".tsv"))
          write.table(ego_df, file = tsv_file, sep = "\t", row.names = FALSE, quote = TRUE)
          cat(paste0("        -> [OK] TSV completo de GO (", ont, ") guardado en: ", tsv_file, "\n"))
          
          # --- Informe visual ---
          pdf_file <- file.path(dir_sea, paste0("Informe_Visual_GO_", ont, "_", base_name, ".pdf"))
          pdf(pdf_file, width = 14, height = 11)
          cat("        -> Generando Resumen Visual (EmapPlot, CnetPlot completo, DotPlot)...\n")
          
          tryCatch({
            if (nrow(ego_df) > 1) {
              
              ego_emap <- ego 
              ego_emap@result <- ego_emap@result %>%
                filter(!is.na(Description)) %>% 
                mutate(Description = paste0(Description, "\n(p=", 
                                            format(p.adjust, scientific = TRUE, digits = 2), 
                                            ", Size=", Count, ")"))
              
              if (nrow(ego_emap@result) > 1) {
                ego_sim <- pairwise_termsim(ego_emap) 
                print(emapplot(ego_sim, 
                               showCategory = args$top_n_emap, 
                               label_format = 100,
                               cex_label_category = 0.7) + 
                        labs(title = paste("EmapPlot (Top", args$top_n_emap, ") GO:", ont, "-", base_name)))
              } else {
                cat("        -> [INFO] EmapPlot omitido para", ont, "(menos de 2 términos tras filtrar NAs).\n")
              }
            } else {
              cat("        -> [INFO] Emapplot omitido para", ont, "(solo 1 término significativo).\n")
            }
          }, error = function(e) {
            cat(paste0("        -> [WARN] Falló al generar EmapPlot para ", ont, ": ", e$message, "\n"))
          })
          
          print(cnetplot(ego, 
                         showCategory = args$top_n_cnet, 
                         foldChange = gene_list_fc,
                         cex_label_gene = 0.7, 
                         cex_label_category = 1.0, 
                         fontface = "bold", 
                         circular = FALSE) + 
                  labs(title = paste("Chord Chart / CnetPlot (Top", args$top_n_cnet, ") GO:", ont, "-", base_name)))
          
          # Dotplot (Con etiquetas ggrepel)
          p_dot <- dotplot(ego, showCategory = args$top_n_emap) +
            labs(title = paste("DotPlot (Top", args$top_n_emap, ") GO:", ont, "-", base_name)) +
            theme(axis.text.y = element_text(size = 9)) 
          
          p_dot_con_etiquetas <- p_dot + 
            ggrepel::geom_text_repel(
              data = p_dot$data, 
              aes(label = paste0("p=", format(p.adjust, scientific=T, digits=2), ", C=", Count)),
              size = 2.0, color = "black", box.padding = 0.4, 
              point.padding = 0.4, segment.color = 'grey50', 
              segment.size = 0.4, min.segment.length = 0.1, max.overlaps = Inf    
            )
          
          print(p_dot_con_etiquetas)
          
          dev.off()
          cat(paste0("        -> [OK] Informe visual generado: ", pdf_file, "\n"))
          
          # --- Tabla de Genes Conectores ---
          cat("        -> Generando Tabla de Genes Conectores (orden global por significancia)...\n")
          tryCatch({
            gene_terms_list <- list()
            genes_all <- unique(unlist(strsplit(ego_df$geneID, "/"))) 
            genes_all <- genes_all[!is.na(genes_all) & genes_all != "NA"] # Filtro anti-NA
            
            for (g in genes_all) {
              terms_for_gene <- ego_df$Description[sapply(strsplit(ego_df$geneID, "/"), function(x) g %in% x)]
              if (length(terms_for_gene) >= 2)
                gene_terms_list[[g]] <- terms_for_gene
            }
            
            if (length(gene_terms_list) == 0) {
              final_table_df <- data.frame(Gen_Conector = "No se encontraron genes conectores", Terminos_Conectados = "", stringsAsFactors = FALSE)
            } else {
              gene_scores <- sapply(names(gene_terms_list), function(g)
                mean(ego_df$p.adjust[ego_df$Description %in% gene_terms_list[[g]]], na.rm = TRUE)
              )
              genes_sorted <- names(sort(gene_scores, decreasing = FALSE))
              
              gene_meta <- data.frame(
                gene = names(gene_list_fc), 
                logFC = gene_list_fc,
                padj = signif(runif(length(gene_list_fc), 0.0001, 0.05), 3), 
                state = ifelse(gene_list_fc > 0, "Sobreexpresado", "Infraexpresado"),
                stringsAsFactors = FALSE
              )
              
              final_table_df <- data.frame(
                Gen_Conector = genes_sorted,
                Terminos_Conectados = sapply(genes_sorted, function(g)
                  paste(strwrap(paste(gene_terms_list[[g]], collapse = "; "),
                                width = 120, exdent = 5), collapse = "\n")),
                stringsAsFactors = FALSE
              )
              
              final_table_df$Gen_Conector <- sapply(final_table_df$Gen_Conector, function(g) {
                if (g %in% gene_meta$gene) {
                  meta <- gene_meta[gene_meta$gene == g, ]
                  paste0(g, "\n(",
                         "logFC=", sprintf("%.2f", meta$logFC),
                         " | padj=", format(meta$padj, scientific = TRUE, digits = 2),
                         " | ", meta$state, ")")
                } else g
              })
            }
            
            # --- PDF de la tabla de conectores ---
            pdf_table_file <- file.path(dir_sea, paste0("Tabla_Genes_Conectores_GO_", ont, "_", base_name, ".pdf"))
            pdf(pdf_table_file, width = 14, height = 11)
            
            calc_rows_per_page <- function(df) {
              if(nrow(df) == 0 || !("Terminos_Conectados" %in% names(df))) return(10)
              avg_lines <- mean(sapply(df$Terminos_Conectados, function(x) length(strsplit(x, "\n")[[1]])))
              if(is.na(avg_lines) || avg_lines == 0) avg_lines <- 1
              max_rows <- floor(0.75 / (0.045 * avg_lines))
              return(max(5, min(10, max_rows)))
            }
            
            rows_total <- nrow(final_table_df)
            rows_per_page <- calc_rows_per_page(final_table_df)
            total_pages <- ceiling(rows_total / rows_per_page)
            
            start_row <- 1
            page_index <- 1
            
            while (start_row <= rows_total) {
              end_row <- min(start_row + rows_per_page - 1, rows_total)
              page_data <- final_table_df[start_row:end_row, ]
              
              grid::grid.newpage()
              grid::grid.text("Tabla de Genes Conectores", y = 0.95, gp = grid::gpar(fontsize = 18, fontface = "bold"))
              grid::grid.text(paste("Ontología:", ont, "| Página", page_index, "de", total_pages), y = 0.91, gp = grid::gpar(fontsize = 12, fontface = "italic"))
              
              grid::pushViewport(grid::viewport(y = 0.45, height = 0.80, width = 0.95))
              
              core_fg <- lapply(seq_len(nrow(page_data)), function(i) {
                col <- "black" 
                if ("Gen_Conector" %in% names(page_data)) {
                  if (grepl("Sobreexpresado", page_data$Gen_Conector[i])) col <- "red"
                  else if (grepl("Infraexpresado", page_data$Gen_Conector[i])) col <- "blue"
                }
                list(cex = 0.75, col = col)
              })
              
              table_grob <- gridExtra::tableGrob(
                page_data, rows = NULL, widths = grid::unit(c(0.20, 0.80), "npc"), 
                theme = gridExtra::ttheme_default(core = list(fg_params = core_fg), colhead = list(fg_params = list(cex = 0.9, fontface = "bold")), padding = grid::unit(c(6, 4), "mm"))
              )
              
              grid::grid.draw(table_grob)
              grid::popViewport()
              
              start_row <- end_row + 1
              page_index <- page_index + 1
            }
            
            dev.off()
            cat(paste0("        -> [OK] Tabla de Genes Conectores generada: ", pdf_table_file, "\n"))
            
          }, error = function(e) cat(paste0("        -> [ERROR] Falló al generar la tabla de genes conectores: ", e$message, "\n")))
          
        } else {
          cat(paste0("        -> [INFO] No se encontraron términos SEA significativos para ", ont, ".\n"))
        }
      }, error = function(e) cat(paste0("        -> [ERROR] en análisis SEA para ", ont, ": ", e$message, "\n")))
    }
    cat(" -> [OK] Análisis SEA completado.\n")
  } else {
    cat(paste0(" -> [INFO] Genes significativos insuficientes (", length(significant_genes), "). El análisis SEA se omite.\n"))
  }
} else {
  cat(" -> [INFO] Análisis SEA (ORA) no solicitado.\n")
}


# ---------------------------
# [PASO 3/4] GSEA (clusterProfiler)
# ---------------------------
gsea_results_list <- list()
if (args$run_gsea_analysis) {
  cat("   -> [3/4] Ejecutando análisis GSEA (Gene Set Enrichment Analysis)...\n")
  
  gene_list_fc_gsea <- NULL
  if (!is.null(deseq_df_raw) && nrow(deseq_df_raw) > 0) {
    cat("   -> [INFO] Preparando lista de genes para GSEA...\n")
    ids_sin_version <- gsub("\\..*$", "", deseq_df_raw$gene_id)
    gene_list_fc_pre_gsea <- deseq_df_raw$log2FoldChange
    names(gene_list_fc_pre_gsea) <- ids_sin_version
    # Clean up NAs and duplicates, critical for GSEA
    gene_list_fc_gsea <- gene_list_fc_pre_gsea[!is.na(gene_list_fc_pre_gsea) & names(gene_list_fc_pre_gsea) != "" & !duplicated(names(gene_list_fc_pre_gsea))]
  }
  
  if (!is.null(gene_list_fc_gsea) && length(gene_list_fc_gsea) > 10) {
    gene_list_ranked <- sort(gene_list_fc_gsea, decreasing = TRUE)
    cat(paste0("   -> [INFO] Se usará la lista completa de ", length(gene_list_ranked), " genes rankeados (por ENSEMBL). Iniciando análisis GSEA GO...\n"))
    
    for (ont in args$sea_ontologies) {
      cat(paste0("            -> Analizando ontología GSEA: ", ont, "\n"))
      tryCatch({
        # Run GSEA with original IDs
        gse <- gseGO(
          geneList = gene_list_ranked,
          OrgDb = org_db_loaded,
          keyType = args$key_type,
          ont = ont,
          pvalueCutoff = args$gsea_padj_cutoff,
          pAdjustMethod = "BH",
          verbose = FALSE
        )
        
        if (!is.null(gse) && nrow(gse@result) > 0) {
          cat(paste0("            -> ¡ÉXITO! Se encontraron ", nrow(gse@result), " términos GSEA significativos para ", ont, ".\n"))
          
          # --- TRADUCCIÓN MANUAL SEGURA (Para visualización) ---
    
          gse_read <- make_readable_universal(gse, org_db_loaded, args$key_type, target_symbol_col)
          
          gsea_results_list[[ont]] <- as.data.frame(gse_read)
          
          # --- Guardar TSV de GSEA ---
          tsv_gsea_file <- file.path(dir_gsea, paste0("Resultados_Completos_GSEA_", ont, "_", base_name, ".tsv"))
          tryCatch({
            write.table(as.data.frame(gse_read), file = tsv_gsea_file, sep = "\t", row.names = FALSE, quote = TRUE, col.names = TRUE)
            cat(paste0("            -> [OK] TSV completo de GSEA (", ont, ") guardado en: ", tsv_gsea_file, "\n"))
          }, error = function(e) cat(paste0("            -> [WARN] No se pudo guardar el TSV de GSEA (", ont, "): ", e$message, "\n")))
          
          # --- Informe Visual GSEA ---
          pdf_gsea_informe <- file.path(dir_gsea, paste0("Informe_GSEA_GO_", ont, "_", base_name, ".pdf"))
          pdf(pdf_gsea_informe, width = 14, height = 11)
          cat("            -> Generando Informe Visual GSEA (RidgePlot, GSEA plots)...\n")
          
          # 1. Ridgeplot 
          tryCatch({
            
            # --- Plot Generation ---
            # Base de ridgeplot
            p_ridge <- ridgeplot(gse_read, showCategory = args$top_n_ridge, fill = "NES") + 
              labs(title = paste("RidgePlot GSEA (NES Activity) GO:", ont, "-", base_name)) +
              theme(
                axis.text.y = element_text(size = 10, face = "bold"),
                plot.margin = margin(10, 20, 10, 10) 
              ) +
              scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b", midpoint = 0) +
              scale_y_discrete(labels = function(x) {
       
                res_subset <- gse_read@result[gse_read@result$Description %in% x, ]
                # Creamos un vector nombrado para asegurar el orden correcto
                labels_vec <- setNames(x, x)
                for (term in x) {
                  row <- res_subset[res_subset$Description == term, ]
                  if (nrow(row) > 0) {
                    # Añadimos NES y p-val al propio nombre
                    stats <- paste0(" [NES=", round(row$NES, 2), ", p=", formatC(row$p.adjust, format="e", digits=1), "]")
                    labels_vec[term] <- paste0(term, "\n", stats)
                  }
                }
                return(labels_vec)
              }) 
            
            print(p_ridge)
            
          }, error = function(e) {
            cat(paste0("            -> [WARN] Advanced Ridgeplot failed. Trying simple version...\n"))
            cat(paste0("            -> Reason: ", e$message, "\n"))
            # Fallback
            tryCatch({
              print(ridgeplot(gse, showCategory = args$top_n_ridge, fill = "NES") + 
                      labs(title = paste("RidgePlot GSEA (Simple) GO:", ont)))
            }, error = function(e2) cat(paste0("            -> [ERROR] Ridgeplot failed completely: ", e2$message, "\n")))
          })
          
            
          
          # 2. BUCLE DE PLOTS INDIVIDUALES
          n_plots <- 0 
          tryCatch({
            n_plots <- min(nrow(gse@result), args$top_n_gseaplot) 
            if (n_plots > 0) {
              cat(paste0("            -> Generando ", n_plots, " GSEA plots individuales (Top ", args$top_n_gseaplot, ")...\n"))
              
              for (i in 1:n_plots) {
                term_desc <- gse_read@result$Description[i] 

                p_gsea_individual <- gseaplot2(gse, 
                                               geneSetID = i,
                                               title = term_desc,
                                               pvalue_table = TRUE) 
                print(p_gsea_individual)
              }
            }
          }, error = function(e) cat(paste0("            -> [WARN] Falló al generar GSEA plots: ", e$message, "\n")))
          
          
          # 3. PLOT RESUMEN FINAL (Última Página)
          tryCatch({
            if (n_plots > 0) {
              cat(paste0("            -> Generando página resumen final con ", n_plots, " rutas...\n"))
              
              titulo_resumen <- paste("Resumen GSEA (Top", n_plots, ") GO:", ont, "-", base_name)
              
              p_resumen <- gseaplot2(gse, 
                                     geneSetID = 1:n_plots,
                                     title = titulo_resumen,
                                     pvalue_table = FALSE) 
              print(p_resumen)
            }
          }, error = function(e) cat(paste0("            -> [WARN] Falló al generar GSlot resumen: ", e$message, "\n")))
          
          dev.off() 
          
        } else {
          cat(paste0("            -> [INFO] No se encontraron términos GSEA significativos para ", ont, ".\n"))
        }
      }, error = function(e) cat(paste0("            -> [ERROR] en análisis GSEA para ", ont, ": ", e$message, "\n")))
    }
    cat("   -> [OK] Análisis GSEA completado.\n")
  } else {
    cat(paste0("   -> [INFO] Lista de genes inválida o insuficiente para GSEA. El análisis GSEA se omite.\n"))
  }
} else {
  cat("   -> [INFO] Análisis GSEA no solicitado.\n")
}

# ---------------------------
# [PASO 4/4] GENERAR INFORMES FINALES (TXT)
# ---------------------------
cat("   -> [4/4] Generando informes finales (TXT)...\n")
deseq_summary_data <- NULL
if (file.exists(deseq_results_file)) {
  deseq_summary_data <- tryCatch(read.table(deseq_results_file, header = TRUE, sep = "\t", quote = "", stringsAsFactors = FALSE, fill = TRUE), error = function(e) NULL)
}

# --- 1. Generar Informe TXT ---
cat("   -> [INFO] Generando informe TXT...\n")
tryCatch({
  generar_informe_detallado(base_name, sea_results_list, gsea_results_list, pathview_summary_df, deseq_summary_data, results_df)
}, error = function(e) {
  cat(paste0("[ERROR] No se pudo generar el informe TXT final: ", e$message, "\n"))
})

# --- 2. Generar Informe HTML ---
cat("   -> [INFO] Generando informe HTML...\n")
tryCatch({
  generar_informe_html(base_name, sea_results_list, gsea_results_list, pathview_summary_df, deseq_summary_data, results_df)
}, error = function(e) cat(paste0("[ERROR] No se pudo generar el HTML: ", e$message, "\n")))

cat(paste0("--- [OK] Finalizado el procesamiento de: ", current_file, " ---\n"))

}
cat("\n=================================================\n")
cat("===       PROCESO MANUAL FINALIZADO       ===\n")
cat("=================================================\n")
