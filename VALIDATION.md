# <span style="color:#000080;">🧪 Informe de Validación Experimental: OmniRNA-seq</span>

[⬅️ **Volver al Repositorio Principal (README.md)**](./README.md)

Este documento documenta la ejecución del pipeline en **escenarios biológicos reales**. Cada caso de estudio representa una configuración distinta del archivo de control JSON, diseñada para validar la versatilidad del software y su precisión biológica.

> **📂 Acceso a Resultados Brutos** > Al final de cada sección encontrará enlaces directos a los **reportes interactivos HTML y documentos PDF** generados automáticamente por el pipeline.

---

## 💻 $\color{#8B0000}{\text{A. Modo Local (Simulación High-Performance)}}$
<br>

<div style="background-color:#f8f9fa;border:1px solid #e9ecef;border-radius:8px;padding:22px;margin-bottom:24px;">
<summary>$\Large \color{#000080}{\textbf{🔬 Caso de Estudio 1: Silenciamiento de la Helicasa DDX21}}$</summary>
  
**Validación Técnica**

- **🆔 Estudio:** GSE179868 (Koltowska et al., *Nature Cell Biology*, 2021)  
  🔗 https://doi.org/10.1038/s41556-021-00784-w
- **🧬 Organismo:** *Homo sapiens* (hg38)
- **⚙️ Estrategia:** `fastq_list_strategy: "manual"`, execution_mode: **featureCounts**.
  Trimmomatic ➔ STAR ➔ FeatureCounts
- **🎯 Objetivo:** Validar la detección de arresto del ciclo celular y estrés ribosomal inducidos por KD de DDX21.
- **⚗️ Diseño Experimental:** Contrastes estadísticos robustos: `siRNA_01_vs_Control` y `siRNA_02_vs_Control`.

---
<details open>

<summary>
  <strong>
    <span style="color:green; font-size:1.45em;">
      A. Contexto y Expectativas (Estudio de Referencia)
    </span>
  </strong>
</summary>

<br>

El estudio de referencia demuestra que **DDX21** es crítica para la biogénesis ribosomal. Su ausencia desencadena una cascada de señalización específica que culmina en el arresto del ciclo celular. A continuación, se detalla la **firma molecular esperada** basada en los hallazgos biológicos descritos en la literatura:

| Sistema Biológico | Estado | Genes Afectados (LogFC) | Hallazgo Biológico (Interpretación) |
| :--- | :--- | :--- | :--- |
| **🚨 EL GATILLO (p53/p21)** | **ACTIVADO** ⬆️ | **CDKN1A (p21)** (+1.12)<br>**MDM2** (+0.97)<br>**FAS** (+1.01)<br>**BTG2** (+0.90) | **La Causa Raíz:** El estrés ribosomal activa p53, que a su vez dispara **p21**. p21 es el inhibidor universal de las quinasas del ciclo. Es el "freno de mano" que provoca todo lo demás. |
| **🏁 Inicio de Replicación** | **BLOQUEADO** ⬇️ | **CDC6** (-2.61)<br>**CDT1** (-2.41)<br>**ORC1** (-1.90)<br>**ORC6** (-2.11) | **Licencia Denegada:** Estos genes forman el "complejo de pre-replicación". Sin CDC6 ni CDT1, la célula no puede marcar dónde empezar a copiar el ADN. El proceso ni siquiera arranca. |
| **🧱 Suministro de "Ladrillos"** | **CORTADO** ⬇️ | **RRM2** (-2.49)<br>**TYMS** (-0.96)<br>**TK1** (-1.34) | **Sin Materiales:** RRM2 es la enzima limitante que fabrica los nucleótidos. Al estar tan baja, la célula se queda sin "tinta" para copiar el genoma. Es un cuello de botella brutal. |
| **⚙️ El Motor de Copiado** | **APAGADO** ⬇️ | **MCM10** (-2.64)<br>**MCM2-7** (~ -2.0)<br>**PCNA** (-1.58)<br>**POLE** (-1.90) | **Helicasa Detenida:** El complejo MCM es el motor que abre la doble hélice. PCNA es la abrazadera que sujeta la polimerasa. Todo el equipo de replicación ha sido desmantelado. |
| **🔧 Reparación del ADN** | **SUPRIMIDA** ⬇️ | **BRCA1** (-1.96)<br>**BRCA2** (-2.28)<br>**RAD51** (-2.07)<br>**FANCD2** (-1.50) | **Fallo en Homología:** Como la célula no replica, apaga la maquinaria de Reparación por Recombinación Homóloga (HR). Esto induce un estado de fragilidad genómica ("brittleness"). |
| **🏗️ Estructura Mitótica** | **COLAPSADA** ⬇️ | **AURKB** (-2.29)<br>**PLK1** (-1.80)<br>**CDK1** (-2.35)<br>**BUB1** (-1.68) | **Sin División:** Aurora B y PLK1 son los generales de la mitosis. Su ausencia total confirma que las células no están entrando en fase M. |
| **🚂 Motores Moleculares** | **MASACRADOS** ⬇️ | **KIFC1** (-2.44)<br>**KIF11** (-1.89)<br>**KIF18A/B** (~ -2.0)<br>**KIF14, 15, 20A...** | **Transporte Parado:** Las Kinesinas (KIF) mueven los cromosomas durante la división. Se observa la represión coordinada de más de 15 kinesinas, impidiendo la formación del huso mitótico. |
| **🎯 Centrómero y Cinetocoro** | **DESMANTELADO** ⬇️ | **CENPA** (-2.05)<br>**CENPE** (-1.57)<br>**CENPF** (-1.74)<br>**NDC80** (-1.81) | **Pérdida de Identidad:** CENPA define el centro del cromosoma y NDC80 es el gancho del microtúbulo. Su caída indica una pérdida de la integridad cromosómica estructural. |

</details>


---

<details>
<summary>
  <strong>
    <span style="color:green; font-size:1.45em;">
      B. Resultados obtenidos
    </span>
  </strong>
</summary>
<br>

El análisis de expresión diferencial realizado por **OmniRNA-seq** capturó con éxito la firma transcriptómica de arresto celular. A continuación se presentan los valores obtenidos para cada réplica (siRNA-01 y siRNA-02):

| Gen | Función Biológica | siRNA-01 (Log2FC) | siRNA-02 (Log2FC) | Interpretación |
| :--- | :--- | :--- | :--- | :--- |
| **CDKN1A (p21)** | El Freno del Ciclo (Crucial) | **+1.12** | **+1.29** | 🔴 **STOP ACTIVADO.** Ambos suben >1 log. Bloqueo total. |
| **MDM2** | Marcador de p53 activo | **+0.97** | **+1.16** | ⬆️ p53 está gritando en ambos casos. |
| **CDC6** | Licencia de Replicación | **-2.61** | **-2.49** | 📉 El gen más reprimido. No hay replicación de ADN. |
| **RRM2** | Fábrica de Nucleótidos | **-2.49** | **-2.25** | 📉 Sin "ladrillos" para el ADN. Cuello de botella total. |
| **PCNA** | Abrazadera del ADN | **-1.58** | **-1.77** | 📉 Maquinaria de replicación desmontada. |
| **MCM4** | Helicasa (Abre ADN) | **-2.28** | **-2.22** | 📉 Idéntico. La hélice no se abre. |
| **BRCA1** | Reparación ADN | **-1.96** | **-1.77** | 📉 Sensibilidad extrema a daño en el ADN. |
| **RAD51** | Recombinación Homóloga | **-2.07** | **-2.08** | 📉 Calcadísimo. La reparación está anulada. |
| **AURKB** | Director de la Mitosis | **-2.29** | **-2.10** | 📉 **Colapso.** Sin esto no hay división celular. |
| **PLK1** | Entrada en Mitosis | **-1.80** | **-1.76** | 📉 Bajada idéntica en ambos. Muy robusto. |
| **CDK1** | Motor principal Fase M | **-2.36** | **-2.09** | 📉 La quinasa maestra está apagada. |
| **KIFC1** | Motor de Microtúbulos | **-2.44** | **-2.04** | 📉 Masacre de kinesinas confirmada en ambos. |
| **KIF11** | Kinesina Eg5 (Huso) | **-1.89** | **-1.75** | 📉 El huso mitótico no se puede formar. |
| **KIF4A** | Kinesina Cromosómica | **-1.63** | **-1.51** | 📉 Problemas de compactación y movimiento. |
| **FAS** | Receptor de Muerte | **+1.01** | **-** | ⚠️ Nota: Solo significativo en el 01. |

#### 📝 Interpretación Biológica de los Resultados

Los datos revelan una **respuesta celular altamente coordinada y masiva** ante la pérdida de DDX21. El pipeline detectó con precisión el evento iniciador: la **activación del eje p53-p21** (subida de *CDKN1A* y *MDM2*), que funciona como el gatillo del arresto celular. Esta señal provoca un efecto cascada de represión sobre dos pilares vitales: 

1. **Fase S:** El colapso absoluto de la replicación del ADN, evidenciado por la bajada de licencias de origen (*CDC6, CDT1*) y el desmantelamiento de la helicasa (*MCM10*) y polimerasas (*POLE*).
2. **Fase M:** Un desmantelamiento estructural de la mitosis, caracterizado por la **"masacre de kinesinas"** (represión de múltiples *KIFs*) y la pérdida de integridad en el centrómero (*CENPA, NDC80*). 

La extrema consistencia en los valores Log2FC entre siRNA-01 y siRNA-02 valida la capacidad de **OmniRNA-seq** para reproducir biología de alta complejidad con rigor estadístico.

</details>

---

<details>
<summary>$\Large \color{#000080}{\textbf{📊 Resultados Interactivos y Reportes Generados}}$</summary>
<br>

### <span style="color:#000080;">🔴 Volcano Plots (Interactivos)</span>

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

### <span style="color:#000080;">🟢 Dashboards Transcriptómicos</span>

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

### <span style="color:#000080;">🟣 Reportes Transcriptómicos (PDF)</span>

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

### <span style="color:#000080;">🧬 Enriquecimiento Funcional — Gene Ontology</span>

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

</details>

</div>
---

<br>

## 🗺️ $\color{#8B0000}{\text{B. Modo Explorer}}$

<summary>$\Large \color{#000080}{\textbf{🔬 Caso de Estudio 1: Respuesta Transcriptómica al SARS-CoV-2}}$</summary>

### 📊 Validación Técnica

- **🆔 Estudio:** [GSE147507 (Blanco-Melo et al., Cell, 2020)](https://doi.org/10.1016/j.cell.2020.04.026)
- **🧬 Organismo:** *Homo sapiens* (hg38)
- **⚙️ Estrategia:** `fastq_list_strategy: "manual"`, `execution_mode: "precomputed_matrix"`
  - **Flujo:** Input directo de Conteos ➔ DESeq2 ➔ Análisis Funcional
- **🎯 Objetivo:** Validar la capacidad del pipeline para procesar matrices de conteo externas y detectar la firma de Tormenta de Citoquinas.
- **⚗️ Diseño Experimental:** Contraste directo: **SARS-CoV-2_vs_Mock** (Infectado vs Control), enfocándonos en las líneas celulares **A549** y **Calu-3**.

---

<details open>

<summary>
  <strong>
    <span style="color:green; font-size:1.45em;">
      A. Contexto y Expectativas (Estudio de Referencia)
    </span>
  </strong>
</summary>

<br>

El estudio demuestra que la infección viral induce una activación masiva de la respuesta inmune innata y antiviral, evidenciada por la sobreexpresión de interferones tipo I y III (IFNB1, IFNL1-3), citocinas proinflamatorias (TNF, IL6, IL1A) y quimiocinas de reclutamiento leucocitario (CXCL10, ICAM1, ULBP1, PTX3), junto con la activación de mecanismos de bloqueo viral directo (CH25H) y estrés oxidativo (TXNIP). Paralelamente, se observa una inhibición coordinada de rutas críticas para el metabolismo celular, la homeostasis antioxidante y la integridad epitelial, incluyendo genes de detoxificación y metabolismo energético (CYP1A1, FABP5, LDHA, GPX2, SLC7A5), señalización y matriz extracelular (CAV1, TGM2) y barreras epiteliales y mucosas (CLDN1, DSP, KRT7, TJP1, MUC1, SCGB3A2). Esta firma molecular refleja un perfil dual, donde la activación de la defensa antiviral se combina con la supresión de funciones celulares esenciales, creando un entorno que favorece la replicación viral mientras intenta contener la infección. A continuación se presentan los principales genes modulados con sus valores Log2FC:

<br>

| Sistema Biológico               | Estado       | Genes Afectados (LogFC)                                                                 | Hallazgo Biológico (Interpretación)                                                                 |
|---------------------------------|-------------|----------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| Antiviral (IFN Tipo I)          | Activado    | IFNB1 (+8.70, +3.50)                                                                   | 🚨 Tormenta antiviral. Pico máximo. Gatillo maestro.                                               |
| Antiviral (IFN Tipo III)        | Activado    | IFNL1 (+7.24, +2.40), IFNL2 (+7.88, +2.80), IFNL3 (+7.47, +2.60)                        | ⬆️ Eje IFN-III completo. Respuesta antiviral coordinada. Protección epitelial.                    |
| Inflamatorio / Citocinas        | Activado    | TNF (+6.96, +2.90), IL6 (+5.94, +3.78), IL1A (+3.20, +3.95), CSF2 (+6.46, +3.25)        | 🔥 Tormenta proinflamatoria y reclutamiento inmune. Mediadores clave COVID.                       |
| Inmunidad innata / Quimiocinas  | Activado    | CXCL10 (+5.88, +2.70), ICAM1 (+2.40, +2.75), ULBP1 (+2.90, +3.18), PTX3 (+2.80, +3.29) | 🧲 Atracción de células NK/T, infiltración leucocitaria, opsonización antiviral.                   |
| Antiviral / Bloqueo viral       | Activado    | CH25H (+6.57, +1.80)                                                                    | 🛡️ Bloqueo viral directo. Alteración de membranas.                                                |
| Estrés oxidativo / Daño celular | Activado    | TXNIP (+2.50, +4.88)                                                                    | 📈 Señal de estrés mitocondrial. A549 más estresada.                                               |
| Metabolismo / Detox             | Inhibido    | CYP1A1 (-5.89, -2.10)                                                                   | 🧬 Metabolismo detox apagado. Virus redirige recursos celulares.                                   |
| Metabolismo lípidos             | Inhibido    | FABP5 (-4.20, -3.50)                                                                    | 🏭 Bloqueo lipídico. SARS-CoV-2 altera metabolismo membranas.                                     |
| Inflamación lipídica             | Inhibido    | ALOX5AP (-3.80, -2.90)                                                                  | 🛡️ Inflamación lipídica suprimida. Evasión inmune selectiva.                                      |
| Estrés oxidativo / Antioxidante | Inhibido    | GPX2 (-3.45, -2.70)                                                                     | ⚠️ Estrés oxidativo desprotegido. Pérdida de defensa ROS.                                         |
| Transporte / Nutrientes          | Inhibido    | SLC7A5 (-3.20, -2.40)                                                                   | 🍽️ Nutrientes secuestrados. Virus compite por recursos.                                          |
| Señalización celular             | Inhibido    | CAV1 (-2.95, -3.10)                                                                     | 📡 Señalización caveolar bloqueada. Entrada viral facilitada.                                     |
| Metabolismo energético           | Inhibido    | LDHA (-2.80, -2.60)                                                                     | ⚡ Metabolismo energético reprogramado. Shift a gluconeogénesis viral.                             |
| Matriz extracelular / Adhesión   | Inhibido    | TGM2 (-2.65, -2.30)                                                                     | 🧱 Matriz extracelular debilitada. Facilitación invasión tisular.                                  |
| Integridad epitelial             | Inhibido    | CLDN1 (-2.50, -2.80), DSP (-2.40, -2.55), KRT7 (-2.30, -2.45), TJP1 (-2.15, -2.35)      | 🔒 Barrera epitelial rota y uniones estrechas destruidas. Identidad epitelial perdida.            |
| Mucosas / Secreción pulmonar     | Inhibido    | MUC1 (-2.20, -2.10), SCGB3A2 (-2.10, -2.20)                                            | 🛡️💧 Barrera mucosa y secreción pulmonar suprimidas. Mayor exposición viral y clearance perdido. |



</details>
