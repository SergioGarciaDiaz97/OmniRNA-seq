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

---

## 🚀 2. Modos de Ejecución (Orquestación Inteligente)

El pipeline implementa una lógica de decisión automatizada para determinar el flujo de trabajo óptimo basándose en la fuente de datos (públicos vs. locales) y el formato de entrada (crudos vs. matriz). Para optimizar el almacenamiento, el sistema incluye los parámetros `cleanup_only_fastq` y `retain_only_fastqc_and_bam` (ver [5. Configuración JSON](#v-⚙️-5-centro-de-control-de-configuración-json)).
<br>
$\Large \color{#8B0000}{\textbf{2.1. 🌍 Modo Explorer (Recuperación Automatizada)}}$
<br>
> [!NOTE]
> **Ideal para:** para utilizar datos de **GEO, ENA o SRA**.
> **Activación:** Requiere un **Project_ID** (ej. PRJNA, SRP) como argumento.

* **$\color{#8B0000}{\text{Flujo Completo (End-to-End Processing):}}$**
    * **Configuración:** `"counting_method": "featurecounts"`.
    * **Descripción:** Interroga las APIs de ENA/SRA para recuperar automáticamente metadatos y FASTQs. Ejecuta el pipeline integral: QC, alineamiento y cuantificación.

* **$\color{#8B0000}{\text{Flujo Acelerado (Direct Matrix Analysis - Public):}}$**
    * **Configuración:** `"counting_method": "precomputed_csv" + URL remota`.
    * **Descripción:** Descarga la matriz de conteos directamente del autor, omitiendo el alineamiento para saltar al análisis estadístico y funcional.

**Sintaxis (Bash):**
```text
sbatch RNA_SEQ_LETS_TRY.sh JSON/config.json PRJNAxxxx
```
<br>

---

$\Large \color{#8B0000}{\textbf{2.2. 💻 Modo Local (Infraestructura Privada / On-Premise)}}$

> [!TIP]
> **Ideal para:** Análisis de datos propios o colaboraciones privadas sin conexión externa.
> **Activación:** Se ejecuta **sin argumento** de `Project_ID`. 
> *(Tutorial disponible en la carpeta `Modo local` de este repositorio).*

<br>

* **$\color{#8B0000}{\text{Procesamiento de Crudos (Raw Data Workflow):}}$**
    * **Configuración:** `"fastq_list_strategy": "manual" + Manifiesto`.
    * **Descripción:** Ingesta vía rutas locales (**URI file://**) para ejecutar alineamiento y conteo.

* **$\color{#8B0000}{\text{Flujo Acelerado (Direct Matrix Analysis):}}$**
    * **Configuración:** `"counting_method": "precomputed_csv"`.
    * **Descripción:** **Bypass** de computación intensiva para ejecutar directamente DESeq2 y reportes.

**Sintaxis (Bash):**
```text
sbatch RNA_SEQ_LETS_TRY.sh JSON/config.json
```
🛡️ Resiliencia Automática: Gracias a su arquitectura modular, OmniRNA-seq es capaz de retomar ejecuciones interrumpidas. Si un job es cancelado por el clúster por exceder el tiempo de pared (walltime), basta con re-lanzar el comando original; el sistema detectará los pasos completados y los archivos válidos, saltando directamente a la etapa pendiente.
