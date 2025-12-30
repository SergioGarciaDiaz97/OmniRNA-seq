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

El pipeline implementa una lógica de decisión automatizada para determinar el flujo de trabajo óptimo. Esta decisión se basa en la fuente de los datos (**públicos vs. locales**) y el formato de entrada (**crudos vs. matriz**).

Existen los parámetros `cleanup_only_fastq` y `retain_only_fastqc_and_bam` (ver apartado [5. Configuración JSON](#-5-centro-de-control-de-configuración-json)) para ahorrar espacio de almacenamiento.

<details>
<summary>$\Large \color{#8B0000}{\textbf{2.1. 🌍 Modo Explorer (Recuperación Automatizada)}}$</summary>
<br>

<div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; margin: 10px 0; border-radius: 4px;">
<span style="font-size: 1.2em;">💡</span> 
<span style="font-weight: bold; color: #856404;"><b>Ideal para: </b></span> Meta-análisis y benchmarking utilizando datos de <b>GEO, ENA o SRA</b>.<br>
<span style="font-weight: bold; color: #856404;">Activación:</span> Requiere suministrar un <b>Project_ID</b> (ej. PRJNA, SRP) como argumento.
</div>

### $\color{#8B0000}{\text{Flujo Completo (End-to-End Processing):}}$
- **Configuración:** `"counting_method": "featurecounts"`.
- **Descripción:** Interroga las APIs de ENA/SRA para recuperar automáticamente metadatos y FASTQs. Ejecuta el pipeline integral: QC, alineamiento y cuantificación.

### $\color{#8B0000}{\text{Flujo Acelerado (Direct Matrix Analysis - Public):}}$
- **Configuración:** `"counting_method": "precomputed_csv" + URL remota`.
- **Descripción:** Descarga la matriz de conteos directamente del autor, omitiendo el alineamiento para saltar al análisis estadístico y funcional.

**Sintaxis (Bash):**
```bash
sbatch RNA_SEQ_LETS_TRY.sh JSON/config.json PRJNAxxxx
```
</details> 

<details>
<summary>$\Large \color{#8B0000}{\textbf{2.2. 💻 Modo Local (Infraestructura Privada / On-Premise)}}$</summary>
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

---

> [!IMPORTANT] **🛡️ Resiliencia Automática & Fault Tolerance**  
> Gracias a su arquitectura modular, OmniRNA-seq es capaz de retomar ejecuciones interrumpidas. Si un job es cancelado por el clúster (ej. Walltime Limit), basta con re-lanzar el comando original; el sistema detectará los pasos completados y saltará directamente a la etapa pendiente.
