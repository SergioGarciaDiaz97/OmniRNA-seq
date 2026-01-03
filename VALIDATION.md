# 🧪 Informe de Validación Experimental: OmniRNA-seq

[⬅️ **Volver al Repositorio Principal (README.md)**](./README.md)

Este documento documenta la ejecución del pipeline en escenarios biológicos reales, validando su precisión computacional y biológica.

---

## 💻 $\color{#8B0000}{\text{A. Modo Local (Simulación High-Performance)}}$

<div style="background-color:#f8f9fa;border:1px solid #e9ecef;border-radius:8px;padding:22px;margin-bottom:24px;">

### 🔬 Caso de Estudio 1: Silenciamiento de la Helicasa DDX21  
**Validación Técnica End-to-End**

- **🆔 Estudio:** GSE179868 (Koltowska et al., *Nature Cell Biology*, 2021)  
  https://doi.org/10.1038/s41556-021-00784-w
- **🧬 Organismo:** *Homo sapiens* (hg38)
- **⚙️ Estrategia:** Trimmomatic ➔ STAR ➔ FeatureCounts
- **🎯 Objetivo:** Detección de arresto del ciclo celular y estrés ribosomal
- **⚗️ Diseño:** `siRNA_01_vs_Control` · `siRNA_02_vs_Control`

---

## 📊 Resultados Interactivos y Reportes Generados

---

### 🔴 Volcano Plots (Interactivos)

<div align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/VolcanoPlot_Dashboard_siRNA_01_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/volcanoplot_int1.png" width="300">
  </a>
  <br><br>
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/VolcanoPlot_Dashboard_siRNA_02_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/volcanoplot_int2.png" width="300">
  </a>
</div>

---

### 🟢 Dashboards Transcriptómicos

<div align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Interactivo_siRNA_01_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/dashboard1.png" width="300">
  </a>
  <br><br>
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Interactivo_siRNA_02_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/dashboard2.png" width="300">
  </a>
</div>

---

### 🟣 Reportes Transcriptómicos (PDF)

<div align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Transcriptomica_Completo_siRNA_01_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/gProf1.png" width="260">
  </a>
  <br><br>
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Transcriptomica_Completo_siRNA_02_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/gProf2.png" width="260">
  </a>
</div>

---

### 🧬 Gene Ontology

#### siRNA 01
<div align="center">
  <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/bp1.png" width="200">
  <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/cc1.png" width="200">
  <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mg1.png" width="200">
</div>

---

#### siRNA 02
<div align="center">
  <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/bp2.png" width="200">
  <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/cc2.png" width="200">
  <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mf2.png" width="200">
</div>

</div>
