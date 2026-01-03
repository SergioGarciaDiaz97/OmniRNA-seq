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

<details open>
<summary><strong>A. Contexto y Expectativas (Estudio de Referencia)</strong></summary>
<br>

El estudio de referencia demuestra que **DDX21** es crítica para la biogénesis ribosomal. Su ausencia desencadena una cascada de señalización específica que culmina en el arresto del ciclo celular. A continuación, se detalla la **firma molecular esperada** basada en los hallazgos biológicos descritos en la literatura:

| Sistema Biológico | Estado | Genes Afectados (LogFC) | Hallazgo Biológico (Mecanismo) |
| :--- | :--- | :--- | :--- |
| **🚨 EL GATILLO (p53/p21)** | **ACTIVADO** ⬆️ | **`CDKN1A` (p21)** (+1.12)<br>**`MDM2`** (+0.97)<br>**`FAS`** (+1.01)<br>**`BTG2`** (+0.90) | **La Causa Raíz:** El estrés ribosomal activa p53, que a su vez dispara **p21**. p21 es el inhibidor universal de las quinasas del ciclo ("freno de mano") que provoca el colapso posterior. |
| **🏁 Inicio de Replicación** | **BLOQUEADO** ⬇️ | **`CDC6`** (-2.61)<br>**`CDT1`** (-2.41)<br>**`ORC1`** (-1.90)<br>**`ORC6`** (-2.11) | **Licencia Denegada:** Estos genes forman el "complejo de pre-replicación". Sin `CDC6` ni `CDT1`, la célula no puede marcar dónde empezar a copiar el ADN. El proceso ni siquiera arranca. |
| **🧱 Suministro de "Ladrillos"** | **CORTADO** ⬇️ | **`RRM2`** (-2.49)<br>**`TYMS`** (-0.96)<br>**`TK1`** (-1.34) | **Sin Materiales:** `RRM2` es la enzima que fabrica los nucleótidos (las letras del ADN). Al estar tan baja, la célula se queda sin "tinta" para copiar el genoma. Es un cuello de botella brutal. |
| **⚙️ El Motor de Copiado** | **APAGADO** ⬇️ | **`MCM10`** (-2.64)<br>**`MCM2-7`** (~ -2.0)<br>**`PCNA`** (-1.58)<br>**`POLE`** (-1.90) | **Helicasa Detenida:** El complejo MCM es el motor que abre la doble hélice. `PCNA` es la abrazadera que sujeta la polimerasa. Todo el equipo de replicación ha sido desmantelado. |
| **🔧 Reparación del ADN** | **SUPRIMIDA** ⬇️ | **`BRCA1`** (-1.96)<br>**`BRCA2`** (-2.28)<br>**`RAD51`** (-2.07)<br>**`FANCD2`** (-1.50) | **Fallo en Homología:** Es paradójico pero lógico. Como la célula no replica, apaga la maquinaria de Reparación por Recombinación Homóloga (HR). Esto induce un estado de fragilidad genómica ("brittleness"). |
| **🏗️ Estructura Mitótica** | **COLAPSADA** ⬇️ | **`AURKB`** (-2.29)<br>**`PLK1`** (-1.80)<br>**`CDK1`** (-2.35)<br>**`BUB1`** (-1.68) | **Sin División:** Aurora B y PLK1 son los generales de la mitosis. Su ausencia total confirma que las células no están entrando en fase M. |
| **🚂 Motores Moleculares** | **MASACRADOS** ⬇️ | **`KIFC1`** (-2.44)<br>**`KIF11`** (-1.89)<br>**`KIF18A/B`** (~ -2.0)<br>**`KIF14/15`** | **Transporte Parado:** Las Kinesinas (KIF) mueven los cromosomas. Se observa la represión coordinada de más de 15 kinesinas, impidiendo la formación del huso mitótico. |
| **🎯 Centrómero y Cinetocoro** | **DESMANTELADO** ⬇️ | **`CENPA`** (-2.05)<br>**`CENPE`** (-1.57)<br>**`CENPF`** (-1.74)<br>**`NDC80`** (-1.81) | **Pérdida de Identidad:** `CENPA` define el centro del cromosoma y `NDC80` es el gancho del microtúbulo. Su caída indica una pérdida de la integridad cromosómica estructural. |

