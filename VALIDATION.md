# 🧪 Informe de Validación Experimental: OmniRNA-seq

[⬅️ **Volver al Repositorio Principal (README.md)**](./README.md)

Este documento documenta la ejecución del pipeline en **escenarios biológicos reales**. Cada caso de estudio representa una configuración distinta del archivo de control JSON, diseñada para validar la versatilidad del software (desde la descarga de datos públicos hasta el análisis local) y su precisión biológica.

A continuación, se detallan los resultados obtenidos, contrastando las expectativas biológicas con los datos de salida generados por el pipeline.

> **📂 Acceso a Resultados Brutos:**
> Para cada caso de estudio, encontrará un panel de control al final de la sección que le permitirá visualizar los **reportes interactivos y PDFs** generados automáticamente por el pipeline.

---

## 💻 $\color{#8B0000}{\text{A. Modo Local (Simulación High-Performance)}}$

<div style="background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 8px; padding: 20px; margin-bottom: 20px;">

### 🔬 Caso de Estudio 1: Silenciamiento de la Helicasa DDX21
**Validación Técnica Definitiva (End-to-End)**

* **🆔 Estudio:** GSE179868 (Koltowska et al., *Nature Cell Biology*, 2021) [[🔗 DOI: 10.1038/s41556-021-00784-w]](https://doi.org/10.1038/s41556-021-00784-w).
* **🧬 Organismo:** *Homo sapiens* (hg38).
* **⚙️ Estrategia:** `fastq_list_strategy: "manual"`. Flujo completo: Trimmomatic ➔ STAR ➔ FeatureCounts.
* **🎯 Objetivo:** Validar la precisión en la detección de paradas del ciclo celular y estrés ribosomal inducidos por el knockdown (KD) de DDX21.
* **⚗️ Diseño:** Análisis de contrastes mediante modelos estadísticos robustos (`siRNA_01_vs_Control` y `siRNA_02_vs_Control`).

<br>

<details>
<summary>$\Large \color{#000080}{\textbf{A. Contexto y Expectativas (Estudio de Referencia)}}$</summary>
<br>

El trabajo de referencia, publicado en **Nature Cell Biology** (Koltowska et al., 2021), describe cómo la helicasa DDX21 es esencial para el desarrollo vascular al equilibrar la biogénesis de ribosomas y la señalización de p53/p21.

* **Mecanismo:** El KD de DDX21 provoca un fallo en la maquinaria de traducción y replicación, activando un arresto del ciclo celular en la fase G2/M.
* **Marcadores Esperados:** Se espera una regulación a la baja (**DOWN**) masiva de genes del cinetocoro (*NDC80*), reguladores mitóticos (*PLK1, AURKB*) y factores de replicación (*CDC6, FEN1*).

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

<table style="border: none; border-collapse: collapse; background-color: transparent;">
<tr>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/VolcanoPlot_Dashboard_siRNA_01_vs_Control.html" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/volcanoplot_int1.png" width="190" alt="Volcano 01">
</a>
</td>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/VolcanoPlot_Dashboard_siRNA_02_vs_Control.html" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/volcanoplot_int2.png" width="190" alt="Volcano 02">
</a>
</td>
</tr>
<tr>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Interactivo_siRNA_01_vs_Control.html" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/dashboard1.png" width="190" alt="Dashboard 01">
</a>
</td>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Interactivo_siRNA_02_vs_Control.html" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/dashboard2.png" width="190" alt="Dashboard 02">
</a>
</td>
</tr>
<tr>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Transcriptomica_Completo_siRNA_01_vs_Control.pdf" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/gProf1.png" width="190" alt="Report 01">
</a>
</td>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Transcriptomica_Completo_siRNA_02_vs_Control.pdf" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/gProf2.png" width="190" alt="Report 02">
</a>
</td>
</tr>
</table>

<br>

<table style="border: none; border-collapse: collapse; background-color: transparent;">
<tr><td colspan="3" align="center" style="border: none; padding-bottom: 5px; font-weight: bold; color: #555; font-size: 0.85em; letter-spacing: 1px;">VISUALIZACIÓN GENE ONTOLOGY (siRNA 01)</td></tr>
<tr>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_BP_siRNA_01_vs_Control.pdf" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/bp1.png" width="150" alt="BP 01">
</a>
</td>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_CC_siRNA_01_vs_Control.pdf" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/cc1.png" width="150" alt="CC 01">
</a>
</td>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_MF_siRNA_01_vs_Control.pdf" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mg1.png" width="150" alt="MF 01">
</a>
</td>
</tr>
<tr><td colspan="3" style="border: none; height: 10px;"></td></tr>
<tr><td colspan="3" align="center" style="border: none; padding-bottom: 5px; font-weight: bold; color: #555; font-size: 0.85em; letter-spacing: 1px;">VISUALIZACIÓN GENE ONTOLOGY (siRNA 02)</td></tr>
<tr>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_BP_siRNA_02_vs_Control.pdf" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/bp2.png" width="150" alt="BP 02">
</a>
</td>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_CC_siRNA_02_vs_Control.pdf" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/cc2.png" width="150" alt="CC 02">
</a>
</td>
<td align="center" style="border: none; padding: 2px;">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_MF_siRNA_02_vs_Control.pdf" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mf2.png" width="150" alt="MF 02">
</a>
</td>
</tr>
</table>

</div>

</div>
