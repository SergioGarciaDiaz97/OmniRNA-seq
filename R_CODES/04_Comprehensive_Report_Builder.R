# Informes_generator.R

# --- Cargar Librerías  ---
cat("📦 Cargando librerías necesarias...\n")
suppressPackageStartupMessages({
  if (!requireNamespace("argparse", quietly = TRUE)) install.packages("argparse", repos="http://cran.us.r-project.org")
  library(argparse)
  if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr", repos="http://cran.us.r-project.org")
  library(dplyr)
  if (!requireNamespace("tidyr", quietly = TRUE)) install.packages("tidyr", repos="http://cran.us.r-project.org")
  library(tidyr)
  if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2", repos="http://cran.us.r-project.org")
  library(ggplot2)
  if (!requireNamespace("gridExtra", quietly = TRUE)) install.packages("gridExtra", repos="http://cran.us.r-project.org")
  library(gridExtra)
  if (!requireNamespace("grid", quietly = TRUE)) install.packages("grid", repos="http://cran.us.r-project.org")
  library(grid)
  if (!requireNamespace("ggrepel", quietly = TRUE)) install.packages("ggrepel", repos="http://cran.us.r-project.org")
  library(ggrepel)
 
  if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager", repos="http://cran.us.r-project.org")
  if (!requireNamespace("gprofiler2", quietly = TRUE)) BiocManager::install("gprofiler2", ask=FALSE, update=FALSE)
  library(gprofiler2)
})


