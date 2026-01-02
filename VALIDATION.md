# 🧪 Informe de Validación Experimental: OmniRNA-seq

[⬅️ **Volver al Repositorio Principal**](./README.md)

Este documento documenta la ejecución del pipeline en **escenarios biológicos reales**. Cada caso de estudio representa una configuración distinta del archivo de control JSON, diseñada para validar la versatilidad del software (desde la descarga de datos públicos hasta el análisis local) y su precisión biológica.

A continuación, se detallan los resultados obtenidos, contrastando las expectativas biológicas con los datos de salida generados por el pipeline.

> **📂 Acceso a Resultados Brutos:**
> Para cada caso de estudio, encontrará una botonera al final de la sección que le permitirá visualizar los **reportes interactivos y PDFs** generados automáticamente por el pipeline (Volcano Plots, Dashboards de Enriquecimiento SEA/GSEA y Atlas de Rutas Metabólicas).

---

## 💻 $\color{#8B0000}{\text{A. Modo Local (Simulación High-Performance)}}$

<div style="background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 8px; padding: 20px; margin-bottom: 20px;">

### 🔬 Caso de Estudio 1: Silenciamiento de la Helicasa DDX21
**Validación Técnica Definitiva (End-to-End)**

* **🆔 Estudio:** GSE179868 (Koltowska et al., *Nature Cell Biology*, 2021).
* **🧬 Organismo:** *Homo sapiens* (hg38).
* **⚙️ Estrategia:** `fastq_list_strategy: "manual"`. Flujo completo: Trimmomatic ➔ STAR ➔ FeatureCounts.
* **🎯 Objetivo:** Validar la precisión en la detección de paradas del ciclo celular y estrés ribosomal inducidos por el knockdown (KD) de DDX21.

#### $\color{#000080}{\text{1. Contexto y Expectativas (Nature Cell Biology)}}$
El trabajo de referencia describe cómo la helicasa DDX21 es esencial para el desarrollo vascular.
* **Mecanismo:** El KD de DDX21 provoca un fallo en la maquinaria de traducción y replicación, activando un arresto del ciclo celular en la fase G2/M.
* **Marcadores Esperados:** Regulación a la baja (**DOWN**) de genes del cinetocoro (*NDC80*), reguladores mitóticos (*PLK1, AURKB*) y factores de replicación (*CDC6, FEN1*).

#### $\color{#000080}{\text{2. Resultados Obtenidos (Validación)}}$
La ejecución local replicó con una significación estadística extrema la biología del estudio original.

* **📉 Colapso de la Maquinaria Mitótica (Confirmado):**
    El pipeline identificó como "Top DEGs" a los reguladores maestros:
    * **NDC80:** (DOWN, log2FC: -1.89; padj: 3.02e-61). Confirma fallo en segregación cromosómica.
    * **AURKB & PLK1:** Potentemente reprimidos (-2.24 y -1.81 FC), validando el arresto en G2/M.

* **🚫 Inhibición de Replicación y Reparación (Confirmado):**
    Coincidiendo con el estrés ribosomal descrito, se detectó una caída drástica en la estabilidad genómica:
    * **FEN1 & PCNA:** Marcadores de la horquilla de replicación colapsados (padj: 8.19e-42).
    * **MCM4:** Inhibición de la helicasa replicativa.

* **🧬 Enriquecimiento Funcional (Rutas):**
    * *DNA Replication* (KEGG:03030): Ruta líder ($p=4.97 \times 10^{-21}$).
    * *Mitotic Spindle Checkpoint*: Confirmada ($p=3.14 \times 10^{-16}$).

#### $\color{#000080}{\text{3. Conclusión}}$
Este caso demuestra que OmniRNA-seq es **Robusto** (procesa alta densidad), **Preciso** (p-values de $10^{-61}$) y **Científicamente Válido**, listo para cohortes clínicas.

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

---

## 🌍 $\color{#8B0000}{\text{B. Modo Explorer (Casos Públicos Multiespecie)}}$

<details>
<summary>$\Large \textbf{🦠 Caso 1: COVID-19 y Tormenta de Citoquinas (Homo sapiens)}$</summary>
<br>

* **Paper:** *Imbalanced Host Response to SARS-CoV-2...* (Blanco-Melo et al., 2020).
* **ID:** GSE147507.
* **Estrategia:** Matriz Pre-calculada (`counting_method: "precomputed_csv"`).

**A. Contexto:**
El estudio definió la huella molecular del SARS-CoV-2: una producción descontrolada de citoquinas proinflamatorias (IL-6, IL-1) sin una respuesta antiviral robusta (Interferones bajos).

