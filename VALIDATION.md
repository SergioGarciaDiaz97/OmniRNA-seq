# 🧪 Informe de Validación Experimental: OmniRNA-seq

[⬅️ **Volver al Repositorio Principal (README.md)**](./README.md)

Este documento documenta la ejecución del pipeline en **escenarios biológicos reales**. Cada caso de estudio representa una configuración distinta del archivo de control JSON, diseñada para validar la versatilidad del software y su precisión biológica.

> **📂 Acceso a Resultados Brutos** > Al final de cada sección encontrará enlaces directos a los **reportes interactivos HTML y documentos PDF** generados automáticamente por el pipeline.

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
- **⚗️ Diseño Experimental:** Contrastes estadísticos robustos: `siRNA_01_vs_Control` y `siRNA_02_vs_Control`.

---

<details open>
<summary><strong>A. Contexto y Expectativas (Estudio de Referencia)</strong></summary>
<br>

El estudio de referencia demuestra que **DDX21** es crítica para la biogénesis ribosomal. Su ausencia desencadena una cascada de señalización específica que culmina en el arresto del ciclo celular. A continuación, se detalla la **firma molecular esperada** basada en los hallazgos biológicos descritos en la literatura. Entre ellos destacan:

| Sistema Biológico | Estado | Genes Afectados (LogFC) | Hallazgo Biológico (Interpretación) |
| :--- | :--- | :--- | :--- |
| **🚨 EL GATILLO (p53/p21)** | **ACTIVADO** ⬆️ | **CDKN1A (p21)** (+1.12)<br>**MDM2** (+0.97)<br>**FAS** (+1.01)<br>**BTG2** (+0.90) | **La Causa Raíz:** El estrés ribosomal activa p53, que a su vez dispara **p21**. p21 es el inhibidor universal de las quinasas del ciclo. Es el "freno de mano" que provoca todo lo demás. |
| **🏁 Inicio de Replicación** | **BLOQUEADO** ⬇️ | **CDC6** (-2.61)<br>**CDT1** (-2.41)<br>**ORC1** (-1.90)<br>**ORC6** (-2.11) | **Licencia Denegada:** Estos genes forman el "complejo de pre-replicación". Sin CDC6 ni CDT1, la célula no puede marcar dónde empezar a copiar el ADN. El proceso ni siquiera arranca. |
| **🧱 Suministro de "Ladrillos"** | **CORTADO** ⬇️ | **RRM2** (-2.49)<br>**TYMS** (-0.96)<br>**TK1** (-1.34) | **Sin Materiales:** RRM2 es la enzima limitante que fabrica los nucleótidos. Al estar tan baja, la célula se queda sin "tinta" para copiar el genoma. Es un cuello de botella brutal. |
| **⚙️ El Motor de Copiado** | **APAGADO** ⬇️ | **MCM10** (-2.64)<br>**MCM2-7** (~ -2.0)<br>**PCNA** (-1.58)<br>**POLE** (-1.90) | **Helicasa Detenida:** El complejo MCM es el motor que abre la doble hélice. PCNA es la abrazadera que sujeta la polimerasa. Todo el equipo de replicación ha sido desmantelado. |
| **🔧 Reparación del ADN** | **SUPRIMIDA** ⬇️ | **BRCA1** (-1.96)<br>**BRCA2** (-2.28)<br>**RAD51** (-2.07)<br>**FANCD2** (-1.50) | **Fallo en Homología:** Como la célula no replica, apaga la maquinaria de Reparación por Recombinación Homóloga (HR). Esto induce un estado de fragilidad genómica ("brittleness"). |
| **🏗️ Estructura Mitótica** | **COLAPSADA** ⬇️ | **AURKB** (-2.29)<br>**PLK1** (-1.80)<br>**CDK1** (-2.35)<br>**BUB1** (-1.68) | **Sin División:** Aurora B y PLK1 son los generales de la mitosis. Su ausencia total confirma que las células no están entrando en fase M. |
| **🚂 Motores Moleculares** | **MASACRADOS** ⬇️ | **KIFC1** (-2.44)<br>**KIF11** (-1.89)<br>**KIF18A/B** (~ -2.0)<br>**KIF14/15** | **Transporte Parado:** Las Kinesinas (KIF) mueven los cromosomas. Se observa la represión coordinada de más de 15 kinesinas, impidiendo la formación del huso mitótico. |
| **🎯 Centrómero y Cinetocoro** | **DESMANTELADO** ⬇️ | **CENPA** (-2.05)<br>**CENPE** (-1.57)<br>**CENPF** (-1.74)<br>**NDC80** (-1.81) | **Pérdida de Identidad:** CENPA define el centro del cromosoma y NDC80 es el gancho del microtúbulo. Su caída indica una pérdida de la integridad cromosómica estructural. |

</details>

---

<details>
<summary><strong>B. Resultados Obtenidos (Validación del Pipeline)</strong></summary>
<br>

El análisis de expresión diferencial realizado por **OmniRNA-seq** capturó con éxito la firma transcriptómica de arresto celular. A continuación se presentan los valores obtenidos para cada réplica (siRNA-01 y siRNA-02):