generar_pdf_contraste <- function(
    sig_genes_filename,      
    all_genes_filename,      
    output_pdf_filename,     
    output_huerfanos_filename, 
    ORGANISMO,               
    contraste_name_simple    
) {
 
  cat(paste("  -> 🎨 Iniciando la generación del PDF para:\n", basename(output_pdf_filename), "\n"))
 
  # --- 1. Parámetros de visualización---
  FUENTES_DATOS <- c("GO:MF", "GO:BP", "GO:CC", "KEGG", "REAC")
  STRIP_GENE_VERSION <- TRUE 
  LOG2FC_THRESHOLD <- 1.0
  GENES_POR_PAGINA_TABLA <- 25
  VIAS_POR_PAGINA_GRAFICO <- 30
  P_VALUE_TOPE <- 1e-16
  VOLCANO_GENES_A_ETIQUETAR <- 15
 

  tryCatch({
   

    cat(paste("    -> 📥 Cargando genes SIGNIFICATIVOS de:", basename(sig_genes_filename), "\n"))
    sig_genes_data <- read.delim(sig_genes_filename, header = TRUE, sep = "\t",
                                 stringsAsFactors = FALSE, fill = TRUE, comment.char = "")
    lista_genes_significativos <- sig_genes_data$gene_id
    if (STRIP_GENE_VERSION) lista_genes_significativos <- sub("\\..*$", "", lista_genes_significativos)
    lista_genes_significativos <- unique(lista_genes_significativos)
    cat(paste("      ->", length(lista_genes_significativos), "genes significativos únicos.\n"))
   
    cat(paste("    -> 📥 Cargando TODOS los genes de:", basename(all_genes_filename), "\n"))
    all_genes_data <- read.delim(all_genes_filename, header = TRUE, sep = "\t",
                                 stringsAsFactors = FALSE, fill = TRUE, comment.char = "")
   
    # --- 3. Ejecutar g:Profiler ---

    cat(paste("    -> 🌐 Ejecutando consulta a g:Profiler para", ORGANISMO, "...\n"))
    gost_results <- tryCatch({
      gost(query = lista_genes_significativos,
           organism = ORGANISMO,
           sources = FUENTES_DATOS,
           user_threshold = 0.05,
           correction_method = "g_SCS",
           domain_scope = "annotated",
           evcodes = TRUE)
    }, error = function(e) {
      cat("    -> ❌ ERROR en g:Profiler:", e$message, "\n")
      return(NULL)
    })
   
    if (is.null(gost_results) || is.null(gost_results$result) || nrow(gost_results$result) == 0) {
        cat("    -> ❌ g:Profiler no devolvió resultados para este contraste. Saltando PDF.\n")
        return() 
    }
   
    gprofiler_data_correcta <- gost_results$result
    cat(paste("      -> ¡Éxito! g:Profiler encontró", nrow(gprofiler_data_correcta), "términos enriquecidos.\n"))
   
    cat("    -> ⚙️ Procesando y cruzando datos...\n")
   
    rutas_expandidas <- gprofiler_data_correcta %>%
      dplyr::select(term_id, term_name, source, intersection) %>%
      tidyr::separate_rows(intersection, sep = ",") %>%
      dplyr::rename(join_key = intersection) %>%
        dplyr::mutate(
        join_key_id = trimws(join_key),
     
        join_key_symbol = NA_character_
    )
    deseq_con_key <- all_genes_data %>%
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
      dplyr::select(source, term_id, term_name, gene_id, join_key_id, symbol,
                    log2FoldChange_num, padj_num, baseMean) %>%
      dplyr::mutate(Regulacion = ifelse(log2FoldChange_num > LOG2FC_THRESHOLD, "UP", "DOWN")) %>%
      dplyr::arrange(padj_num) %>%
      dplyr::distinct()
   
    # --- Buscar y guardar genes "huérfanos" ---
    cat(paste("    -> 🧬 Buscando genes huérfanos...\n"))
   
    genes_mapeados_en_rutas <- unique(datos_finales_ordenados$join_key_id)
    sig_genes_data_con_key <- sig_genes_data
   
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
   
    cat(paste("      -> ¡Encontrados!", total_huerfanos, "genes huérfanos.\n"))
   
    # Guardar la tabla de huérfanos específica para este contraste
    tryCatch({
      write.table(tabla_huerfanos_completa, output_huerfanos_filename,
                 row.names = FALSE, na = "", sep = "\t", quote = FALSE)
      cat(paste("    -> 💾 Tabla de huérfanos guardada en:", basename(output_huerfanos_filename), "\n"))
    }, error = function(e) {
      cat("    -> ⚠️ Error al guardar TXT de huérfanos:", e$message, "\n")
    })
   
 
    # =========================================================================
    # --- 7. PASE 1: Generar Índice---
    # =========================================================================
    cat("    -> 📑 Generando Índice (Pase 1/2)...\n")
   
    toc_data <- data.frame(Nombre = character(), Pagina = integer())
    pagina_pdf_actual <- 1 
    pagina_pdf_actual <- 2 
   
    pagina_pdf_actual <- 3
    toc_data <- rbind(toc_data, data.frame(Nombre = "Resumen de Genes Huérfanos", Pagina = pagina_pdf_actual))
   
    fuentes_ordenadas <- c("GO:MF", "GO:BP", "GO:CC", "REAC", "KEGG")
    nombres_fuentes <- c("GO:MF - Funciones Moleculares",
                        "GO:BP - Procesos Biológicos",
                        "GO:CC - Componentes Celulares",
                        "REAC - Rutas Reactome",
                        "KEGG - Rutas Metabólicas")
   
    for (idx in 1:length(fuentes_ordenadas)) {
      fuente_actual <- fuentes_ordenadas[idx]
      nombre_largo_fuente <- nombres_fuentes[idx]
     
      datos_fuente <- gprofiler_data_correcta %>%
        dplyr::filter(source == fuente_actual) %>%
        dplyr::arrange(p_value)
     
      if (nrow(datos_fuente) == 0) {
        next
      }
     
      pagina_pdf_actual <- pagina_pdf_actual + 1
      toc_data <- rbind(toc_data, data.frame(Nombre = paste("Resumen -", nombre_largo_fuente), Pagina = pagina_pdf_actual))
     
      genes_en_seccion <- datos_finales_ordenados %>%
        dplyr::filter(source == fuente_actual) %>%
        dplyr::distinct(gene_id, symbol, log2FoldChange_num, padj_num, Regulacion)
     
      if(nrow(genes_en_seccion) > 0) {
        pagina_pdf_actual <- pagina_pdf_actual + 1
        toc_data <- rbind(toc_data, data.frame(Nombre = paste("  Volcano Plot -", fuente_actual), Pagina = pagina_pdf_actual))
      }
     
      conteo_por_ruta_fuente <- datos_finales_ordenados %>%
        dplyr::filter(source == fuente_actual) %>%
        dplyr::group_by(term_name, Regulacion) %>%
        dplyr::tally()
     
      conteo_con_padj_fuente <- conteo_por_ruta_fuente %>%
        dplyr::left_join(datos_fuente %>% dplyr::select(term_name, p_value), by = "term_name") %>%
        dplyr::filter(!is.na(p_value)) %>%
        dplyr::arrange(p_value)
     
      lista_rutas_grafico_fuente <- unique(conteo_con_padj_fuente$term_name)
     
      if (length(lista_rutas_grafico_fuente) > 0) {
        grupos_de_rutas <- split(lista_rutas_grafico_fuente,
                                 ceiling(seq_along(lista_rutas_grafico_fuente) / VIAS_POR_PAGINA_GRAFICO))
       
        toc_data <- rbind(toc_data, data.frame(Nombre = paste("  Gráficos -", fuente_actual), Pagina = pagina_pdf_actual + 1))
        pagina_pdf_actual <- pagina_pdf_actual + length(grupos_de_rutas)
      }
     
      total_paginas_tablas_fuente <- 0
      if (length(lista_rutas_grafico_fuente) > 0) {
        paginas_por_ruta <- datos_finales_ordenados %>%
          dplyr::filter(term_name %in% lista_rutas_grafico_fuente) %>%
          dplyr::group_by(term_name) %>%
          dplyr::tally() %>%
          dplyr::mutate(paginas_ruta = ceiling(n / GENES_POR_PAGINA_TABLA))
       
        total_paginas_tablas_fuente <- sum(paginas_por_ruta$paginas_ruta)
       
        toc_data <- rbind(toc_data, data.frame(Nombre = paste("  Tablas -", fuente_actual), Pagina = pagina_pdf_actual + 1))
        pagina_pdf_actual <- pagina_pdf_actual + total_paginas_tablas_fuente
      }
    }
    cat("      -> Índice generado. Páginas estimadas:", pagina_pdf_actual, "\n")
   
   
    # =========================================================================
    # --- 8. Generar PDF Definitivo ---
    # =========================================================================
    cat(paste("    -> 🎨 Generando PDF:", basename(output_pdf_filename), "(Pase 2/2)...\n"))
    pdf(output_pdf_filename, width = 12, height = 8.5)
   
    # --- PÁGINA 1: Portada ---
    pagina_pdf_actual <- 1
    grid.newpage()
    grid.text("Análisis de Enriquecimiento Funcional", y = 0.8, gp = gpar(fontsize = 28, fontface = "bold"))
    grid.text(paste("Contraste:", contraste_name_simple), y = 0.7, gp = gpar(fontsize = 14, fontface="italic"))
    grid.text(paste("Organismo:", ORGANISMO), y = 0.6, gp = gpar(fontsize = 16))
    grid.text(paste("Archivos de entrada:"), y = 0.5, gp = gpar(fontsize = 12, fontface = "bold"))
    grid.text(basename(sig_genes_filename), y = 0.45, gp = gpar(fontsize = 10, fontface = "italic"))
    grid.text(basename(all_genes_filename), y = 0.42, gp = gpar(fontsize = 10, fontface = "italic"))
    grid.text(paste("Fuentes de datos:", paste(FUENTES_DATOS, collapse=", ")), y = 0.35, gp = gpar(fontsize = 12))
    grid.text(paste("Generado el:", Sys.Date()), y = 0.1, gp = gpar(fontsize = 9, col = "grey"))
   
    # --- PÁGINA 2: Índice ---
    pagina_pdf_actual <- 2
    grid.newpage()
    grid.text("Índice del Informe", y = 0.9, gp = gpar(fontsize = 20, fontface = "bold"))
   
    y_start <- 0.85
    for (i in 1:nrow(toc_data)) {
      nombre_seccion <- toc_data$Nombre[i]
      numero_pagina <- toc_data$Pagina[i]
     
      if (startsWith(nombre_seccion, "  ")) {
        x_pos <- 0.15
        fuente <- "italic"
        tamano <- 10
      } else {
        x_pos <- 0.1
        fuente <- "bold"
        tamano <- 12
        y_start <- y_start - 0.01
      }
     
      grid.text(nombre_seccion, x = x_pos, y = y_start, just = "left", gp = gpar(fontsize = tamano, fontface = fuente))
      puntos <- paste(rep(".", 60 - nchar(nombre_seccion)), collapse = "")
      grid.text(puntos, x = x_pos + 0.02, y = y_start, just = "left", gp = gpar(fontsize = tamano, col = "grey"))
      grid.text(numero_pagina, x = 0.9, y = y_start, just = "right", gp = gpar(fontsize = tamano, fontface = fuente))
     
      y_start <- y_start - 0.04
      if (y_start < 0.1) {
        grid.newpage()
        grid.text("Índice del Informe (cont.)", y = 0.9, gp = gpar(fontsize = 20, fontface = "bold"))
        y_start <- 0.85
      }
    }
   
    # --- PÁGINA 3: Resumen de Huérfanos ---
    pagina_pdf_actual <- 3
    grid.newpage()
    grid.text("Resumen de Cobertura del Análisis", y = 0.9, gp = gpar(fontsize = 20, fontface = "bold"))
   
    grid.text(paste("Total de genes significativos de entrada:", total_genes_originales), y = 0.80, gp = gpar(fontsize = 12))
    grid.text(paste("Genes mapeados en rutas enriquecidas:", total_genes_mapeados), y = 0.75, gp = gpar(fontsize = 12))
    grid.text(paste("Total de Genes Huérfanos:", total_huerfanos), y = 0.70, gp = gpar(fontsize = 12, col = "red", fontface = "bold"))
   
    grid.text("Desglose de los Genes Huérfanos:", y = 0.55, gp = gpar(fontsize = 14, fontface = "bold"))
    grid.text(paste("(Genes que NO están en las", nrow(gprofiler_data_correcta), "rutas enriquecidas)"), y = 0.52, gp = gpar(fontsize = 9, fontface = "italic"))
   
    grid.text(paste("- Genes sin símbolo (NA o ''):", sin_simbolo), y = 0.45, gp = gpar(fontsize = 12))
    grid.text(paste("- Genes con anotación no informativa (LOC..., si:..., zgc:...):", simbolo_raro), y = 0.40, gp = gpar(fontsize = 12))
    grid.text(paste("- Con símbolo real (pero en rutas no enriquecidas):", anotados_reales), y = 0.35, gp = gpar(fontsize = 12))
   
    grid.text(paste("La tabla completa con los", total_huerfanos, "genes huérfanos se ha guardado en '", basename(output_huerfanos_filename), "'"),
          y = 0.15, gp = gpar(fontsize = 10, fontface = "italic"))
   
    # --- BUCLE PRINCIPAL POR SECCIONES (GO:MF, GO:BP, etc.) ---
   
    for (idx in 1:length(fuentes_ordenadas)) {
   
      fuente_actual <- fuentes_ordenadas[idx]
      nombre_largo_fuente <- nombres_fuentes[idx]
   
      datos_fuente <- gprofiler_data_correcta %>%
        dplyr::filter(source == fuente_actual) %>%
        dplyr::arrange(p_value)
   
      if (nrow(datos_fuente) == 0) {
        next
      }
   
      # --- PÁGINA DE RESUMEN DE LA SECCIÓN ---
      pagina_pdf_actual <- pagina_pdf_actual + 1
      grid.newpage()
      grid.text(paste("Sección de Análisis:", nombre_largo_fuente), y = 0.9, gp = gpar(fontsize = 20, fontface = "bold"))
   
      total_terminos <- nrow(datos_fuente)
      terminos_tope <- datos_fuente %>% dplyr::filter(p_value < P_VALUE_TOPE)
      n_tope <- nrow(terminos_tope)
   
      grid.text(paste("Total de términos enriquecidos en esta sección:", total_terminos), y = 0.80, gp = gpar(fontsize = 12))
      grid.text(paste("Términos 'Tope' (p-valor < 1e-16):", n_tope), y = 0.75, gp = gpar(fontsize = 12, col = "red", fontface = "bold"))
   
      if (n_tope > 0) {
        grid.text("Términos que superan el 'tope' de significancia:", y = 0.65, gp = gpar(fontsize = 14, fontface = "bold"))
        lista_tope_texto <- paste0("- ", terminos_tope$term_name, " (", terminos_tope$term_id, ", p-val: ", format(terminos_tope$p_value, scientific = TRUE, digits = 2), ")")
        if (length(lista_tope_texto) > 10) {
          lista_tope_texto <- c(lista_tope_texto[1:10], "...y otros")
        }
        y_start <- 0.60
        for (linea_tope in lista_tope_texto) {
          y_start <- y_start - 0.04
          grid.text(linea_tope, y = y_start, x = 0.1, just = "left", gp = gpar(fontsize = 9, fontface = "italic"))
        }
      }
      grid.text(paste("A continuación se muestran los gráficos de barras y tablas de genes para esta sección."), y = 0.15, gp = gpar(fontsize = 10))
   
   
      # --- PÁGINA DE VOLCANO PLOT ---
      genes_en_seccion <- datos_finales_ordenados %>%
        dplyr::filter(source == fuente_actual) %>%
        dplyr::distinct(gene_id, symbol, log2FoldChange_num, padj_num, Regulacion) %>%
        dplyr::mutate(logP = -log10(padj_num))
   
      if(nrow(genes_en_seccion) > 0) {
        pagina_pdf_actual <- pagina_pdf_actual + 1
       
        max_logP <- max(genes_en_seccion$logP[is.finite(genes_en_seccion$logP)], na.rm = TRUE)
        genes_en_seccion$logP <- ifelse(is.finite(genes_en_seccion$logP), genes_en_seccion$logP, max_logP + 5)
       
        genes_para_etiquetar <- genes_en_seccion %>%
          dplyr::filter(!is.na(symbol) & symbol != "") %>%
          dplyr::arrange(padj_num) %>%
          head(VOLCANO_GENES_A_ETIQUETAR)
       
        volcano_plot <- ggplot(genes_en_seccion, aes(x = log2FoldChange_num, y = logP, color = Regulacion)) +
          geom_point(alpha = 0.5) +
          scale_color_manual(values = c("UP" = "#e41a1c", "DOWN" = "#377eb8", "NEUTRAL" = "grey"),
                             labels = c("DOWN", "UP")) +
          theme_minimal(base_size = 12) +
          labs(title = paste("Volcano Plot -", nombre_largo_fuente),
               subtitle = paste("Mostrando", nrow(genes_en_seccion), "genes únicos mapeados en esta sección"),
               x = "Log2 Fold Change",
               y = "-log10(p-valor ajustado del gen)") +
          geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "grey40") +
          geom_vline(xintercept = c(-LOG2FC_THRESHOLD, LOG2FC_THRESHOLD), linetype = "dashed", color = "grey40") +
          ggrepel::geom_text_repel(data = genes_para_etiquetar,
                                   aes(label = symbol),
                                   color = "black", size = 3, max.overlaps = 20) +
          theme(legend.position = "bottom",
                plot.title = element_text(face = "bold", size = 16))
       
        print(volcano_plot)
      }
   
      # --- PÁGINAS DE GRÁFICOS (paginado) ---
      conteo_por_ruta_fuente <- datos_finales_ordenados %>%
        dplyr::filter(source == fuente_actual) %>%
        dplyr::group_by(term_name, Regulacion) %>%
        dplyr::tally()
   
      total_genes_por_ruta_fuente <- conteo_por_ruta_fuente %>%
        dplyr::group_by(term_name) %>%
        dplyr::summarise(total_genes = sum(n))
   
      conteo_final_plot <- dplyr::left_join(conteo_por_ruta_fuente, total_genes_por_ruta_fuente, by = "term_name")
   
      conteo_con_padj_fuente <- conteo_final_plot %>%
        dplyr::left_join(datos_fuente %>% dplyr::select(term_name, p_value), by = "term_name") %>%
        dplyr::filter(!is.na(p_value)) %>%
        dplyr::arrange(p_value) %>%
        dplyr::mutate(
          p_valor_fmt = format(p_value, scientific = TRUE, digits = 2),
          term_name_con_pvalor = paste0(term_name, " (p=", p_valor_fmt, ")")
        )
   
      lista_rutas_grafico_fuente <- unique(conteo_con_padj_fuente$term_name)
   
      if (length(lista_rutas_grafico_fuente) > 0) {
     
        grupos_de_rutas <- split(lista_rutas_grafico_fuente,
                                 ceiling(seq_along(lista_rutas_grafico_fuente) / VIAS_POR_PAGINA_GRAFICO))
        total_paginas_grafico_fuente <- length(grupos_de_rutas)
     
        for (pagina in seq_along(grupos_de_rutas)) {
          pagina_pdf_actual <- pagina_pdf_actual + 1
          rutas_pagina_actual <- grupos_de_rutas[[pagina]]
       
          datos_plot_pagina <- conteo_con_padj_fuente %>%
            dplyr::filter(term_name %in% rutas_pagina_actual)
       
          niveles_ordenados <- rev(datos_plot_pagina %>%
                                     dplyr::distinct(term_name, p_value, term_name_con_pvalor) %>%
                                     dplyr::arrange(p_value) %>%
                                     dplyr::pull(term_name_con_pvalor))
       
          grafico_pagina <- ggplot(datos_plot_pagina,
                                   aes(x = factor(term_name_con_pvalor, levels = niveles_ordenados), y = n, fill = Regulacion)) +
            geom_bar(stat = "identity") +
            geom_text(aes(label = n), position = position_stack(vjust = 0.5), color = "white", size = 3) +
            coord_flip() +
            scale_fill_manual(values = c("UP" = "#e41a1c", "DOWN" = "#377eb8")) +
            labs(title = paste(nombre_largo_fuente, "- Gráfico (Pág.", pagina, "de", total_paginas_grafico_fuente, ")"),
                 x = "Ruta Funcional (p-valor de la ruta)", y = "Número de Genes") +
            theme_minimal(base_size = 10) +
            theme(plot.title = element_text(face = "bold", size = 16),
                  axis.text.y = element_text(size = 8), legend.position = "bottom")
          print(grafico_pagina)
        }
      }
   
      # --- PÁGINAS DE TABLAS (paginado) ---
      lista_rutas_unicas_tablas <- lista_rutas_grafico_fuente
   
      if (length(lista_rutas_unicas_tablas) > 0) {
     
        for (ruta_actual in lista_rutas_unicas_tablas) {
          datos_ruta <- datos_finales_ordenados %>%
            dplyr::filter(term_name == ruta_actual) %>%
            dplyr::arrange(padj_num)
       
          total_genes <- nrow(datos_ruta)
          if (total_genes == 0) { next }
       
          p_valor_ruta <- gprofiler_data_correcta %>%
            dplyr::filter(term_name == ruta_actual) %>%
            dplyr::pull(p_value)
          p_valor_formateado <- format(p_valor_ruta[1], scientific = TRUE, digits = 3)
       
          total_paginas_ruta <- ceiling(total_genes / GENES_POR_PAGINA_TABLA)
          secciones <- split(datos_ruta, ceiling(seq_len(total_genes) / GENES_POR_PAGINA_TABLA))
       
          for (i in seq_along(secciones)) {
            pagina_pdf_actual <- pagina_pdf_actual + 1
            seccion_actual <- secciones[[i]]
         
            grid.newpage()
         
            tabla_para_imprimir <- seccion_actual %>%
              dplyr::mutate(
                log2FoldChange = round(log2FoldChange_num, 3),
                padj = format(padj_num, scientific = TRUE, digits = 3),
                baseMean = round(as.numeric(baseMean), 1)
              ) %>%
              dplyr::select(gene_id, symbol, Regulacion, log2FoldChange, padj, baseMean)
         
            colores_filas <- ifelse(seccion_actual$log2FoldChange_num > LOG2FC_THRESHOLD, "#e41a1c", "#377eb8")
            matriz_colores <- matrix("black", nrow = nrow(tabla_para_imprimir), ncol = ncol(tabla_para_imprimir))
         
            col_idx_reg <- which(colnames(tabla_para_imprimir) == "Regulacion")
            col_idx_lfc <- which(colnames(tabla_para_imprimir) == "log2FoldChange")
            matriz_colores[, col_idx_reg] <- colores_filas
            matriz_colores[, col_idx_lfc] <- colores_filas
         
            theme_tabla_coloreada <- gridExtra::ttheme_default(
              core = list(fg_params = list(col = matriz_colores, cex = 0.8)),
              colhead = list(fg_params = list(fontface = "bold", cex = 0.9)),
              padding = unit(c(4, 4), "mm")
            )
         
            titulo_ruta <- paste0("Ruta: ", ruta_actual)
            if (total_paginas_ruta > 1) {
              titulo_ruta <- paste0(titulo_ruta, " (Página ", i, " de ", total_paginas_ruta, ")")
            }
            grid::grid.text(titulo_ruta, y = 0.95, gp = gpar(fontsize = 15, fontface = "bold"))
         
            subtitulo_ruta <- paste("Fuente:", seccion_actual$source[1],
                                    "| ID:", seccion_actual$term_id[1],
                                    "| Genes:", total_genes,
                                    "| p-valor ruta:", p_valor_formateado)
            grid::grid.text(subtitulo_ruta, y = 0.90, gp = gpar(fontsize = 9, fontface = "italic", col = "gray30"))
         
            grob_tabla <- gridExtra::tableGrob(tabla_para_imprimir, rows = NULL, theme = theme_tabla_coloreada)
            pushViewport(viewport(y = 0.45, height = 0.8))
            grid.draw(grob_tabla)
            popViewport()
         
            } 
          }
        }
    } 
   
    # --- 9. Cierre del PDF ---
    dev.off()
   
    cat(paste("    -> ✅ ¡ÉXITO! Informe PDF de", pagina_pdf_actual, "páginas guardado.\n"))
   
  }, error = function(e) {

    cat(paste("    -> ❌❌❌ ERROR FATAL al generar el PDF:", basename(output_pdf_filename), "\n"))
    cat(paste("    -> Error:", e$message, "\n"))

    if (names(dev.cur()) == "pdf") {
      dev.off()
    }
  })
 
} 


