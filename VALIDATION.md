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
- **🎯 Objetivo:** Validar la detección de arresto del ciclo celular y estrés ribosomal inducidos por KD de DDX21.
- **⚗️ Diseño Experimental:**  
  Contrastes estadísticos robustos: `siRNA_01_vs_Control` y `siRNA_02_vs_Control`.

---

<details>
<summary><strong>A. Contexto y Expectativas (Estudio de Referencia)</strong></summary>
<br>

El estudio de referencia demuestra que **DDX21** es crítica para la biogénesis ribosomal. Su ausencia desencadena una cascada de señalización específica que culmina en el arresto del ciclo celular.

A continuación, se detalla la **firma molecular obtenida** en este análisis, comparando los niveles de expresión (Log2FC) entre las dos réplicas biológicas independientes (**siRNA-01** / **siRNA-02**), lo que confirma la robustez del mecanismo detectado:

| Sistema Biológico | Estado | Genes Afectados (Log2FC)<br>*(siRNA-01 / siRNA-02)* | Hallazgo Biológico (Interpretación del Mecanismo) |
| :--- | :--- | :--- | :--- |
| **🚨 EL GATILLO (p53/p21)** | **ACTIVADO** ⬆️ | **`CDKN1A` (p21)** (+1.18 / +1.29)<br>**`MDM2`** (+1.04 / +1.16)<br>**`FAS`** (+1.36 / -)<br>**`BTG2`** (+1.09 / -) | **La Causa Raíz:** El estrés ribosomal activa p53, que a su vez induce fuertemente a **p21**. Este es el inhibidor universal de las quinasas del ciclo ("freno de mano") que provoca el colapso posterior. |
| **🏁 Inicio de Replicación** | **BLOQUEADO** ⬇️ | **`CDC6`** (-2.63 / -2.49)<br>**`CDT1`** (-2.48 / -2.36)<br>**`ORC1`** (-2.13 / -1.84)<br>**`ORC6`** (-2.10 / -1.80) | **Licencia Denegada:** Represión profunda (>4 veces) de los componentes del complejo pre-replicativo. Sin `CDC6` ni `CDT1`, la célula es incapaz de marcar dónde empezar a copiar el ADN. El proceso ni siquiera arranca. |
| **🧱 Suministro de "Ladrillos"** | **CORTADO** ⬇️ | **`RRM2`** (-2.58 / -2.25)<br>**`TK1`** (-1.09 / -1.45)<br>**`TYMS`** (No sig.) | **Sin Materiales:** La enzima `RRM2` es el factor limitante para la síntesis de nucleótidos. Su drástica caída (-2.5 log) genera un "cuello de botella" metabólico que hace imposible la síntesis de nuevo ADN. |
| **⚙️ El Motor de Copiado** | **APAGADO** ⬇️ | **`MCM10`** (-2.84 / -2.43)<br>**`MCM2-7`** (~ -1.80 / -1.70)<br>**`PCNA`** (-1.77 / -1.37)<br>**`POLE`** (-1.82 / -2.22) | **Helicasa Detenida:** Desmantelamiento coordinado del complejo helicasa (`MCMs`) y la maquinaria de la polimerasa (`PCNA`, `POLE`). La célula ha eliminado la maquinaria necesaria para abrir y copiar la doble hélice. |
| **🔧 Reparación del ADN** | **SUPRIMIDA** ⬇️ | **`BRCA1`** (-2.14 / -1.77)<br>**`BRCA2`** (-2.53 / -1.94)<br>**`RAD51`** (-1.68 / -2.08)<br>**`FANCD2`** (-1.26 / -1.68) | **Fragilidad Genómica:** Al detenerse la replicación, se reprime la vía de Recombinación Homóloga (HR). La caída de `BRCA` y `RAD51` induce un estado de "brittleness" (fragilidad extrema) ante daños en el ADN. |
| **🏗️ Estructura Mitótica** | **COLAPSADA** ⬇️ | **`AURKB`** (-2.24 / -2.10)<br>**`PLK1`** (-1.81 / -1.76)<br>**`CDK1`** (-2.61 / -2.09)<br>**`BUB1`** (-1.72 / -1.43) | **Sin División:** Aurora B y PLK1 son los reguladores maestros de la mitosis. Su ausencia total (>2 log de represión) confirma que las células no están entrando en fase M. |
| **🚂 Motores Moleculares** | **MASACRADOS** ⬇️ | **`KIFC1`** (-2.63 / -2.04)<br>**`KIF11`** (-1.84 / -1.75)<br>**`KIF18A`** (-2.53 / -2.44)<br>**`KIF14`** (-1.60 / -1.56) | **Transporte Parado:** Represión masiva de las Kinesinas (`KIF`). `KIF11` (Eg5) es esencial para la bipolaridad del huso; su ausencia impide la separación de los polos, bloqueando la mitosis. |
| **🎯 Centrómero y Cinetocoro** | **DESMANTELADO** ⬇️ | **`CENPA`** (-2.29 / -1.69)<br>**`CENPE`** (-1.59 / -1.29)<br>**`CENPF`** (-1.67 / -1.60)<br>**`NDC80`** (-1.89 / -1.58) | **Pérdida de Identidad:** `CENPA` define el centro del cromosoma y `NDC80` es el gancho del microtúbulo. Su caída indica una pérdida de la integridad estructural del cinetocoro. |

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
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/volcanoplot_int1.png" width="300">
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/VolcanoPlot_Dashboard_siRNA_02_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/volcanoplot_int2.png" width="300">
  </a>
  <br>
  <sub><b>siRNA 01 (Izquierda) — siRNA 02 (Derecha)</b></sub>
</p>

---

### 🟢 Dashboards Transcriptómicos

<p align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Interactivo_siRNA_01_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/dashboard1.png" width="300">
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Interactivo_siRNA_02_vs_Control.html" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/dashboard2.png" width="300">
  </a>
  <br>
  <sub><b>Dashboard siRNA 01 — Dashboard siRNA 02</b></sub>
</p>

---

### 🟣 Reportes Transcriptómicos (PDF)

<p align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Transcriptomica_Completo_siRNA_01_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/gProf1.png" width="300">
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Transcriptomica_Completo_siRNA_02_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/gProf2.png" width="300">
  </a>
  <br>
  <sub><b>Reporte Completo 01 — Reporte Completo 02</b></sub>
</p>

---

### 🧬 Enriquecimiento Funcional — Gene Ontology

#### siRNA 01

<p align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_BP_siRNA_01_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/bp1.png" width="240">
  </a>
  &nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_CC_siRNA_01_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/cc1.png" width="240">
  </a>
  &nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_MF_siRNA_01_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mg1.png" width="240">
  </a>
</p>

#### siRNA 02

<p align="center">
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_BP_siRNA_02_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/bp2.png" width="240">
  </a>
  &nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_CC_siRNA_02_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/cc2.png" width="240">
  </a>
  &nbsp;
  <a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Visual_GO_MF_siRNA_02_vs_Control.pdf" target="_blank">
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mf2.png" width="240">
  </a>
</p>

</div>
