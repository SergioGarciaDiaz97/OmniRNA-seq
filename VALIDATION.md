## 💻 $\color{#8B0000}{\text{A. Modo Local (Simulación High-Performance)}}$

<div style="background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 8px; padding: 20px; margin-bottom: 20px;">

### 🔬 Caso de Estudio 1: Silenciamiento de la Helicasa DDX21 en Células Endoteliales
**Validación Técnica Definitiva (End-to-End)**

* **🆔 Identificador del Estudio:** GSE179868 (Koltowska et al., *Nature Cell Biology*, 2021).
* **🧬 Organismo:** *Homo sapiens* (Genoma hg38 / GRCh38.97).
* **⚙️ Estrategia:** Flujo completo automatizado desde archivos crudos (`fastq_list_strategy: "manual"`).
* **🛠️ Procesamiento:** Control de calidad con Trimmomatic, alineamiento de alta precisión con STAR y cuantificación genómica mediante featureCounts.
* **🎯 Objetivo:** Validar la precisión del pipeline en la detección de paradas del ciclo celular y estrés ribosomal inducidos por el knockdown (KD) de DDX21.
* **⚗️ Diseño Experimental:** Análisis de contrastes mediante modelos estadísticos robustos (`siRNA_01_vs_Control` y `siRNA_02_vs_Control`).

<br>

<details>
<summary>$\Large \color{#000080}{\textbf{A. Contexto y Expectativas (Estudio de Referencia)}}$</summary>
<br>

El trabajo de referencia, publicado en **Nature Cell Biology** (Koltowska et al., 2021), describe cómo la helicasa DDX21 es esencial para el desarrollo vascular al equilibrar la biogénesis de ribosomas y la señalización de p53/p21.

* **Mecanismo:** El KD de DDX21 provoca un fallo en la maquinaria de traducción y replicación, activando un arresto del ciclo celular en la fase G2/M.
* **Marcadores Clave:** Se espera una regulación a la baja (**DOWN**) masiva de genes del cinetocoro (*NDC80*), reguladores mitóticos (*PLK1, AURKB*) y factores de replicación (*CDC6, FEN1*).

</details>

<details>
<summary>$\Large \color{#000080}{\textbf{B. Resultados Obtenidos (Validación del Pipeline Local)}}$</summary>
<br>

La ejecución local del pipeline no solo fue exitosa en términos de computación, sino que replicó con una significación estadística extrema la biología del estudio original.

<details>
<summary>$\large \color{#2E8B57}{\textbf{1. Colapso de la Maquinaria Mitótica (Confirmado)}}$</summary>

El pipeline identificó como "Top DEGs" a los reguladores maestros del ciclo celular, validando la sensibilidad del modelo estadístico:

* **NDC80:** Identificado como uno de los genes más significativos (**DOWN**, log2FC: -1.89; padj: 3.02e-61). Este resultado confirma la capacidad del pipeline para detectar el fallo en la segregación cromosómica.
* **AURKB & PLK1:** Potentemente reprimidos (log2FC: -2.24 y -1.81 respectivamente). La detección coordinada de estos genes valida que el pipeline captura correctamente el arresto en G2/M.
</details>

<details>
<summary>$\large \color{#2E8B57}{\textbf{2. Inhibición de la Replicación y Reparación del ADN (Confirmado)}}$</summary>

Coincidiendo con el estrés ribosomal descrito por Koltowska et al., el análisis local mostró una caída drástica en la estabilidad genómica:

* **FEN1 & PCNA:** Marcadores críticos de la horquilla de replicación, identificados con una precisión estadística asombrosa (**DOWN**, log2FC: -2.21, padj: 8.19e-42 para FEN1; log2FC: -1.77, padj: 5.35e-35 para PCNA).
* **Complejo MCM (MCM4):** El pipeline detectó la inhibición de la helicasa replicativa (**DOWN**, log2FC: -2.20), replicando el fallo en el inicio de la síntesis de ADN.
</details>

<details>
<summary>$\large \color{#2E8B57}{\textbf{3. Enriquecimiento Funcional (Validación de Rutas)}}$</summary>

El módulo de interpretación biológica automatizado confirmó las rutas patológicas con p-valores de alta confianza:

* **DNA Replication (KEGG:03030):** Identificada como ruta líder (**p=4.97e-21**), validando la integración de la estadística con la base de datos KEGG.
* **Mitotic Spindle Checkpoint:** Confirmada con una significación de **p=3.14e-16**, consolidando la veracidad del mecanismo de acción propuesto.
</details>

</details>

<br>

<div align="center">
  <h4 style="margin-bottom: 10px;">📥 Ver Resultados Generados por el Pipeline</h4>
  
  <a href="./Rutas/Caso1/Volcano_Dashboard.html">
    <img src="https://img.shields.io/badge/📊_Volcano_Plot-Interactivo_(HTML)-FF5733?style=for-the-badge&logo=plotly&logoColor=white" alt="Volcano">
  </a>
  <a href="./Rutas/Caso1/Functional_Dashboard.html">
    <img src="https://img.shields.io/badge/🧬_SEA_&_GSEA-Dashboard_(HTML)-2E8B57?style=for-the-badge&logo=html5&logoColor=white" alt="Functional Dashboard">
  </a>
  <br>
  <a href="./Rutas/Caso1/Pathview_Atlas.pdf">
    <img src="https://img.shields.io/badge/🗺️_Pathview_Atlas-Mapas_KEGG_(PDF)-007BFF?style=for-the-badge&logo=adobeacrobatreader&logoColor=white" alt="Pathview Atlas">
  </a>
  <a href="./Rutas/Caso1/Comprehensive_Report.pdf">
    <img src="https://img.shields.io/badge/📑_Reporte_Final-g:Profiler_Analysis_(PDF)-800080?style=for-the-badge&logo=overleaf&logoColor=white" alt="Full Report">
  </a>
</div>

</div>