# =========================================================================
# --- SECCIÓN 2: SCRIPT PRINCIPAL (BATCH RUNNER) ---

# =========================================================================

# --- 2.1 Argumentos de entrada para el script BATCH ---
parser <- ArgumentParser(description='Generador de Informes PDF para todos los contrastes de un análisis DESeq2.')
parser$add_argument('--input_dir', type="character", required=TRUE,
                    help="Directorio que contiene los resultados del pipeline DESeq2 (ej: /home/user/proyecto/resultados_deseq)")
parser$add_argument('--organism', type="character", required=TRUE,
                    help="Organismo para g:Profiler (ej: drerio, hsapiens, mmusculus)")
args <- parser$parse_args()

# --- 2.2 Búsqueda de archivos ---
cat(paste("\n🚀 Iniciando generador de informes en lote en:", args$input_dir, "\n"))
cat(paste("🔬 Organismo definido:", args$organism, "\n"))

# Buscamos los archivos "Completos" para usarlos como guía
files_completos <- list.files(path = args$input_dir,
                             pattern = "^Resultados_Completos_.*\\.txt$",
                             full.names = TRUE)

if (length(files_completos) == 0) {
  cat(paste("❌ No se encontraron archivos 'Resultados_Completos_...txt' en el directorio:\n", args$input_dir, "\n"))
  cat("Asegúrate de haber ejecutado el pipeline v17 primero y de que los resultados están en esa carpeta.\n")
  stop("Proceso detenido.", call. = FALSE)
}

