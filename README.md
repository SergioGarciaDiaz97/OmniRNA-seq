	📂 1. Organización del Proyecto (Separation of Concerns)

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

Flujo lógico: Launcher → Python (data engineering) → R (estadística/biológica) → PDFs publicables