**B. Validación:**
El pipeline identificó con precisión la firma de la "Tormenta de Citoquinas":
1.  **Hiperinflamación:** `IL6` (Log2FC: 3.65) y `TNF` (Log2FC: 2.40) fuertemente inducidos.
2.  **Reclutamiento Inmune:** Sobrerregulación de `CXCL2` y `CXCL3` (atracción de neutrófilos).
3.  **Rutas Patogénicas:** Validación de *Acute Inflammatory Response* impulsada por el núcleo `IL1B` / `IL1A`.

<div align="center" style="margin-top: 20px; border-top: 1px dashed #ccc; padding-top: 15px;">
  <a href="./Rutas/Caso2/Volcano.html"><img src="https://img.shields.io/badge/📊_Volcano-Interactivo-FF5733?style=flat-square"></a>
  <a href="./Rutas/Caso2/Dashboard.html"><img src="https://img.shields.io/badge/🧬_Functional-Dashboard-2E8B57?style=flat-square"></a>
  <a href="./Rutas/Caso2/Pathview.pdf"><img src="https://img.shields.io/badge/🗺️_Pathview-Atlas-007BFF?style=flat-square"></a>
  <a href="./Rutas/Caso2/Report.pdf"><img src="https://img.shields.io/badge/📑_Reporte-Completo-800080?style=flat-square"></a>
</div>
</details>

<details>
<summary>$\Large \textbf{💊 Caso 2: Asma y Farmacogenómica (Homo sapiens)}$</summary>
<br>

* **Paper:** *Himes et al., 2014* (GSE52778).
* **Objetivo:** Mecanismo de acción de la Dexametasona en músculo liso bronquial.

**A. Contexto:**
Investigación de la eficacia de corticoides. Se espera inducción de genes antiinflamatorios y el descubrimiento del gen *CRISPLD2*.

**B. Validación:**
1.  **Inducción Glucocorticoide:** `FKBP5` detectado como el gen más inducido (+8.54 FC).
2.  **Validación del Gen Hero:** Se confirmó la inducción de `CRISPLD2` (Log2FC: +2.63; padj: 4.45e-20), validando el hallazgo principal del paper.
3.  **Supresión Inflamatoria:** Represión exitosa de `TNFSF15` y `CXCL12`.

<div align="center" style="margin-top: 20px; border-top: 1px dashed #ccc; padding-top: 15px;">
  <a href="./Rutas/Caso3/Volcano.html"><img src="https://img.shields.io/badge/📊_Volcano-Interactivo-FF5733?style=flat-square"></a>
  <a href="./Rutas/Caso3/Dashboard.html"><img src="https://img.shields.io/badge/🧬_Functional-Dashboard-2E8B57?style=flat-square"></a>
  <a href="./Rutas/Caso3/Pathview.pdf"><img src="https://img.shields.io/badge/🗺️_Pathview-Atlas-007BFF?style=flat-square"></a>
  <a href="./Rutas/Caso3/Report.pdf"><img src="https://img.shields.io/badge/📑_Reporte-Completo-800080?style=flat-square"></a>
</div>
</details>

<details>
<summary>$\Large \textbf{🍔 Caso 3: Obesidad y Tejido Adiposo (Mus musculus)}$</summary>
<br>

* **Paper:** *Shi et al., 2018* (GSE112740).
* **Objetivo:** Caracterizar el "blanqueamiento" del Tejido Adiposo Marrón (BAT).

**A. Contexto:**
La obesidad provoca pérdida de identidad miogénica en el BAT y fallo termogénico.

**B. Validación:**
1.  **Colapso Muscular:** Represión severa de `Tnni1` (-6.79 FC), `Myl1` y `Tnnt2`.
2.  **Fallo Termogénico:** Inhibición del canal de calcio `Cacna1s`, esencial para la mitocondria.
3.  **Inflamación:** Detección de la ruta *Cytokine-cytokine receptor interaction* (`Il10`, `Xcl1`).

<div align="center" style="margin-top: 20px; border-top: 1px dashed #ccc; padding-top: 15px;">
  <a href="./Rutas/Caso4/Volcano.html"><img src="https://img.shields.io/badge/📊_Volcano-Interactivo-FF5733?style=flat-square"></a>
  <a href="./Rutas/Caso4/Dashboard.html"><img src="https://img.shields.io/badge/🧬_Functional-Dashboard-2E8B57?style=flat-square"></a>
  <a href="./Rutas/Caso4/Pathview.pdf"><img src="https://img.shields.io/badge/🗺️_Pathview-Atlas-007BFF?style=flat-square"></a>
  <a href="./Rutas/Caso4/Report.pdf"><img src="https://img.shields.io/badge/📑_Reporte-Completo-800080?style=flat-square"></a>
</div>
</details>

<details>
<summary>$\Large \textbf{🚀 Caso 4: Estrés Espacial (Arabidopsis thaliana)}$</summary>
<br>

