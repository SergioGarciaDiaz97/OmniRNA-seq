# 🧬 OmniRNA-seq: High-Performance HPC Transcriptomics Pipeline

OmniRNA-seq es un ecosistema bioinformático integral para el análisis automatizado y reproducible de datos de RNA‑seq *bulk* en entornos HPC. Transforma lecturas crudas de secuenciación en resultados biológicos interpretables y listos para publicación, desacoplando la **ingeniería de datos** (Python) del **modelado estadístico avanzado** (R/Bioconductor) y del **despliegue reproducible** basado en contenedores **Apptainer/Singularity**.

El sistema es agnóstico al organismo, con soporte nativo y flujos de anotación validados para:
**Homo sapiens**, **Mus musculus**, **Saccharomyces cerevisiae**, **Arabidopsis thaliana**, **Danio rerio**, **C. elegans** y **Drosophila melanogaster**.

---

## 📚 Índice
1. [Organización del Proyecto](#-1-organización-del-proyecto-separation-of-concerns)  
2. [Modos de Ejecución](#-2-modos-de-ejecución-orquestación-inteligente)  
3. [Launcher Maestro](#-3-punto-de-entrada-launcher-maestro-rna_seq_lets_trysh)  
4. [Dependencias y Contenedores](#-4-dependencias-y-entorno-de-ejecución-contenedores)  
5. [Centro de Configuración JSON](#-5-centro-de-control-de-configuración-json)  
6. [Requisitos de Metadatos](#-6-requisitos-de-metadatos-metadata_archivos)  
7. [Arquitectura del Sistema](#-7-arquitectura-del-sistema)  
8. [Estructura Global de Resultados](#-8-estructura-global-de-resultados-output-tree)  
9. [Autoría y Colaboraciones](#-9-autoría-impacto-y-colaboración)

---

## 📂 1. Organización del Proyecto (Separation of Concerns)

```text
OmniRNA-seq/
├── RNA_SEQ_LETS_TRY.sh        # Launcher maestro (HPC / SLURM)
├── JSON/                      # Configuración del experimento (El Contrato)
│   ├── project01.json
│   └── project02.json
│   └── ...
│ 
├── Metadata_Archivos/         # Archivos CSV de diseño experimental
│   ├── metadata_project01.csv
│   └── metadata_project02.csv
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
`Launcher → Python (data engineering) → R (estadística/biológica) → PDFs publicables`

---

## 🚀 2. Modos de Ejecución (Orquestación Inteligente)
<br>
El pipeline implementa una lógica de decisión automatizada para determinar el flujo de trabajo óptimo. Esta decisión se basa en la fuente de los datos (públicos vs. locales) y el formato de entrada (crudos vs. matriz), definido en el archivo de configuración JSON. Existen los parámetros (ver apartado [5. Centro de configuración JSON](#v-⚙️-5-centro-de-control-de-configuración-json)) **cleanup_only_fastq** y **retain_only_fastqc_and_bam** para ahorrar espacio de almacenamiento en la memoria.
<br>
$\Large \color{#8B0000}{\textbf{2.1. 🌍 Modo Explorer (Recuperación Automatizada de Repositorios)}}$  
<br>
**Caso de uso:** Meta-análisis y benchmarking utilizando datos públicos (GEO, ENA, SRA). **Activación:** Se ejecuta suministrando un **Project_ID** (ej. PRJNA, SRP) como argumento.
<br>
* **$\color{#8B0000}{\text{Flujo Completo (End-to-End Processing):}}$**
    * **Configuración:** `"counting_method": "featurecounts"`.
    * **Descripción:** El sistema interroga las APIs de ENA/SRA para recuperar automáticamente los metadatos del diseño experimental y los archivos FASTQ crudos. Ejecuta el pipeline completo: control de calidad, alineamiento y cuantificación.
<br>
**$\color{#8B0000}{\text{Flujo Acelerado (Direct Matrix Analysis - Public):}}$**
    * **Configuración:** `"counting_method": "precomputed_csv" + URL remota`.
    * **Descripción:** Descarga la matriz de conteos procesada directamente desde el repositorio del autor. Omite el alineamiento para saltar inmediatamente al análisis estadístico y funcional.
<br>
**Sintaxis (Bash):**
```text
sbatch RNA_SEQ_LETS_TRY.sh JSON/config.json PRJNAxxxx
```

$\huge \color{#8B0000}{\text{2.2. 💻 Modo Local (Infraestructura Privada / On-Premise)}}$

**Caso de uso:** Análisis de datos propios del laboratorio o colaboraciones privadas, sin conexión a APIs externas. 

**Activación:** Se ejecuta sin argumento de Project_ID. Como tutorial para el modo local hemos replicado este método partiendo de muestras fastq descargadas (ver sección en este GitHub en carpeta Modo local).

Procesamiento de Crudos (Raw Data Workflow):

Configuración: "fastq_list_strategy": "manual" + Manifiesto de archivos.

Descripción: Procesa archivos FASTQ alojados en el sistema de ficheros local. Utiliza un manifiesto de rutas (URI file://) para ingerir las muestras y ejecutar el alineamiento y conteo.

Flujo Acelerado Local (Direct Matrix Analysis - Local):

Configuración: "counting_method": "precomputed_csv" + Ruta local al archivo.

Descripción: Ingesta directa de una matriz de conteos (.csv) suministrada externamente o pre-calculada. Realiza un bypass de la etapa de computación intensiva para ejecutar exclusivamente los módulos de estadística (DESeq2), enriquecimiento y generación de reportes.

Sintaxis (Bash):
```text
sbatch RNA_SEQ_LETS_TRY.sh JSON/config.json
```
🛡️ Resiliencia Automática: Gracias a su arquitectura modular, OmniRNA-seq es capaz de retomar ejecuciones interrumpidas. Si un job es cancelado por el clúster por exceder el tiempo de pared (walltime), basta con re-lanzar el comando original; el sistema detectará los pasos completados y los archivos válidos, saltando directamente a la etapa pendiente.
