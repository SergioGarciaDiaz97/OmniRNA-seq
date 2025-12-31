<h2 style="display: flex; align-items: center; gap: 15px;">
  <img src="./assets/adn.gif" width="80" style="vertical-align: middle;">
  <span style="line-height: 1; font-weight: bold;">OmniRNA-seq: High-Performance HPC Transcriptomics Pipeline</span>
</h2>

OmniRNA-seq es un ecosistema bioinformático integral para el análisis automatizado y reproducible de datos de RNA‑seq bulk en entornos HPC. Transforma lecturas crudas de secuenciación en resultados biológicos interpretables y listos para publicación, desacoplando la ingeniería de datos (Python) del modelado estadístico avanzado (R/Bioconductor) y del despliegue reproducible basado en contenedores Apptainer/Singularity.

El sistema es agnóstico al organismo, con soporte nativo y flujos de anotación validados para una amplia gama de modelos biológicos, incluyendo ***Homo sapiens***, ***Mus musculus***, ***Saccharomyces cerevisiae***, ***Arabidopsis thaliana***, ***Danio rerio***, ***Caenorhabditis elegans*** y ***Drosophila melanogaster***.

## 📚 Índice
_Haz clic en cualquier apartado para ir directamente a la sección._
1. [Organización del Proyecto](#organizacion)
2. [Modos de Ejecución](#modos)
3. [Launcher Maestro](#launcher)
4. [Dependencias y Contenedores](#dependencias-y-entorno-de-ejecución-contenedores)
5. [Centro de Configuración JSON](#centro-de-control-de-configuración-json)
6. [Requisitos de Metadatos](#requisitos-de-metadatos-metadata_archivos)
7. [Arquitectura del Sistema](#arquitectura-del-sistema)
8. [Estructura Global de Resultados](#estructura-global-de-resultados-output-tree)
9. [Autoría y Colaboraciones](#autoría-impacto-y-colaboración)
---

<a id="organizacion"></a>
## 📂 $\color{#8B0000}{\text{1. Organización del Proyecto (Separation of Concerns)}}$
Para que funcione el pipeline es necesario alojar los diferentes archivos en las carpetas indicadas a continuación.

```text
OmniRNA-seq/
├── RNA_SEQ_LETS_TRY.sh        # Launcher maestro (HPC / SLURM)
├── JSON/                      # Configuración del experimento (El Contrato)
│   ├── project01.json 
│   └── ...
│ 
├── Metadata_Archivos/         # Archivos CSV de diseño experimental
│   ├── metadata_project01.csv
│   └── ...
│
├── src/
│   └── PYTHON_CODES/          # Orquestación
│       ├── main.py
│       ├── experiment_profiler.py
│       ├── data_conector.py
│       └── 01_pipeline_core.py
│
├── R_CODES/                   # Motor Estadístico y Biológico
│   ├── 01_EDA_QC.R
│   ├── 02_Differential_expression.R
│   ├── 03_Functional_analysis_viz.R
│   └── 04_Comprehensive_Report_Builder.R
│
└── logs/                      # Trazas de ejecución SLURM
```
**Flujo lógico:**  
`Python (data engineering) → R (estadística/biológica) → PDFs publicables`

---

<a id="modos"></a> 
## 🚀 $\color{#8B0000}{\text{2. Modos de Ejecución (Orquestación Inteligente):}}$

El pipeline implementa una lógica de decisión automatizada para determinar el flujo de trabajo óptimo. Esta decisión se basa en la fuente de los datos (**públicos vs. locales**) y el formato de entrada (**crudos vs. matriz**).

Existen los parámetros `cleanup_only_fastq` y `retain_only_fastqc_and_bam` (ver apartado [5. Configuración JSON](#-5-centro-de-control-de-configuración-json)) para ahorrar espacio de almacenamiento.

<details>
<summary>$\Large \color{#000080}{\textbf{2.1. 🌍 Modo Explorer (Recuperación Automatizada)}}$</summary>

<br>

<div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; margin: 10px 0; border-radius: 4px;">
<span style="font-size: 1.2em;">💡</span> 
<span style="font-weight: bold; color: #856404;"><b>Ideal para: </b></span> Explorar y replicar análisis con archivos públicos ubicados <b>GEO, ENA o SRA</b>.<br>
<span style="font-weight: bold; color: #856404;">Activación:</span> Requiere suministrar un <b>Project_ID</b> (ej. PRJNA, SRP) como argumento.
</div>

### $\color{#2E8B57}{\text{Flujo Completo (End-to-End Processing):}}$
- **Configuración:** `"counting_method": "featureCounts"`.
- **Descripción:** Interroga las APIs de ENA/SRA para recuperar automáticamente metadatos y FASTQs. Ejecuta el pipeline integral: QC, alineamiento y cuantificación.

### $\color{#2E8B57}{\text{Flujo Acelerado (Direct Matrix Analysis - Public):}}$
- **Configuración:** `"counting_method": "precomputed_csv" + URL remota`.
- **Descripción:** Descarga la matriz de conteos directamente del autor, omitiendo el alineamiento para saltar al análisis estadístico y funcional.

**Sintaxis (Bash):**
```bash
sbatch RNA_SEQ_LETS_TRY.sh JSON/config.json PRJNAxxxx
```
</details> 

<details>
<summary>$\Large \color{#000080}{\textbf{2.2. 💻 Modo Local (Infraestructura Privada / On-Premise)}}$</summary>
<br>

<div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; margin: 10px 0; border-radius: 4px;">
<span style="font-size: 1.2em;">💡</span> 
<span style="font-weight: bold; color: #856404;"><b>Ideal para: </b></span> Análisis de datos propios del laboratorio o colaboraciones privadas, sin conexión a APIs externas.<br>
<span style="font-weight: bold; color: #856404;"><b>Activación:</b></span> Se ejecuta <b>sin</b> argumento de Project_ID. Como tutorial para el modo local hemos replicado este método partiendo de muestras fastq descargadas (<b>ver sección en este GitHub en carpeta Modo local</b>).
</div>

### $\color{#2E8B57}{\text{Flujo Completo (End-to-End Processing):}}$
- **Configuración:** `"fastq_list_strategy": "manual" + Manifiesto de archivos.`.
- **Descripción:** Procesa archivos FASTQ alojados en el sistema de ficheros local. Utiliza un manifiesto de rutas (URI file://) para ingerir las muestras y ejecutar el alineamiento y conteo.

### $\color{#2E8B57}{\text{Flujo Acelerado Local (Direct Matrix Analysis - Local):}}$
- **Configuración:** `"counting_method": "precomputed_csv" + Ruta local al archivo.`.
- **Descripción:** Ingesta directa de una matriz de conteos (.csv) suministrada externamente o pre-calculada.

**Sintaxis (Bash):**
```bash
sbatch RNA_SEQ_LETS_TRY.sh JSON/config.json
```
</details> 
<br>

<div style="
  background-color:#eef4fb;
  border-left:5px solid #1e3a8a;
  padding:14px;
  margin:14px 0;
  border-radius:6px;
">
<b>Resiliencia Automática:</b><br>
Gracias a su arquitectura modular, OmniRNA-seq es capaz de retomar ejecuciones interrumpidas. Si un job es cancelado por el clúster por exceder el tiempo de pared (walltime), basta con re-lanzar el comando original; el sistema detectará los pasos completados y los archivos válidos, saltando directamente a la etapa pendiente.
</div>

<br><br>

<a id="launcher"></a>
## 🎛️ $\color{#8B0000}{\text{3. Punto de entrada: Launcher maestro.sh}}$

<div style="
  background-color:#eef4fb;
  border-left:5px solid #1e3a8a;
  padding:14px;
  margin:14px 0;
  border-radius:6px;
">
<b>Orquestación centralizada del pipeline.</b><br>
Todo el flujo de trabajo se controla desde un <b>único script Bash optimizado para SLURM</b>,
que actúa como interfaz entre el usuario y el clúster HPC, garantizando ejecución robusta,
reproducible y eficiente.
</div>
<br>
<details>

<summary>$\Large \color{#000080}{\textbf{⚙️ Responsabilidades clave del launcher}}$</summary>

- **Gestión eficiente de volúmenes**  
  Configuración dinámica de <i>bind paths</i> y directorios temporales sobre sistemas de archivos paralelos
  (p. ej. <b>BeeGFS</b>), minimizando cuellos de botella de I/O.

- **Aislamiento y reproducibilidad**  
  Ejecución controlada de contenedores <b>Apptainer</b>, asegurando versiones consistentes de herramientas
  críticas como STAR, HISAT2, StringTie y R-Bioconductor.

- **Limpieza automática**  
  Implementación de <i>exit traps</i> para la eliminación segura de archivos temporales,
  optimizando el uso de almacenamiento en infraestructuras compartidas.

</details>

<br>

<a id="dependencias-y-entorno-de-ejecución-contenedores"></a>

## 📦 $\color{#8B0000}{\text{4. Dependencias y Entorno de Ejecución (Contenedores)}}$

**📝 Nota: Inmutabilidad y Reproducibilidad**

Para garantizar que el análisis sea idéntico en cualquier clúster, **PLEXUS-seq** no depende de librerías locales. Todo se ejecuta mediante imágenes de contenedores **Apptainer** o **Singularity**.

<br>

> [!WARNING]
> **⚠️ Limitaciones Críticas y Estándares**
>
> Es obligatorio cumplir estos requisitos para evitar fallos:
>
> **1. Formato de Calidad (Estricto Phred+33)**
> * Calibrado solo para Illumina ≥1.8.
> * **Restricción:** Archivos antiguos con Phred+64 requieren conversión previa.
>
> **2. Estrategia de Trimming Inmutable**
> * Uso exclusivo de **Trimmomatic** por trazabilidad académica.
> * **Restricción:** No se permite sustituir por otros limpiadores (ej. fastp).

<br>

<details>
<summary>$\Large \color{#000080}{\textbf{🛠️ Herramientas de Procesamiento Upstream (Gold Standard)}}$</summary>
<br>

* **Control de Calidad:** `FastQC v0.12.1` y `MultiQC v1.29`
* **Limpieza y Trimming:** `Trimmomatic v0.39`
* **Alineamiento:** `STAR v2.7.10a` y `HISAT2 v2.2.1`
* **Cuantificación:** `Subread featureCounts v2.0.6` y `StringTie v2.2.3`

</details>

<details>
<summary>$\Large \color{#000080}{\textbf{🧬 Entorno Estadístico Downstream (R / Bioconductor)}}$</summary>
<br>

Los módulos de análisis diferencial y funcional se ejecutan dentro de un contenedor dedicado (`r_custom_env.sif`) con **R v4.3+**.

#### $\color{#2E8B57}{\text{🏗️ Núcleo Bioconductor e Infraestructura}}$
Gestiona las estructuras de datos genómicos y la paralelización.
* `BiocManager`, `BiocGenerics`, `BiocParallel`
* `S4Vectors`, `IRanges`, `GenomicRanges`
* `SummarizedExperiment`, `MatrixGenerics`
* `Rcpp`, `RcppArmadillo`, `locfit`

#### $\color{#2E8B57}{\text{⚙️ Motor Bioinformático y Estadístico}}$
Algoritmos para normalización, modelado y anotación.
* **Análisis Diferencial:** `DESeq2`, `limma`, `vsn`, `matrixStats`
* **Enriquecimiento:** `clusterProfiler`, `gprofiler2`, `pathview`
* **Genómica:** `biomaRt`, `AnnotationDbi`, `GenomicFeatures`, `Rsamtools`
* **Sistema:** `argparse` 🔌

#### $\color{#2E8B57}{\text{🛠️ Ingeniería de Datos (Tidyverse Utils)}}$
Manipulación eficiente de tablas y datos.
* `dplyr`, `tidyr`, `stringr`, `tibble`, `jsonlite`

#### $\color{#2E8B57}{\text{🌍 Organismos Soportados Nativamente}}$
Paquetes de anotación (`org.*.db`) para mapeo automático de IDs:

| Organismo | Paquete de Anotación (DB) |
| :--- | :--- |
| **Homo sapiens** (👤 Humano) | `org.Hs.eg.db` |
| **Mus musculus** (🐭 Ratón) | `org.Mm.eg.db` |
| **Rattus norvegicus** (🐀 Rata) | `org.Rn.eg.db` |
| **Danio rerio** (🐟 Pez Cebra) | `org.Dr.eg.db` |
| **Drosophila melanogaster** (🦗 Mosca) | `org.Dm.eg.db` |
| **Caenorhabditis elegans** (🐛 Gusano) | `org.Ce.eg.db` |
| **Saccharomyces cerevisiae** (🍺 Levadura) | `org.Sc.sgd.db` |
| **Arabidopsis thaliana** (🌱 Planta) | `org.At.tair.db` |
| **Gallus gallus** (🐔 Pollo) | `org.Gg.eg.db` |
| **Xenopus laevis** (🐸 Rana) | `org.Xl.eg.db` |

#### $\color{#2E8B57}{\text{📊 Suite de Visualización y Reportes}}$
Generación de gráficos de publicación y dashboards interactivos.
* **Gráficos Estáticos:** `ggplot2`, `ggrepel`, `pheatmap`, `enrichplot`, `RColorBrewer`
* **Composición:** `cowplot`, `patchwork`, `gridExtra`, `png`
* **Interactividad:** `plotly`
* **Reportes:** `rmarkdown`, `knitr`

</details>

<br>
<a id="centro-de-control-de-configuración-json"></a>

## ⚙️ $\color{#8B0000}{\text{5. Centro de Control de Configuración (📁 JSON/)}}$

OmniRNA-seq sigue un enfoque de **Arquitectura Basada en Contratos**. Los archivos JSON definen completamente el experimento, asegurando que la ejecución sea reproducible y auditable.

<br>

<details>
<summary>$\Large \color{#000080}{\text{1. Project Setup: Infraestructura y Metodología}}$</summary>
<br>

Define el esqueleto del flujo de trabajo:

* **`aligner`**: Selección del motor de alineamiento (`star`, `hisat2` o `both`). El modo `both` permite validación cruzada para identificar sesgos algorítmicos.
* **`counting_method`**: Define si el análisis parte de lecturas crudas (`featureCounts`) o de una matriz precalculada (`precomputed_csv`).
* **`quantification_options`**: Módulo de inteligencia para la normalización (StringTie):
    * `run_for`: Define qué métricas calcular (`tpm`, `fpkm`). Corrige el sesgo por longitud de gen y profundidad.
    * `run_exploratory_analysis`: Activa/desactiva el QC Estadístico (EDA) ideal para detectar posibles comportamientos outliers en muestras.
    * `explore_on`: Define sobre qué matriz normalizada se realizará el diagnóstico.

</details>

<details>
<summary>$\Large \color{#000080}{\text{2. Source Data: Estrategias de Ingesta}}$</summary>
<br>

* **`fastq_list_strategy`**:
    * **`automatic`**: Usa la **API de ENA** para descargar muestras indicadas en la URL generada por `data_conector.py`.
    * **`manual`**: (Obligatorio para modo local). El usuario provee una lista de URLs/rutas específicas en `fastq_list_file` para mayor flexibilidad.
* **`genome_urls`**: Descarga automática y construcción dinámica de genomas y anotaciones.

</details>

<details>
<summary>$\Large \color{#000080}{\text{3. Tool Parameters: Rendimiento y Rigor}}$</summary>
<br>

Define la estrategia computacional y los criterios de calidad.

**A. Paralelización Inteligente (Throttling)**
Para evitar el *I/O thrashing* en clústers compartidos, el pipeline procesa la ingesta en bloques concurrentes usando `threads`, `threads_per_sample` y `max_parallel_samples`. Maximiza el throughput sin violar cuotas.

**B. Gestión del Ciclo de Vida (Storage Lifecycle)**
Limpieza asíncrona a nivel de worker para optimizar espacio:

| Clave JSON | Valor | Descripción Técnica |
| :--- | :--- | :--- |
| `retain_only_fastqc_and_bam` | **True** | **Modo Ahorro Máximo:** Tras generar el BAM, purga FASTQs (crudos/trimmed), SAM y temporales (`_STARtmp`). Solo guarda reportes y BAM final. |
| `cleanup_only_fastq` | **True** | **Ahorro Intermedio:** Elimina únicamente los FASTQ crudos descomprimidos, manteniendo las lecturas limpias (trimmed) en disco. |
| *Zero-Noise Protection* | *(Auto)* | **Integridad:** Detecta y elimina archivos de 0 bytes de intentos fallidos previos, forzando una regeneración limpia. |

**C. Parámetros de Herramientas**
* **Trimmomatic:** Configuración de limpieza (`leading`, `trailing`, `slidingwindow`, `minlen`) y adaptadores (`adapter_fasta_url`).
* **STAR (`sjdbOverhang`):** Se calibra automáticamente (`ReadLength - 1`) para optimizar el mapeo en uniones de empalme (*splice junctions*).
* **FeatureCounts (`strand_specific`):** Topología de la librería (0: unstranded, 1: forward, 2: reverse).
* **Analysis Thresholds:** Define los cortes (`log2fc`, `padj`) para considerar un gen como Expresado Diferencialmente (DEG).

</details>

<details>
<summary>$\Large \color{#000080}{\text{4. DESeq2 Experiment: Diseño Experimental}}$</summary>
<br>

Conecta la matriz de expresión con las variables biológicas:

* **`metadata_path`**: Ruta al archivo `.csv` que vincula FASTQ con grupos biológicos.
* **`grouping_variable`**: Columna de interés (ej. `condition`).
* **`design_formula`**: Modelo estadístico (ej. `~ batch + condition`). Soporta diseños complejos e interacciones.
* **`control_group`**: Nivel de referencia (*baseline*). Todos los Fold Changes se calculan contra este grupo.

</details>

<details>
<summary>$\Large \color{#000080}{\text{5. Annotation: Contexto Biológico}}$</summary>
<br>

Gestiona la interoperabilidad entre bases de datos:

* **`organism_db`**: Paquete de Bioconductor para anotación (GO/KEGG).
* **`key_type`**: Formato de entrada de los IDs en el GTF (ej. `ENSEMBL`, `ENTREZID`).
* **`strip_gene_version` (true):** Pre-procesamiento vital para Ensembl. Elimina versiones de transcrito (ej. `FBgn00.1` → `FBgn00`) para asegurar un mapeo exacto.

</details>

<details>
<summary>$\Large \color{#000080}{\text{6. Container Images: Reproducibilidad Binaria}}$</summary>
<br>

Definición explícita de las rutas a imágenes **Singularity/Apptainer** (`.sif`). Esto congela las versiones de todo el software (STAR, R, Samtools), garantizando la inmutabilidad del entorno.

</details>

<details>
<summary>$\Large \color{#000080}{\text{7. Scripts: Orquestación de Motores (R)}}$</summary>
<br>

Mapa de rutas que desacopla el motor de ejecución de la lógica estadística:
* `r_exploratory_script_path` → **01_EDA_QC.R**
* `r_deseq2_script_path` → **02_Differential_expression.R**
* `r_enrichment_plotter_script_path` → **03_Functional_analysis_viz.R**
* `r_pdf_report_script_path` → **04_Comprehensive_Report_Builder.R**

</details>

<details>
<summary>$\Large \color{#000080}{\text{8. Functional Analysis: Inteligencia Biológica 🧠}}$</summary>
<br>

Capa de interpretación de alto nivel, diseñada para transformar las listas de genes en narrativas mecanísticas mediante algoritmos de enriquecimiento de última generación.

<br>

**🦁 $\color{#000080}{\text{A. Configuración de Especie}}$**
Definición de las bases de datos externas para la consulta en tiempo real.
* **`gprofiler_organism_code`**: Identificador semántico (ej. `hsapiens`) para consultas a la API de g:Profiler. Garantiza que las anotaciones (GO, Reactome) estén actualizadas al día de la ejecución.
* **`pathview_kegg_code`**: Código de tres letras (ej. `hsa`) compatible con KEGG para el mapeo visual de rutas metabólicas.

<br>

**🧬 $\color{#000080}{\text{B. Dualidad Analítica (SEA vs. GSEA)}}$**
* **`run_sea_analysis` (ORA)**: Ejecuta el Análisis de Sobre-representación. Compara tu lista de genes significativos contra el "background" genómico (Test Hipergeométrico). Ideal para procesos discretos ("encendido/apagado").
    * **`sea_ontologies`**: Segmenta el análisis en las tres ramas de Gene Ontology: `BP` (Procesos), `MF` (Función Molecular) y `CC` (Componente Celular).
* **`run_gsea_analysis`**: Activa el Gene Set Enrichment Analysis. Analiza el **transcriptoma completo rankeado** por su Fold Change (sin cortes de significancia). Detecta cambios sutiles pero coordinados en rutas completas que el análisis estándar ignoraría.

<br>

**📉 $\color{#000080}{\text{C. Rigor Estadístico}}$**
Control estricto de falsos positivos.
* **`kegg_padj_threshold` / `sea_padj_cutoff`**: Filtro de significancia tras la corrección por múltiples test (FDR Benjamini-Hochberg), asegurando bases estadísticas sólidas.
* **`sea_qvalue_cutoff`**: Control adicional de la tasa de error, vital en estudios con alta densidad de datos.

<br>

**📊 $\color{#000080}{\text{D. Visualización Avanzada y Reportes}}$**
El pipeline (`run_enrichment_plots`) genera automáticamente una suite gráfica controlada por los parámetros `top_n`:

* **`top_n_emap`**: Genera *Enrichment Maps* para visualizar la redundancia y conectividad entre términos GO (agrupamiento por similitud).
* **`top_n_cnet`**: Crea *Gene-Concept Networks*, vinculando visualmente los genes significativos con las rutas biológicas a las que pertenecen.
* **`top_n_ridge`**: Produce *Ridgeplots* (gráficos de crestas) para mostrar la distribución de frecuencia del cambio (NES) en las rutas principales.
* **`top_n_gseaplot`**: Genera los perfiles de enriquecimiento clásicos (running score) para las rutas con mayor impacto biológico.
* **`Pathview`**: Proyecta los datos de expresión sobre mapas oficiales de **KEGG**, renderizando archivos donde cada enzima se colorea según su regulación (🔴 UP / 🟢 DOWN).

**📄 Reporte Final (`run_final_pdf_reports`)**: Ejecuta g:Profiler (multifuente GO/KEGG/REAC) y compila el `Informe_Transcriptomica_Completo.pdf` (TOC, Volcano Plots y tablas paginadas).

</details>

<br>

<a id="requisitos-de-metadatos-metadata_archivos"></a>

## 📄 $\color{#8B0000}{\text{6. Requisitos de Metadatos (MetadataArchivos/)}}$

Para que el motor estadístico **DESeq2** interprete correctamente el diseño experimental, se requiere un archivo `metadata.csv` estándar correspondiente al análisis, ubicado en la carpeta **Metadata_Archivos/** (y referenciado en el JSON).

Este archivo actúa como la **llave maestra** 🗝️ que conecta los archivos crudos con las variables biológicas.

<br>

### $\color{#000080}{\text{📋 Reglas de Formato}}$

* **1. Primera Columna:** Debe contener los **IDs de las muestras** (coincidentes con los nombres de los archivos FASTQ/BAM).
* **2. Columnas de Factores:** Variables biológicas de interés (ej. *Genotipo*, *Tratamiento*, *Tiempo*).
* **3. Consistencia:** Los nombres de las columnas deben coincidir **exactamente** con los términos usados en la `design_formula` del archivo JSON.

<br>

> [!Nota]
> **🛠️ Nota Técnica: Sanitización Automática**
>
> El pipeline incluye un módulo de seguridad que genera un archivo `metadata_corregido.csv`. Este proceso detecta y corrige caracteres inválidos en los nombres de las muestras (ej. reemplaza guiones `-` por puntos `.`) para asegurar la compatibilidad total con **R**.
> 

<br>
<a id="arquitectura-del-sistema"></a>

## 🏗️ $\color{#8B0000}{\text{7. Arquitectura del Sistema}}$

<br>

<details>
<summary>$\Large \color{#000080}{\text{1. Ingeniería de Datos y Orquestación (Python 3.10+)}}$</summary>
<br>

La capa de ingeniería actúa como el **sistema nervioso** del pipeline. Diseñada bajo el principio de *Responsabilidad Única*, gestiona la logística de datos antes de cualquier análisis estadístico.

* **`main.py` (El Director):** Procesa el archivo JSON, valida las rutas del sistema y decide la estrategia de ejecución global, delegando tareas a los submódulos.
* **`experiment_profiler.py` (Inteligencia):** Se conecta automáticamente a las APIs públicas de **ENA** y **Ensembl** para recuperar metadatos y construir dinámicamente las URLs de referencia.
* **`data_conector.py` (Logística):** Gestiona la descarga paralela y robusta de archivos FASTQ, con lógica de reintentos y validación de integridad.
* **`01_pipeline_core.py` (El Motor):** Orquesta la ejecución secuencial de herramientas críticas (Trimmomatic, STAR, HISAT2, StringTie).
    * *Feature Destacada:* **Validación Cruzada**. Si se selecciona el modo `"both"`, ejecuta ambos alineadores y genera archivos de intersección para evaluar la consistencia técnica entre algoritmos.

</details>

<details>
<summary>$\Large \color{#000080}{\text{2. Suite Estadística y Biológica (R / Bioconductor)}}$</summary>
<br>

Esta capa transforma los datos crudos en conocimiento biológico mediante cuatro módulos especializados.

#### $\color{#000080}{\text{A. Control de Calidad y Exploración}}$
***01_EDA_QC.R*** Establece la línea base de calidad aplicando transformación `log2(x+1)` y ejecutando una **auditoría adaptativa**:

1.  **PCA Multidimensional Secuencial:** No se limita al plano principal. Analiza proyecciones iterativas (PC1 vs PC2... hasta PC4 vs PC5) para detectar *batch effects* ocultos.
2.  **Clustering Jerárquico Especificado:** Usa distancias Euclidianas y aglomeración por *Complete Linkage* para maximizar la disimilitud.
3.  **Algoritmo Heurístico de Auditoría:** Genera un diagnóstico automático (semáforo) adaptando sus matemáticas al tamaño del grupo ($N$):
    * **Enfoque Clásico ($N < 5$):** Usa Media y SD. (Alerta > 1.5 SD | Fallo > 2.0 SD).
    * **Enfoque Robusto ($N \ge 5$):** Usa Mediana y MAD. (Alerta > 2.5 MAD | Fallo > 3.0 MAD).

#### $\color{#000080}{\text{B. Expresión Diferencial}}$
***02_Differential_expression.R*** Implementa Modelos Lineales Generalizados (**GLM**) mediante **DESeq2** con corrección Benjamini-Hochberg (FDR).
* **Auditoría Previa:** Histogramas y boxplots para detectar outliers técnicos antes del modelado.
* **Visualización:** Genera **Volcano Plots Interactivos** (HTML) para exploración *point-and-click*.
* **Genes Huérfanos:** Módulo de descubrimiento para identificar genes estadísticamente vitales sin ruta funcional conocida.

#### $\color{#000080}{\text{C. Inteligencia Funcional}}$
***03_Functional_analysis_viz.R*** Utiliza el motor de **clusterProfiler** para crear una narrativa visual integral.
* **Dualidad Analítica:** Ejecuta en paralelo **SEA** (Sobre-representación) y **GSEA** (Enriquecimiento de Sets) sobre el transcriptoma completo.
* **Pathview:** Mapea la expresión diferencial sobre diagramas oficiales de **KEGG**, coloreando nodos (🔴 UP / 🟢 DOWN) para visualizar el flujo metabólico.
* **Dashboard Interactivo:** Compila todos los hallazgos en un HTML unificado.
* **Genes Conectores:** Algoritmo exclusivo que identifica genes puente entre diferentes procesos biológicos.

#### $\color{#000080}{\text{D. Reporte Final}}$
***04_Comprehensive_Report_Builder.R*** Actúa como el editor final.
* **g:Profiler en tiempo real:** Consultas multifuente para garantizar anotaciones actualizadas.
* **Renderizado de Doble Pase:** Pre-escanea los datos para calcular una paginación perfecta antes de generar el PDF.
* **Fusión de Ontologías:** Integra GO (BP, MF, CC), KEGG y Reactome en una narrativa lineal jerarquizada por significancia ($p < 10^{-16}$).

</details>
<br>

<a id="estructura-global-de-resultados-output-tree"></a>

## 📂 $\color{#8B0000}{\text{8. Estructura Global de Resultados (Output Tree)}}$

Una vez finalizado el pipeline, los resultados se organizan automáticamente en la siguiente jerarquía de carpetas.

```text
<PROJECT_DIR>/
├── <PROJECT_ID>_fastq_urls.txt                  # [Gen: data_conector.py]
├── Info_<PROJECT_ID>/                           # [Gen: experiment_profiler.py] (No en local)
│   ├── info_experiment_<ID>.txt                 # (Metadatos del diseño experimental)
│   └── list_of_samples_<ID>.txt                 # (Tabla GSM | SRR | Título)
│
├── adapters/                                    # [Gen: 01_pipeline_core.py]
│   └── TruSeq_adapters.fa
│
├── REFERENCE_GENOMES_FILES/                     # [Gen: 01_pipeline_core.py]
│   ├── <Organism>.dna.toplevel.fa               # (Descargado de Ensembl)
│   ├── <Organism>.<Version>.gtf                 # (Anotación)
│   └── [Indices de STAR / HISAT2]               # (Generados por los alineadores)
│
├── FASTQ_FILES/                                 # [Gen: 01_pipeline_core.py]
│   └── <SAMPLE>_1.fastq.gz                      # (Descarga raw)
│
├── FASTQC/                                      # [Gen: 01_pipeline_core.py]
│   └── <SAMPLE>_fastqc.html                     # (Reporte calidad cruda)
│
├── TRIMMED_READS/                               # [Gen: 01_pipeline_core.py]
│   └── <SAMPLE>.trimmed.fastq.gz                # (Lecturas limpias tras Trimmomatic)
│
├── ALIGNMENTS_<STAR|HISAT2>/                    # [Gen: 01_pipeline_core.py]
│   └── <SAMPLE>_Aligned.sortedByCoord.out.bam   # (Archivo BAM final)
│
├── STRINGTIE_<STAR|HISAT2>/                     # [Gen: 01_pipeline_core.py]
│   └── <SAMPLE>/gene_abundances.tsv             # (Cálculo intermedio TPM/FPKM)
│
├── COUNTS/                                      # [Gen: 01_pipeline_core.py]
│   ├── counts_<ALIGNER>.txt                     # (Matriz conteos crudos - featureCounts)
│   ├── counts_STAR.txt / counts_HISAT2.txt      # (Matrices duales si se activa modo "both")
│   ├── <ALIGNER>_TPM_matrix.tsv                 # (Matriz normalizada TPM - StringTie)
│   └── <ALIGNER>_FPKM_matrix.tsv                # (Matriz normalizada FPKM - StringTie)
│
├── EDA_RESULTS_<ALIGNER>_<TYPE>/                # [Gen: 01_EDA_QC.R]
│   ├── 1_Distribution_Check.pdf
│   ├── 2_Variance_Structure.pdf
│   ├── 3_PCA_Analysis.pdf
│   ├── 4_Dendrogram.pdf
│   ├── 5_Sample_Correlation.pdf
│   ├── 6_Top_Variable_Genes.pdf
│   └── 7_QC_Report_Automated.txt                # (Informe de QC con sospechas de outliers)
│
├── DESEQ2_RESULTS_<ALIGNER>/                    # [Gen: Scripts R 02, 03 y 04]
│   ├── metadata_corregido.csv                   # [01_pipeline_core -> pasa a R]
│   │
│   │   # --- Salidas de 02_Differential_expression.R ---
│   ├── QC_estadisticas_conteos_crudos_*.txt
│   ├── Resultados_Completos_<CONTRASTE>.txt     # (Tabla maestra con stats)
│   ├── Resultados_Significativos_<CONTRASTE>.txt
│   ├── genes_huerfanos_<CONTRASTE>.txt          # (Genes significativos sin GO/KEGG)
│   ├── VolcanoPlot_Dashboard_<CONTRASTE>.html   # (Interactivo Plotly)
│   ├── Analisis_Rutas_Enriquecidas_*.txt        # (Input para scripts visuales)
│   │
│   │   # --- Salidas de 03_Functional_analysis_viz.R ---
│   ├── Informe_Interactivo_<CONTRASTE>.html     # (Dashboard global funcional)
│   ├── Informe_Completo_Ontogenia_*.txt         # (Resumen texto plano)
│   ├── sea_analysis_plots/                      # (Plots ORA/SEA: Dotplots, Cnetplots)
│   ├── gsea_analysis_plots/                     # (Plots GSEA: Ridgeplots, GSEA curves)
│   ├── pathview_plots/                          # (Mapas de rutas KEGG coloreados .png/.pdf)
│   │
│   │   # --- Salida de 04_Comprehensive_Report_Builder.R ---
│   └── Informe_Transcriptomica_Completo_*.pdf   # (Reporte Final Paginado)
│
├── MULTIQC_<ALIGNER>_REPORT/                    # [Gen: 01_pipeline_core.py]
│   └── multiqc_report.html                      # (Auditoría de calidad unificada)
│
└── WORKFLOW_COMPARISON/                         # [Gen: 01_pipeline_core.py - Solo modo "both"]
    └── resumen_comparacion_genes.txt            # (Estadísticas de intersección STAR vs HISAT2)
```
<br>
<details>
<summary>$\Large \color{#000080}{\textbf{🔄 Descripción del Flujo de Datos}}$</summary>
<br>
El pipeline comienza con la fase de ingeniería de datos orquestada por Python usando `main.py` y ejecutado por `RNA_SEQ_LETS_TRY.sh`.

Los scripts `experiment_profiler.py` y `data_conector.py` generan la carpeta **Info_<PRJ>** con los metadatos y la lista de descargas. A continuación, el motor principal `01_pipeline_core.py` se encarga del trabajo pesado: descarga y descomprime las referencias (**REFERENCE_GENOMES**) y los datos crudos (**FASTQ_FILES**), ejecuta el control de calidad y limpieza (**FASTQC**, **TRIMMED_READS**), realiza el alineamiento (**ALIGNMENTS_<STAR/HISAT2>**) y la cuantificación (**STRINGTIE**, **COUNTS**), produciendo las matrices de conteo `.txt` y `.tsv` que servirán de entrada para la estadística.

En ejecuciones con validación cruzada (**modo both**), el pipeline genera sets de resultados independientes para cada alineador, permitiendo al investigador elegir el motor con mayor tasa de mapeo.

Una vez generadas las matrices, entran en acción los módulos de R:

* **`01_EDA_QC.R`**: Toma la matriz de conteos y genera la carpeta **EDA_RESULTS**, que contiene diagnósticos visuales (PCA, Heatmaps) y el reporte de outliers.
* **`02_Differential_expression.R`**: Crea la carpeta principal **DESEQ2_RESULTS**, donde deposita las tablas de expresión diferencial, los genes huérfanos y el Volcano Plot interactivo.
* **`03_Functional_analysis_viz.R`**: Sobre esa misma carpeta, añade las subcarpetas de visualización (sea/gsea/pathview_plots) y el dashboard HTML funcional.
* **`04_Comprehensive_Report_Builder.R`**: Finalmente, recopila toda esta información para compilar el **Informe_Transcriptomica_Completo.pdf** usando gProfiler.

Finalmente Python vuelve a intervenir para generar el reporte de **MULTIQC**, que unifica las métricas de calidad de todas las herramientas (FastQC, Trimmomatic, STAR, HISAT2 y featureCounts), permitiendo al investigador validar la robustez técnica de la ejecución y justificar estadísticamente cualquier decisión de exclusión de muestras antes de la interpretación biológica.

</details>

<br>

<a id="autoría-impacto-y-colaboración"></a>


## 🤝 $\color{#8B0000}{\text{9. Autoría, Impacto y Colaboración}}$
OmniRNA-seq nace con la filosofía del **código abierto (licencia MIT)** para eliminar barreras en la ciencia. Sin embargo, su arquitectura robusta es el resultado de cientos de horas de ingeniería y la dedicación exclusiva de un **Investigador Predoctoral (FPU)**.

<br>

<details>
<summary>$\Large \color{#000080}{\textbf{🏫 Colaboraciones Locales, Contacto e Impacto}}$</summary>
<br>

Para análisis de datos privados (FASTQs o matrices de conteos), ofrezco soporte directo. Facilita tus archivos + `metadata.csv` y recibirás tus resultados procesados.

* 🆔 **ORCID:** [0000-0003-0207-9026](https://orcid.org/0000-0003-0207-9026)
* 📧 **Contacto:** sergio120897@gmail.com

<br>

### 🌟 Impacto: Tu Cita es el Motor

> **Tu reconocimiento es el verdadero motor de este proyecto.**
>
> Si este pipeline agiliza tu investigación, una **cita en tu paper** es la mejor forma de validarlo y apoyar mi carrera académica.

</details>

<br>

### $\color{#000080}{\text{🧬 Soporte Experto Co-autoría}}$

La ciencia es mejor cuando se comparte. Si necesitas una integración profunda, auditoría de datos o soporte bioinformático experto para elevar el impacto de tu estudio, estoy totalmente abierto a la **colaboración y co-autoría**.

¡Transformemos juntos esos datos crudos en descubrimientos biológicos!

---

<div align="center">

### 👨‍💻 **Sergio García Díaz**
**Lead Developer FPU Fellow**

</div>