* **Paper:** *Ferl et al.* (PRJNA375085).
* **Objetivo:** Efecto de la microgravedad en la ISS sobre las plantas.

**A. Contexto:**
Se espera Hipoxia (raíces ahogadas por falta de drenaje sin gravedad) y Estrés Oxidativo.

**B. Validación:**
1.  **Hipoxia:** Activación de la fermentación alcohólica mediante `ADH1` (Log2FC: 2.97).
2.  **Estrés Oxidativo:** Respuesta masiva de Peroxidasas (`AtPRX71`) y Glutatión (`ATGSTF3`).
3.  **Parada de Crecimiento:** Represión de fotosíntesis (`PSBR`) y pared celular (`AtXTH31`).

<div align="center" style="margin-top: 20px; border-top: 1px dashed #ccc; padding-top: 15px;">
  <a href="./Rutas/Caso5/Volcano.html"><img src="https://img.shields.io/badge/📊_Volcano-Interactivo-FF5733?style=flat-square"></a>
  <a href="./Rutas/Caso5/Dashboard.html"><img src="https://img.shields.io/badge/🧬_Functional-Dashboard-2E8B57?style=flat-square"></a>
  <a href="./Rutas/Caso5/Pathview.pdf"><img src="https://img.shields.io/badge/🗺️_Pathview-Atlas-007BFF?style=flat-square"></a>
  <a href="./Rutas/Caso5/Report.pdf"><img src="https://img.shields.io/badge/📑_Reporte-Completo-800080?style=flat-square"></a>
</div>
</details>

<details>
<summary>$\Large \textbf{🧠 Caso 5: Alzheimer Modelo 5xFAD (Mus musculus)}$</summary>
<br>

* **Paper:** *Forner et al., 2021* (GSE168137).
* **Objetivo:** Fenotipado sistemático del modelo 5xFAD.

**A. Contexto:**
Patología dual: Respuesta inmune innata (Microglía DAM) y pérdida de plasticidad neuronal.

**B. Validación:**
1.  **Microglía Reactiva:** Inducción de `Cxcl10` (+2.58 FC) y `Ccl12`, validando la quimiotaxis inmune.
2.  **Colapso Neuronal:** Represión de genes IEGs de la familia Fos (`Fos`, `Fosb`), explicando el déficit cognitivo.
3.  **Precisión Funcional:** Detección de rutas inflamatorias compartidas (*Viral myocarditis* en KEGG) impulsadas por el núcleo TNF/IL-1.

<div align="center" style="margin-top: 20px; border-top: 1px dashed #ccc; padding-top: 15px;">
  <a href="./Rutas/Caso6/Volcano.html"><img src="https://img.shields.io/badge/📊_Volcano-Interactivo-FF5733?style=flat-square"></a>
  <a href="./Rutas/Caso6/Dashboard.html"><img src="https://img.shields.io/badge/🧬_Functional-Dashboard-2E8B57?style=flat-square"></a>
  <a href="./Rutas/Caso6/Pathview.pdf"><img src="https://img.shields.io/badge/🗺️_Pathview-Atlas-007BFF?style=flat-square"></a>
  <a href="./Rutas/Caso6/Report.pdf"><img src="https://img.shields.io/badge/📑_Reporte-Completo-800080?style=flat-square"></a>
</div>
</details>

<details>
<summary>$\Large \textbf{🪰 Caso 6: Miogénesis (Drosophila melanogaster)}$</summary>
<br>

* **Paper:** *Moucaud et al., PLoS Biol 2024*.
* **Objetivo:** Identificación de marcadores de adhesión en mioblastos.

**A. Contexto:**
Comparación de mioblastos puros vs tejido total para encontrar el gen *Amalgam*.

**B. Validación:**
1.  **Firma Miogénica:** Enriquecimiento de reguladores maestros: `twi`, `Mef2`, `zfh1` y `him`.
2.  **Validación del Descubrimiento:** `Ama` (Amalgam) identificado como gen enriquecido, replicando la Figura 1 del paper.
3.  **Pureza Celular:** Confirmación de la ausencia de marcadores ectodérmicos (`wg`, `Dll`).

<div align="center" style="margin-top: 20px; border-top: 1px dashed #ccc; padding-top: 15px;">
  <a href="./Rutas/Caso7/Volcano.html"><img src="https://img.shields.io/badge/📊_Volcano-Interactivo-FF5733?style=flat-square"></a>
  <a href="./Rutas/Caso7/Dashboard.html"><img src="https://img.shields.io/badge/🧬_Functional-Dashboard-2E8B57?style=flat-square"></a>
  <a href="./Rutas/Caso7/Pathview.pdf"><img src="https://img.shields.io/badge/🗺️_Pathview-Atlas-007BFF?style=flat-square"></a>
  <a href="./Rutas/Caso7/Report.pdf"><img src="https://img.shields.io/badge/📑_Reporte-Completo-800080?style=flat-square"></a>
