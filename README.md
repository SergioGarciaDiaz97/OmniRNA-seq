# 🧬 OmniRNA-seq: High-Performance HPC Transcriptomics Pipeline

OmniRNA-seq es un ecosistema bioinformático integral para el análisis automatizado y reproducible de datos de RNA‑seq *bulk* en entornos HPC. Transforma lecturas crudas de secuenciación en resultados biológicos interpretables y listos para publicación, desacoplando la **ingeniería de datos** (Python) del **modelado estadístico avanzado** (R/Bioconductor) y del **despliegue reproducible** basado en contenedores **Apptainer/Singularity**.

El sistema es agnóstico al organismo, con soporte nativo y flujos de anotación validados para:
**Homo sapiens**, **Mus musculus**, **Saccharomyces cerevisiae**, **Arabidopsis thaliana**, **Danio rerio**, **C. elegans** y **Drosophila melanogaster**.

---

## 📚 Índice
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
<span style="font-weight: bold; color: #856404;"><b>Ideal para: </b></span> Meta-análisis y benchmarking utilizando datos de <b>GEO, ENA o SRA</b>.<br>
<span style="font-weight: bold; color: #856404;">Activación:</span> Requiere suministrar un <b>Project_ID</b> (ej. PRJNA, SRP) como argumento.
</div>

### $\color{#2E8B57}{\text{Flujo Completo (End-to-End Processing):}}$
- **Configuración:** `"counting_method": "featurecounts"`.
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

<br><br>

<a id="dependencias"></a>
<h2 style="color:#8B0000;">
  📦 4. Dependencias y Entorno de Ejecución (Contenedores)
</h2>

<div style="
  background-color:#fdf6e3;
  border-left:5px solid #f39c12;
  padding:14px;
  margin:12px 0;
  border-radius:6px;
">
  <strong>📝 Nota: Inmutabilidad y Reproducibilidad</strong><br>
  Para garantizar que el análisis sea idéntico en cualquier clúster, 
  <strong>OmniRNA-seq</strong> no depende de librerías locales. 
  Todo se ejecuta mediante imágenes de contenedores <strong>Apptainer</strong> o <strong>Singularity</strong>.
</div>

<div style="
  background-color:#fdecea;
  border-left:5px solid #e74c3c;
  padding:14px;
  margin:12px 0;
  border-radius:6px;
">
  <strong>⚠️ Limitaciones Críticas y Estándares</strong><br><br>
  <strong>1. Formato de Calidad (Estricto Phred+33)</strong><br>
  Calibrado solo para Illumina ≥1.8.<br>
  <span style="color:#c0392b;"><em>Restricción:</em> Archivos antiguos con Phred+64 requieren conversión previa.</span><br><br>

  <strong>2. Estrategia de Trimming Inmutable</strong><br>
  Uso exclusivo de <strong>Trimmomatic</strong> por trazabilidad clínica.<br>
  <span style="color:#c0392b;"><em>Restricción:</em> No se permite sustituir por otros limpiadores (ej. fastp) en la configuración estándar.</span>
</div>

<details>
<summary style="font-size:1.1em; font-weight:bold; color:#000080;">🛠️ Herramientas de Procesamiento Upstream (Gold Standard)</summary>

<br>
<ul>
  <li><strong>Control de Calidad:</strong> FastQC v0.12.1 y MultiQC v1.29</li>
  <li><strong>Limpieza y Trimming:</strong> Trimmomatic v0.39</li>
  <li><strong>Alineamiento:</strong> STAR v2.7.10a y HISAT2 v2.2.1</li>
  <li><strong>Cuantificación:</strong> Subread featureCounts v2.0.6 y StringTie v2.2.3</li>
</ul>
</details>

<details>
<summary style="font-size:1.1em; font-weight:bold; color:#000080;">🧬 Entorno Estadístico Downstream (R/Bioconductor)</summary>

<br>
<p>Los módulos de análisis diferencial y funcional se ejecutan dentro de un contenedor (`r_custom_env.sif`) con R v4.3+.</p>

<h4>🏗️ Núcleo Bioconductor</h4>
<ul>
  <li>BiocManager v1.30.23, BiocGenerics v0.48.1</li>
  <li>S4Vectors v0.40.2, IRanges v2.36.0, GenomicRanges v1.54.1</li>
  <li>SummarizedExperiment v1.32.0, BiocParallel v1.36.0</li>
</ul>

<h4>⚙️ Motor Bioinformático</h4>
<ul>
  <li>DESeq2 v1.42.1</li>
  <li>clusterProfiler v4.10.1</li>
  <li>gprofiler2 v0.2.3</li>
  <li>pathview v1.42.0</li>
  <li>biomaRt v2.58.2</li>
  <li>argparse v2.2.3 🔌</li>
</ul>

<h4>🌍 Organismos Soportados Nativamente</h4>
<ul>
  <li>Arabidopsis thaliana (🌱)</li>
  <li>Homo sapiens (👤)</li>
  <li>Mus musculus (🐭)</li>
  <li>Rattus norvegicus (🐀)</li>
  <li>Danio rerio (🐟)</li>
  <li>Drosophila melanogaster (🪰 → reemplazar por 🐝 si no carga)</li>
  <li>Caenorhabditis elegans (🪱 → reemplazar por 🐛 si no carga)</li>
  <li>Saccharomyces cerevisiae (🍺)</li>
</ul>

<h4>📊 Suite de Visualización & Reportes</h4>
<ul>
  <li>ggplot2 v3.5.0, ggrepel v0.9.5, pheatmap v1.0.12</li>
  <li>rmarkdown v2.26 & knitr v1.46</li>
</ul>

</details>