cat(paste("🔍 Encontrados", length(files_completos), "contrastes para procesar.\n"))

# --- 2.3 Bucle principal ---
total_contrastes <- length(files_completos)

for (i in 1:total_contrastes) {
  all_file_path <- files_completos[i]
 
  # 1. Extraer el nombre del contraste

  contraste_name <- sub("Resultados_Completos_(.*)\\.txt$", "\\1", basename(all_file_path))
 
  cat(paste0("\n",
             "=====================================================================\n",
             "  PROCESANDO CONTRASTE (", i, " de ", total_contrastes, "): ", contraste_name, "\n",
             "=====================================================================\n"))
 
  # 2. Construir los nombres de los otros archivos necesarios
  sig_file_path <- file.path(args$input_dir, paste0("Resultados_Significativos_", contraste_name, ".txt"))
  pdf_output_path <- file.path(args$input_dir, paste0("Informe_Transcriptomica_Completo_", contraste_name, ".pdf"))
  huerfanos_output_path <- file.path(args$input_dir, paste0("genes_huerfanos_", contraste_name, ".txt")) 
 
  # 3. Verificar que existen los archivos
  if (!file.exists(sig_file_path)) {
    cat(paste("  -> ⚠️ ADVERTENCIA: No se encontró el archivo 'Significativos' esperado:\n",
              basename(sig_file_path), "\n",
              "  -> Saltando este contraste.\n"))
    next 
  }
 
  # 4. Llamar a la función de generación de PDF
  generar_pdf_contraste(
    sig_genes_filename = sig_file_path,
    all_genes_filename = all_file_path,
    output_pdf_filename = pdf_output_path,
    output_huerfanos_filename = huerfanos_output_path,
    ORGANISMO = args$organism,
    contraste_name_simple = contraste_name
  )
}

cat("\n🎯 Proceso de generación de informes en lote completado.\n")