</div>
</details>

<details>
<summary>$\Large \textbf{🐟 Caso 7: Neurotoxicidad (Danio rerio)}$</summary>
<br>

* **Paper:** *Aluru et al., 2022*.
* **Objetivo:** Efecto de la Saxitoxina (STX) en el desarrollo.

**B. Validación por Puntos Temporales:**
1.  **24hpf (Inicio):** Detección temprana de fallo en calcio (`atp2a1l`), prediciendo parálisis.
2.  **36hpf (Desviación):** Impacto visual con caída de genes de fototransducción (`gnb3b`).
3.  **48hpf (Colapso):** Validación del mecanismo de muerte por **Necroptosis** (`ripk1`, `ripk3`), conectando el fallo de adhesión con la muerte celular.

<div align="center" style="margin-top: 20px; border-top: 1px dashed #ccc; padding-top: 15px;">
  <a href="./Rutas/Caso8/Volcano.html"><img src="https://img.shields.io/badge/📊_Volcano-Interactivo-FF5733?style=flat-square"></a>
  <a href="./Rutas/Caso8/Dashboard.html"><img src="https://img.shields.io/badge/🧬_Functional-Dashboard-2E8B57?style=flat-square"></a>
  <a href="./Rutas/Caso8/Pathview.pdf"><img src="https://img.shields.io/badge/🗺️_Pathview-Atlas-007BFF?style=flat-square"></a>
  <a href="./Rutas/Caso8/Report.pdf"><img src="https://img.shields.io/badge/📑_Reporte-Completo-800080?style=flat-square"></a>
</div>
</details>

<details>
<summary>$\Large \textbf{🍺 Caso 8: Longevidad (Saccharomyces cerevisiae)}$</summary>
<br>

* **Paper:** *Sen et al., 2015* (GSE53720).
* **Objetivo:** Mecanismos de la Restricción Calórica (CR).

**B. Validación:**
1.  **Ciclo del Glioxilato:** Inducción masiva de `ICL1` (**+6.23 FC**) y `MLS1`, permitiendo vivir de fuentes de carbono alternativas.
2.  **Beta-Oxidación:** Activación peroxisomal mediante Catalasa A (`CTA1`).
3.  **Conclusión:** Cuantificación precisa del "interruptor metabólico" necesario para la longevidad.

<div align="center" style="margin-top: 20px; border-top: 1px dashed #ccc; padding-top: 15px;">
  <a href="./Rutas/Caso9/Volcano.html"><img src="https://img.shields.io/badge/📊_Volcano-Interactivo-FF5733?style=flat-square"></a>
  <a href="./Rutas/Caso9/Dashboard.html"><img src="https://img.shields.io/badge/🧬_Functional-Dashboard-2E8B57?style=flat-square"></a>
  <a href="./Rutas/Caso9/Pathview.pdf"><img src="https://img.shields.io/badge/🗺️_Pathview-Atlas-007BFF?style=flat-square"></a>
  <a href="./Rutas/Caso9/Report.pdf"><img src="https://img.shields.io/badge/📑_Reporte-Completo-800080?style=flat-square"></a>
</div>
</details>

<details>
<summary>$\Large \textbf{🪱 Caso 9: Toxicología Ambiental (Caenorhabditis elegans)}$</summary>
<br>

* **Paper:** *Qu et al., 2022* (GSE189660).
* **Objetivo:** Respuesta al Cadmio.

**B. Validación:**
1.  **Quelación de Metales:** `mtl-1` (Metalotioneína) identificado como Top DEG (+4.11 FC).
2.  **Fase II Detox:** Inducción extrema de Glutatión S-transferasas (`gst-38`, `gst-24`).
3.  **Metabolismo:** Enriquecimiento en rutas de *Metabolism of xenobiotics*.

<div align="center" style="margin-top: 20px; border-top: 1px dashed #ccc; padding-top: 15px;">
  <a href="./Rutas/Caso10/Volcano.html"><img src="https://img.shields.io/badge/📊_Volcano-Interactivo-FF5733?style=flat-square"></a>
  <a href="./Rutas/Caso10/Dashboard.html"><img src="https://img.shields.io/badge/🧬_Functional-Dashboard-2E8B57?style=flat-square"></a>
  <a href="./Rutas/Caso10/Pathview.pdf"><img src="https://img.shields.io/badge/🗺️_Pathview-Atlas-007BFF?style=flat-square"></a>
  <a href="./Rutas/Caso10/Report.pdf"><img src="https://img.shields.io/badge/📑_Reporte-Completo-800080?style=flat-square"></a>
</div>
</details>
