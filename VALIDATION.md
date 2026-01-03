## 📊 Resultados Interactivos y Reportes Generados

La validación experimental se completa con un conjunto de **artefactos visuales e interactivos** generados automáticamente por *OmniRNA-seq*.  
Estos outputs permiten explorar los datos desde distintos niveles de abstracción, combinando **estadística**, **visualización interactiva** e **interpretación funcional**.

Los resultados se estructuran en cuatro capas complementarias:

- **Análisis estadístico diferencial** (Volcano Plots interactivos)
- **Exploración transcriptómica integrada** (Dashboards HTML)
- **Documentación reproducible** (Reportes PDF completos)
- **Interpretación funcional** (Gene Ontology y rutas KEGG con Pathview)

---

### 🔴 Volcano Plots (Interactivos)

Los volcano plots interactivos permiten inspeccionar de forma dinámica la relación entre magnitud del cambio de expresión (*log2FC*) y significación estadística (*−log10 adj-p*), facilitando la identificación de genes clave implicados en el arresto del ciclo celular y el estrés ribosomal.

<div align="center">
<table style="border:none;border-collapse:collapse;">
<tr>
<td align="center" width="50%">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/VolcanoPlot_Dashboard_siRNA_01_vs_Control.html" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/volcanoplot_int1.png" width="340">
</a>
<br><sub><b>siRNA 01 vs Control</b></sub>
</td>

<td align="center" width="50%">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/VolcanoPlot_Dashboard_siRNA_02_vs_Control.html" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/volcanoplot_int2.png" width="340">
</a>
<br><sub><b>siRNA 02 vs Control</b></sub>
</td>
</tr>
</table>
</div>

---

### 🟢 Dashboards Transcriptómicos Integrados

Los dashboards HTML constituyen el **núcleo exploratorio** del pipeline.  
Cada dashboard integra en una única interfaz:

- Listados completos de **genes diferencialmente expresados (DEGs)**
- Estadística detallada (log2FC, p-value, adjusted p-value)
- Visualizaciones interactivas y rankings
- **Interpretación funcional automatizada**
- **Visualización de rutas biológicas mediante Pathview**, permitiendo mapear los cambios de expresión directamente sobre rutas KEGG relevantes (replicación del ADN, checkpoint mitótico, etc.)

<div align="center">
<table style="border:none;border-collapse:collapse;">
<tr>
<td align="center" width="50%">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Interactivo_siRNA_01_vs_Control.html" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/dashboard1.png" width="340">
</a>
<br><sub><b>Dashboard Funcional — siRNA 01</b></sub>
</td>

<td align="center" width="50%">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Interactivo_siRNA_02_vs_Control.html" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/dashboard2.png" width="340">
</a>
<br><sub><b>Dashboard Funcional — siRNA 02</b></sub>
</td>
</tr>
</table>
</div>

---

### 🟣 Reportes Transcriptómicos Completos (PDF)

Los reportes PDF proporcionan una **documentación estática, reproducible y portable** del análisis, adecuada para revisión externa, archivo o material suplementario.

Cada informe incluye:
- Resumen estadístico global del contraste
- Top DEGs y métricas asociadas
- Enriquecimiento funcional (GO y rutas)
- Figuras clave generadas automáticamente
- Interpretación biológica coherente con el estudio de referencia

<div align="center">
<table style="border:none;border-collapse:collapse;">
<tr>
<td align="center" width="50%">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Transcriptomica_Completo_siRNA_01_vs_Control.pdf" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/gProf1.png" width="300">
</a>
<br><sub><b>Reporte Completo — siRNA 01</b></sub>
</td>

<td align="center" width="50%">
<a href="https://SergioGarciaDiaz97.github.io/OmniRNA-seq/Resultados/Modo_local/Informe_Transcriptomica_Completo_siRNA_02_vs_Control.pdf" target="_blank">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/gProf2.png" width="300">
</a>
<br><sub><b>Reporte Completo — siRNA 02</b></sub>
</td>
</tr>
</table>
</div>

---

### 🧬 Enriquecimiento Funcional — Gene Ontology

El análisis funcional confirma que los efectos transcriptómicos del KD de **DDX21** convergen en procesos altamente coherentes con la biología esperada.

#### siRNA 01

<div align="center">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/bp1.png" width="320">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/cc1.png" width="320">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mg1.png" width="320">
</div>

#### siRNA 02

<div align="center">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/bp2.png" width="320">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/cc2.png" width="320">
<img src="https://raw.githubusercontent.com/SergioGarciaDiaz97/OmniRNA-seq/main/assets/mf2.png" width="320">
</div>

<p align="center"><em>
La concordancia funcional entre ambos siRNAs refuerza la robustez del pipeline y la validez biológica de los resultados.
</em></p>
