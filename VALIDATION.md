# 🧪 Informe de Validación Experimental: OmniRNA-seq

[⬅️ **Volver al Repositorio Principal (README.md)**](./README.md)

Este documento documenta la ejecución del pipeline en **escenarios biológicos reales**. Cada caso de estudio representa una configuración distinta del archivo de control JSON, diseñada para validar la versatilidad del software y su precisión biológica.

> **📂 Acceso a Resultados Brutos**  
> Al final de cada sección encontrará enlaces directos a los **reportes interactivos HTML y documentos PDF** generados automáticamente por el pipeline.

---

## 💻 $\color{#8B0000}{\text{A. Modo Local (Simulación High-Performance)}}$

<div style="background-color:#f8f9fa;border:1px solid #e9ecef;border-radius:8px;padding:22px;margin-bottom:24px;">

### 🔬 Caso de Estudio 1: Silenciamiento de la Helicasa DDX21  
**Validación Técnica End-to-End**

- **🆔 Estudio:** GSE179868 (Koltowska et al., *Nature Cell Biology*, 2021)  
  🔗 https://doi.org/10.1038/s41556-021-00784-w
- **🧬 Organismo:** *Homo sapiens* (hg38)
- **⚙️ Estrategia:** `fastq_list_strategy: "manual"`  
  Trimmomatic ➔ STAR ➔ FeatureCounts
- **🎯 Objetivo:** Validar la detección de arresto del ciclo celular y estrés ribosomal inducidos por KD de DDX21
- **⚗️ Diseño Experimental:**  
  Contrastes estadísticos robustos  
  `siRNA_01_vs_Control` y `siRNA_02_vs_Control`

---

<details>
<summary><strong>A. Contexto y Expectativas (Estudio de Referencia)</strong></summary>
<br>

El estudio de referencia demuestra que **DDX21** es crítica para la biogénesis ribosomal y el control del ciclo celular.

- **Mecanismo esperado:**  
  Estrés ribosomal ➔ activación p53/p21 ➔ arresto en G2/M
- **Genes esperados DOWN:**  
  *NDC80, PLK1, AURKB, CDC6, FEN1, PCNA*

</details>

---

<details>
<summary><strong>B. Resultados Obtenidos (Validación del Pipeline)</strong></summary>
<br>

La ejecución local del pipeline reprodujo fielmente la biología descrita en el estudio original, con **significación estadística extrema**.

<details>
<summary><em>1. Colapso de la Maquinaria Mitótica</em></summary>

- **NDC80:** log2FC = -1.89 | padj = 3.02e-61  
- **AURKB / PLK1:** Represión coordinada (arresto G2/M)

</details>

<details>
<summary><em>2. Inhibición de Replicación y Reparación del ADN</em></summary>

- **FEN1:** log2FC = -2.21 | padj = 8.19e-42  
- **PCNA:** log2FC = -1.77 | padj = 5.35e-35  
- **MCM4:** Inhibición de la helicasa replicativa

</details>

<details>
<summary><em>3. Enriquecimiento Funcional</em></summary>

- **DNA Replication (KEGG:03030):** p = 4.97e-21  
- **Mitotic Spindle Checkpoint:** p = 3.14e-16

</details>

</details>

---

## 📊 Resultados Interactivos y Reportes Generados
---

### 🔴 Volcano Plots (Interactivos)

<p align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/VolcanoPlot_Dashboard_siRNA_01_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/volcanoplot_int1.png" width="260">
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/VolcanoPlot_Dashboard_siRNA_02_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/volcanoplot_int2.png" width="260">
  </a>
  <br>
  <sub><b>siRNA 01 (Izquierda) — siRNA 02 (Derecha)</b></sub>
</p>

---

### 🟢 Dashboards Transcriptómicos

<p align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Interactivo_siRNA_01_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/dashboard1.png" width="260">
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Interactivo_siRNA_02_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/dashboard2.png" width="260">
  </a>
  <br>
  <sub><b>Dashboard siRNA 01 — Dashboard siRNA 02</b></sub>
</p>

---

### 🟣 Reportes Transcriptómicos (PDF)

<p align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Transcriptomica_Completo_siRNA_01_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/gProf1.png" width="260">
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Transcriptomica_Completo_siRNA_02_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/gProf2.png" width="260">
  </a>
  <br>
  <sub><b>Reporte Completo 01 — Reporte Completo 02</b></sub>
</p>

---

### 🧬 Enriquecimiento Funcional — Gene Ontology

#### siRNA 01

<p align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_BP_siRNA_01_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/bp1.png" width="200">
  </a>
  &nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_CC_siRNA_01_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/cc1.png" width="200">
  </a>
  &nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_MF_siRNA_01_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mg1.png" width="200">
  </a>
</p>

#### siRNA 02

<p align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_BP_siRNA_02_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/bp2.png" width="200">
  </a>
  &nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_CC_siRNA_02_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/cc2.png" width="200">
  </a>
  &nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_MF_siRNA_02_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mf2.png" width="200">
  </a>
</p>

</div>
