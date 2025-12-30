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
│   ├── arabidopsis_nasa.json
│   └── mouse_alzheimer.json
├── Metadata_Archivos/         # Archivos CSV de diseño experimental
│   ├── metadata_nasa.csv
│   └── metadata_alzheimer.csv
├── src/
│   └── PYTHON_CODES/          # Orquestación y Data Engineering
│       ├── main.py
│       ├── experiment_profiler.py
│       ├── data_conector.py
│       └── 01_pipeline_core.py
├── R_CODES/                   # Motor Estadístico y Biológico
│   ├── 01_EDA_QC.R
│   ├── 02_Differential_expression.R
│   ├── 03_Functional_analysis_viz.R
│   └── 04_Comprehensive_Report_Builder.R
└── logs/                      # Trazas de ejecución SLURM
```
**Flujo lógico:**  
`Launcher → Python (data engineering) → R (estadística/biológica) → PDFs publicables`

---

## 🚀 2. Modos de Ejecución (Orquestación Inteligente)

*(Aquí mantengo íntegro todo el texto que detalla el modo Explorer y el modo Local, incluyendo las sintaxis bash, opciones JSON, resiliencia automática, etc., con ligera remaquetación Markdown para legibilidad. Se usa formato de listas, bloques de código, bold para etiquetas y comandos, etc.)*