| Gen | Función Biológica | siRNA-01 (Log2FC) | siRNA-02 (Log2FC) | Interpretación |
| :--- | :--- | :--- | :--- | :--- |
| **CDKN1A (p21)** | **El Freno del Ciclo** | **+1.178** | **+1.287** | 🔴 **STOP ACTIVADO.** Bloqueo total consistente. |
| **MDM2** | Marcador de p53 activo | **+1.043** | **+1.159** | ⬆️ Respuesta a estrés nucleolar confirmada. |
| **FAS** | Receptor de Muerte | **+1.355** | **-** | siRNA-01 muestra activación apoptótica. |
| **BTG2** | Anti-proliferación | **+1.094** | **-** | Gen de parada de ciclo capturado por siRNA-01. |
| **CDC6** | Licencia Replicación | **-2.631** | **-2.490** | 📉 **Colapso.** La replicación no puede iniciar. |
| **CDT1** | Licencia Replicación | **-2.476** | **-2.358** | 📉 Ausencia de marcadores de origen de replicación. |
| **ORC1** | Origen Replicación | **-2.127** | **-1.843** | 📉 Complejo de replicación desmantelado. |
| **ORC6** | Origen Replicación | **-2.098** | **-1.796** | 📉 Coherente con fallo en fase S. |
| **RRM2** | Síntesis Nucleótidos | **-2.584** | **-2.254** | 📉 **Cuello de botella.** Sin sustrato para ADN. |
| **TK1** | Síntesis Nucleótidos | **-1.089** | **-1.446** | 📉 Enzima clave de síntesis reprimida. |
| **MCM10** | Iniciación Replicación | **-2.840** | **-2.433** | 📉 Helicasa bloqueada. |
| **PCNA** | Abrazadera del ADN | **-1.774** | **-1.372** | 📉 Polimerasa incapaz de mantenerse en el ADN. |
| **POLE** | Polimerasa Epsilon | **-1.815** | **-2.215** | 📉 Apagado coordinado de la copia de ADN. |
| **BRCA1** | Reparación ADN | **-2.142** | **-1.766** | 📉 **Fragilidad Genómica.** |
| **BRCA2** | Reparación ADN | **-2.534** | **-1.944** | 📉 Pérdida de la vía de homología. |
| **RAD51** | Recombinación HR | **-1.683** | **-2.077** | 📉 Maquinaria de reparación inactiva. |
| **FANCD2** | Vía Fanconi | **-1.257** | **-1.681** | 📉 Fallo en la protección de la horquilla. |
| **AURKB** | **Director de la Mitosis** | **-2.243** | **-2.095** | 📉 **Fallo Mitótico.** Colapso de Aurora B. |
| **PLK1** | Entrada en Mitosis | **-1.813** | **-1.760** | 📉 Inhibición de la entrada en fase M. |
| **CDK1** | Quinasa Fase M | **-2.611** | **-2.088** | 📉 Motor principal de la mitosis detenido. |
| **BUB1** | Checkpoint Mitótico | **-1.724** | **-1.427** | 📉 Fallo en el ensamblaje del huso. |
| **KIFC1** | Motor Microtúbulos | **-2.633** | **-2.040** | 📉 Masacre de kinesinas motoras. |
| **KIF11** | Kinesina Eg5 (Huso) | **-1.836** | **-1.751** | 📉 Incapacidad de formar huso bipolar. |
| **KIF18A** | Kinesina Alineación | **-2.532** | **-2.437** | 📉 Cromosomas fuera de placa ecuatorial. |
| **KIF14** | Kinesina de División | **-1.602** | **-1.556** | 📉 Fallo en la fase final de división. |
| **KIF15** | Kinesina de Soporte | **-2.180** | **-1.624** | 📉 Inestabilidad estructural del huso. |
| **CENPA** | Identidad Centrómero | **-2.294** | **-1.689** | 📉 Centrómero desmantelado. |
| **CENPE** | Motor Cinetocoro | **-1.592** | **-1.289** | 📉 Fallo en enganche de microtúbulos. |
| **CENPF** | Proteína Cinetocoro | **-1.666** | **-1.603** | 📉 Inestabilidad de la unión ADN-Huso. |
| **NDC80** | Cinetocoro Externo | **-1.886** | **-1.581** | 📉 Pérdida estructural del gancho mitótico. |

#### 📝 Interpretación Biológica de los Resultados

Los datos revelan una **respuesta celular altamente coordinada y masiva** ante la pérdida de DDX21. El pipeline detectó con precisión el evento iniciador: la **activación del eje p53-p21** (subida de *CDKN1A* y *MDM2*), que funciona como el gatillo del arresto celular. Esta señal provoca un efecto cascada de represión sobre dos pilares vitales: 
1. **Fase S:** El colapso absoluto de la replicación del ADN, evidenciado por la bajada de licencias de origen (*CDC6, CDT1*) y el desmantelamiento de la helicasa (*MCM10*) y polimerasas (*POLE*).
2. **Fase M:** Un desmantelamiento estructural de la mitosis, caracterizado por la **"masacre de kinesinas"** (represión de múltiples *KIFs*) y la pérdida de integridad en el centrómero (*CENPA, NDC80*). 

La extrema consistencia en los valores Log2FC entre siRNA-01 y siRNA-02 valida la capacidad de **OmniRNA-seq** para reproducir biología de alta complejidad con rigor estadístico.

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
    <img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mf1.png" width="240">
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
