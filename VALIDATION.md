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

El estudio de referencia demuestra que **DDX21** es crítica para la biogénesis ribosomal. Su ausencia desencadena una cascada de señalización específica que culmina en el arresto del ciclo celular. A continuación, se detalla la **firma molecular esperada** basada en los hallazgos biológicos descritos en la literatura:

| Sistema Biológico | Estado Esperado | Mecanismo Molecular Descrito (Literatura) |
| :--- | :--- | :--- |
| **🚨 Eje p53/p21** | **ACTIVADO** ⬆️ | El estrés ribosomal impide la degradación de p53 por MDM2. La acumulación de p53 induce la expresión de **p21** (*CDKN1A*), que actúa como inhibidor universal de las quinasas dependientes de ciclina (CDKs), frenando el ciclo. |
| **📉 Biogénesis Ribosomal** | **SUPRIMIDO** ⬇️ | DDX21 es necesaria para el procesamiento del rRNA 47S. Su pérdida provoca un fallo en la maduración de los ribosomas y una caída transcripcional de los genes ribosomales y nucleolares. |
| **🔄 Maquinaria Mitótica** | **COLAPSADA** ⬇️ | Como consecuencia del arresto en fases previas (G1/S), la célula reprime la expresión de genes esenciales para la mitosis, incluyendo **Aurora Kinase B** (*AURKB*), **PLK1** y múltiples kinesinas motoras (*KIFs*), impidiendo la división celular. |
| **🧬 Replicación del ADN** | **BLOQUEADA** ⬇️ | La activación del checkpoint impide la formación de los complejos de pre-replicación (*CDC6*, *CDT1*) y la actividad de las helicasas replicativas (*MCMs*), bloqueando la entrada en fase S. |

</details>

---

<details>
<summary><strong>B. Resultados Obtenidos (Validación del Pipeline)</strong></summary>
<br>

El análisis de los datos generados por **OmniRNA-seq** muestra una recapitulación precisa del fenotipo descrito. La siguiente tabla compara los niveles de expresión (**Log2 Fold Change**) obtenidos en las dos réplicas biológicas independientes (**siRNA-01** y **siRNA-02**), demostrando la robustez técnica del pipeline:

| Sistema Biológico | Gen Clave | **siRNA-01** (Log2FC) | **siRNA-02** (Log2FC) | Interpretación del Hallazgo |
| :--- | :--- | :--- | :--- | :--- |
| **🚨 El Gatillo (p53)** | **`CDKN1A` (p21)** | **+1.178** | **+1.287** | 🔴 **STOP ACTIVADO.** La señal es idéntica y robusta en ambos. Bloqueo total. |
| | **`MDM2`** | **+1.043** | **+1.159** | ⬆️ p53 está estabilizado y activo. |
| | **`FAS`** | **+1.355** | **-** | ⚠️ El siRNA-01 activa apoptosis; el 02 es puramente citostático (parada). |
| **🏁 Replicación** | **`CDC6`** | **-2.631** | **-2.490** | 📉 **Colapso Total.** Sin esto, la replicación **no puede ni empezar**. |
| | **`CDT1`** | **-2.476** | **-2.358** | 📉 El complejo pre-replicativo está totalmente ausente. |
| | **`RRM2`** | **-2.584** | **-2.254** | 📉 **Cuello de botella.** Falta la materia prima (nucleótidos) para el ADN. |
| **⚙️ Helicasa** | **`MCM10`** | **-2.840** | **-2.433** | 📉 Bajada masiva. Esencial para abrir la doble hélice. |
| | **`PCNA`** | **-1.774** | **-1.372** | 📉 Sin la abrazadera, la polimerasa se cae del ADN. |
| **🔧 Reparación** | **`BRCA1`** | **-2.142** | **-1.766** | 📉 **Fragilidad Genómica.** Sensibilidad extrema a daños. |
| | **`RAD51`** | **-1.683** | **-2.077** | 📉 Mecanismo de Recombinación Homóloga anulado. |
| **🏗️ Mitosis** | **`AURKB`** | **-2.243** | **-2.095** | 📉 **Fallo Mitótico.** Caída idéntica (>2 log) en ambos. |
| | **`PLK1`** | **-1.813** | **-1.760** | 📉 La quinasa que inicia la división está apagada. |
| | **`CDK1`** | **-2.611** | **-2.088** | 📉 El motor principal del ciclo está detenido. |
| **🚂 Motores** | **`KIFC1`** | **-2.633** | **-2.040** | 📉 Los polos del huso no se pueden juntar. |
| | **`KIF11`** | **-1.836** | **-1.751** | 📉 El huso bipolar no se puede formar (Eg5). |
| **🎯 Centrómero** | **`CENPA`** | **-2.294** | **-1.689** | 📉 Pérdida estructural del sitio de unión del cromosoma. |
| | **`NDC80`** | **-1.886** | **-1.581** | 📉 El "gancho" del microtúbulo no está. |

#### 📝 Interpretación Biológica de los Resultados

Los datos revelan una **respuesta celular bifásica** y altamente conservada ante la pérdida de DDX21. En primer lugar, se observa una activación transcripcional robusta del eje **p53-p21** (*MDM2, CDKN1A*), que actúa como el evento iniciador del arresto del ciclo celular. Esta señal de "freno" provoca, en consecuencia, un **colapso transcripcional masivo** de toda la maquinaria necesaria para la proliferación: desde los factores de "licencia" de la replicación en fase S (*CDC6, CDT1, MCMs*) hasta los componentes estructurales y motores de la mitosis (*AURKB, PLK1, Kinesinas*). La consistencia cuantitativa de los valores Log2FC entre ambas réplicas (siRNA-01 y siRNA-02) valida la precisión del pipeline para caracterizar fenotipos complejos de parada del crecimiento.

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