</details>

---

<details>
<summary><strong>B. Resultados Obtenidos (Validación del Pipeline)</strong></summary>
<br>

El análisis de los datos generados por **OmniRNA-seq** muestra una recapitulación precisa del fenotipo descrito. La siguiente tabla compara los niveles de expresión (**Log2 Fold Change**) obtenidos en las dos réplicas biológicas independientes, siguiendo la misma estructura biológica que el estudio de referencia:

| Gen | Función Biológica | siRNA-01 (Log2FC) | siRNA-02 (Log2FC) | Interpretación del Resultado |
| :--- | :--- | :--- | :--- | :--- |
| **`CDKN1A` (p21)** | **El Freno del Ciclo (Crucial)** | **+1.12** | **+1.29** | 🔴 **STOP ACTIVADO.** Ambos suben >1 log. Bloqueo total. |
| **`MDM2`** | Marcador de p53 activo | **+0.97** | **+1.16** | ⬆️ p53 está gritando en ambos casos. |
| **`FAS`** | Receptor de Muerte | **+1.01** | **-** | ⚠️ *Nota:* Solo significativo en el 01. Sugiere que el 01 es un pelín más tóxico/apoptótico que el 02. |
| **`CDC6`** | Licencia de Replicación | **-2.61** | **-2.49** | 📉 **El gen más reprimido.** No hay replicación de ADN. |
| **`RRM2`** | Fábrica de Nucleótidos | **-2.49** | **-2.25** | 📉 Sin "ladrillos" para el ADN. Cuello de botella total. |
| **`PCNA`** | Abrazadera del ADN | **-1.58** | **-1.77** | 📉 Maquinaria de replicación desmontada. |
| **`MCM4`** | Helicasa (Abre ADN) | **-2.28** | **-2.22** | 📉 Idéntico. La hélice no se abre. |
| **`BRCA1`** | Reparación ADN | **-1.96** | **-1.77** | 📉 Sensibilidad extrema a daño en el ADN. |
| **`RAD51`** | Recombinación Homóloga | **-2.07** | **-2.08** | 📉 Calcadísimo. La reparación está anulada. |
| **`AURKB`** | **Director de la Mitosis** | **-2.29** | **-2.10** | 📉 **Colapso.** Sin esto no hay división celular. |
| **`PLK1`** | Entrada en Mitosis | **-1.80** | **-1.76** | 📉 Bajada idéntica en ambos. Muy robusto. |
| **`CDK1`** | Motor principal Fase M | **-2.36** | **-2.09** | 📉 La quinasa maestra está apagada. |
| **`KIFC1`** | Motor de Microtúbulos | **-2.44** | **-2.04** | 📉 Masacre de kinesinas confirmada en ambos. |
| **`KIF11`** | Kinesina Eg5 (Huso) | **-1.89** | **-1.75** | 📉 El huso mitótico no se puede formar. |
| **`KIF4A`** | Kinesina Cromosómica | **-1.63** | **-1.51** | 📉 Problemas de compactación y movimiento. |

#### 📝 Interpretación Biológica de los Resultados

Los datos revelan una respuesta celular altamente conservada ante la pérdida de DDX21. En primer lugar, se observa una **activación transcripcional robusta del eje p53-p21** (*MDM2, CDKN1A*), que actúa como el evento iniciador ("gatillo") del arresto del ciclo celular. Esta señal de freno provoca, en consecuencia, un **colapso transcripcional masivo** de toda la maquinaria necesaria para la proliferación: desde los factores de "licencia" de la replicación en fase S (*CDC6, RRM2, MCMs*) hasta los componentes estructurales y motores de la mitosis (*AURKB, PLK1, Kinesinas*). La consistencia cuantitativa de los valores Log2FC entre ambas réplicas (siRNA-01 y siRNA-02) valida la precisión del pipeline para caracterizar fenotipos complejos de parada del crecimiento.

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
