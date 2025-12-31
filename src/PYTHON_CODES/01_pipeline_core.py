import os
import subprocess
import argparse
import json
import shutil
import gzip
import logging
import pandas as pd
import re
import csv
import concurrent.futures
import multiprocessing
from functools import partial
from collections import defaultdict

# ==============================================================================
# SECCIÓN 1: FUNCIONES AUXILIARES Y DE CONFIGURACIÓN
# ==============================================================================

def setup_logging(log_file):
    """Configura el sistema de logging para guardar en un archivo y mostrar en consola."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] - %(message)s",
        handlers=[
            logging.FileHandler(log_file, mode='w'),
            logging.StreamHandler()
        ]
    )

def create_directory(path):
    """Crea un directorio si no existe."""
    if not os.path.exists(path):
        os.makedirs(path)
        logging.info(f"📁 Carpeta creada: {path}")


def read_urls_from_file(file_path):
    """Lee una lista de URLs desde un archivo de texto, una por línea."""
    try:
        with open(file_path, 'r') as f:
            urls = [line.strip() for line in f if line.strip()]
        logging.info(f"✅ Leídas {len(urls)} URLs desde {file_path}")
        return urls
    except FileNotFoundError:
        logging.error(f"❌ No se encontró el archivo de lista de FASTQs: {file_path}"); exit(1)

def run_parallel_downloads(urls, destination_dir, max_workers):
    if not urls: logging.info(f"🤷 No hay URLs para descargar en {os.path.basename(destination_dir)}. Saltando."); return
    logging.info(f"⬇️  Iniciando descarga de {len(urls)} archivos en {os.path.basename(destination_dir)} con {max_workers} hilos...")
    def download_worker(url):
        filename = os.path.basename(url)
        filepath = os.path.join(destination_dir, filename)
        uncompressed_path = filepath[:-3] if filepath.endswith(".gz") else filepath
        if os.path.exists(uncompressed_path) or os.path.exists(filepath): return ('SALTADO', filename)
        try:
            subprocess.run(["wget", "-q", "-P", destination_dir, url], check=True, capture_output=True, text=True)
            return ('OK', filename)
        except subprocess.CalledProcessError as e:
            logging.warning(f"⚠️  Error descargando {filename}: {e.stderr.strip()}."); return ('ERROR', filename)

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        results = list(executor.map(download_worker, urls))
    
    skipped_files = [f for status, f in results if status == 'SALTADO']
    if skipped_files: logging.info(f"  -> 📝 {len(skipped_files)} archivos saltados (ya existían) en {os.path.basename(destination_dir)}.")

def unzip_single_file(gz_path):
    out_path = gz_path[:-3]
    if os.path.exists(out_path):
        try: os.remove(gz_path); return ('SALTADO', os.path.basename(gz_path))
        except OSError: return ('ERROR_BORRADO', os.path.basename(gz_path))
    try:
        with gzip.open(gz_path, 'rb') as f_in, open(out_path, 'wb') as f_out: shutil.copyfileobj(f_in, f_out)
        os.remove(gz_path); return ('OK', os.path.basename(gz_path))
    except Exception as e:
        logging.error(f"❌ Error descomprimiendo {os.path.basename(gz_path)}: {e}"); return ('ERROR', os.path.basename(gz_path))

def unzip_files_parallel(directory, process_executor):
    """Descomprime archivos .gz en paralelo usando un pool de procesos compartido."""
    logging.info(f"📦 Iniciando descompresión paralela en {directory}...")
    files_to_unzip = [os.path.join(directory, f) for f in os.listdir(directory) if f.endswith(".gz")]
    if not files_to_unzip:
        logging.info(f"🤷 No hay archivos .gz para descomprimir en {directory}."); return

    results = list(process_executor.map(unzip_single_file, files_to_unzip))
    
    ok_files = [f for status, f in results if status == 'OK']
    skipped_files = [f for status, f in results if status == 'SALTADO']
    error_files = [f for status, f in results if status == 'ERROR']

    logging.info(f"🏁 Descompresión de {directory} finalizada: {len(ok_files)} descomprimidos, {len(skipped_files)} saltados, {len(error_files)} errores.")
    if skipped_files: logging.info(f"  -> 📝 Archivos .gz eliminados (ya estaban descomprimidos): {len(skipped_files)}")
    if error_files: logging.error(f"❌ Errores de descompresión en: {', '.join(error_files)}.")

def group_fastqs_into_samples(fastq_urls, seq_type):
    """Agrupa las URLs de fastq en muestras, emparejando R1 y R2."""
    if seq_type == "single-end":
        samples = []
        for url in fastq_urls:
            sample_id = re.sub(r'\.f(ast)?q(\.gz)?$', '', os.path.basename(url))
            samples.append({'id': sample_id, 'r1_url': url})
        return samples
    
    sample_map = defaultdict(dict)
    r1_pattern = re.compile(r'(_R1|_1)\.f(ast)?q(\.gz)?$')
    
    for url in fastq_urls:
        filename = os.path.basename(url)
        if r1_pattern.search(filename):
            sample_id = r1_pattern.sub('', filename)
            sample_map[sample_id]['r1_url'] = url
            sample_map[sample_id]['id'] = sample_id
        else:
            sample_id = re.sub(r'(_R2|_2)\.f(ast)?q(\.gz)?$', '', filename)
            sample_map[sample_id]['r2_url'] = url
            
    samples = []
    for sample_id, data in sorted(sample_map.items()):
        if 'r1_url' in data and 'r2_url' in data:
            samples.append(data)
        else:
            logging.warning(f"⚠️ No se encontró el par completo para la muestra {sample_id}. Se omitirá.")
            
    return samples

def get_reference_files(reference_dir):
    fasta_file, gtf_file = None, None
    for fname in os.listdir(reference_dir):
        if fname.endswith((".fa", ".fna", ".fasta")): fasta_file = os.path.join(reference_dir, fname)
        elif fname.endswith(".gtf"): gtf_file = os.path.join(reference_dir, fname)
    return fasta_file, gtf_file

def prepare_adapters(base_dir, adapter_url):
    if not adapter_url: logging.warning("⚠️ No se proporcionó URL de adaptadores."); return None
    adapters_dir = os.path.join(base_dir, "adapters")
    adapters_file = os.path.join(adapters_dir, "TruSeq_adapters.fa")
    if not os.path.exists(adapters_file):
        create_directory(adapters_dir)
        logging.info(f"⬇️ Descargando adaptadores desde {adapter_url}...")
        try:
            subprocess.run(["wget", "-O", adapters_file, adapter_url], check=True, capture_output=True, text=True)
            logging.info(f"✅ Adaptadores descargados en {adapters_file}")
        except Exception as e:
            logging.error(f"❌ Error al descargar adaptadores: {e}"); return None
    else:
        logging.info(f"✅ Adaptadores ya existen: {adapters_file}")
    return adapters_file


def download_and_prepare_matrix(matrix_url, output_dir):
    """
    Descarga, descomprime, detecta separador, limpia y estandariza la matriz
    a formato CSV, reemplazando guiones en los nombres de columnas por puntos.
    """
    create_directory(output_dir)
    filename = os.path.basename(matrix_url)
    compressed_path = os.path.join(output_dir, filename)
    standardized_csv_path = os.path.join(output_dir, "standardized_counts.csv")

    if os.path.exists(standardized_csv_path):
        logging.info(f"✅ Matriz estandarizada ya existe: {standardized_csv_path}. Saltando.")
        return standardized_csv_path

    if not os.path.exists(compressed_path):
        logging.info(f"⬇️ Descargando matriz de conteos desde {matrix_url}...")
        try:
            subprocess.run(["wget", "-O", compressed_path, matrix_url], check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            logging.error(f"❌ Error descargando la matriz: {e.stderr}"); return None

    uncompressed_path = compressed_path[:-3] if filename.endswith(".gz") else compressed_path
    if filename.endswith(".gz"):
        logging.info(f"📦 Descomprimiendo {filename}...")
        with gzip.open(compressed_path, 'rb') as f_in, open(uncompressed_path, 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)

    try:
        logging.info(f"🕵️  Detectando separador y limpiando la matriz...")
        sep = ','
        try:
            with open(uncompressed_path, 'r', newline='') as f:
                sample = f.read(4096)
                dialect = csv.Sniffer().sniff(sample, delimiters=',\t ')
                sep = dialect.delimiter
                logging.info(f"    -> Separador detectado: '{repr(sep)}'")
        except csv.Error:
            logging.warning(f"⚠️  El detective de CSV falló. Se usará la coma (,) como separador por defecto.")

        df = pd.read_csv(uncompressed_path, sep=sep, comment='#', index_col=0)
        
        annotation_cols_to_remove = ['Chr', 'Start', 'End', 'Strand', 'Length']
        cleaned_df = df[[col for col in df.columns if col not in annotation_cols_to_remove]]

        cleaned_df.columns = cleaned_df.columns.str.replace('-', '.', regex=False)
        logging.info("    -> Nombres de columnas estandarizados (guiones '-' reemplazados por puntos '.').")
        
        cleaned_df.to_csv(standardized_csv_path, sep=',')
        logging.info(f"✅ Matriz limpia guardada en formato estándar CSV: {standardized_csv_path}")
        
        if os.path.exists(compressed_path): os.remove(compressed_path)
        if os.path.exists(uncompressed_path): os.remove(uncompressed_path)
            
        return standardized_csv_path
    except Exception as e:
        logging.error(f"❌ Error procesando la matriz: {e}"); return None
    

# ==============================================================================
# SECCIÓN FUNCIONES DE HERRAMIENTAS BIOINFORMÁTICAS
# ==============================================================================

              

def build_star_index(fasta_file, gtf_file, index_dir, star_container, threads, sjdb_overhang):
    """Construye el índice del genoma para STAR, omitiendo si ya existe."""
    container_cmd = os.environ.get("APPTAINER_CMD", "apptainer")
    if os.path.exists(os.path.join(index_dir, "SA")):
        logging.info(f"⏩ Índice STAR ya existe en {index_dir}. Saltando."); return
    
    cmd = [container_cmd, "exec", star_container, "STAR", "--runThreadN", str(threads), "--runMode", "genomeGenerate", "--genomeDir", index_dir, "--genomeFastaFiles", fasta_file, "--sjdbGTFfile", gtf_file, "--sjdbOverhang", str(sjdb_overhang)]
    logging.info(f"🛠️  Construyendo índice STAR en {index_dir} ...")
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        logging.info(f"✅ Índice STAR generado.")
    except subprocess.CalledProcessError as e:
        logging.error(f"❌ Error al construir el índice STAR: {e.stderr}"); exit(1)


def build_hisat2_index(fasta_file, gtf_file, index_prefix, hisat2_container):
    """Construye el índice del genoma para HISAT2 de forma robusta."""
    container_cmd = os.environ.get("APPTAINER_CMD", "apptainer")
    index_dir = os.path.dirname(index_prefix)
    
    if len([f for f in os.listdir(index_dir) if f.startswith(os.path.basename(index_prefix)) and f.endswith(".ht2")]) >= 8:
        logging.info(f"⏩ Índice HISAT2 ya existe en {index_dir}. Saltando."); return
    
    logging.info(f"🛠️  Construyendo índice HISAT2 en {index_dir} ...")
    ss_file, exon_file = f"{index_prefix}.ss", f"{index_prefix}.exon"
    
    cmd_ss = [container_cmd, "exec", hisat2_container, "hisat2_extract_splice_sites.py", gtf_file]
    cmd_exon = [container_cmd, "exec", hisat2_container, "hisat2_extract_exons.py", gtf_file]
    build_cmd = [container_cmd, "exec", hisat2_container, "hisat2-build", "--ss", ss_file, "--exon", exon_file, fasta_file, index_prefix]

    try:
        logging.info("    -> 1. Extrayendo splice sites del GTF...")
        result_ss = subprocess.run(cmd_ss, check=True, capture_output=True, text=True)
        with open(ss_file, 'w') as f:
            f.write(result_ss.stdout)
        
        logging.info("    -> 2. Extrayendo exones del GTF...")
        result_exon = subprocess.run(cmd_exon, check=True, capture_output=True, text=True)
        with open(exon_file, 'w') as f:
            f.write(result_exon.stdout)
        
        logging.info("    -> 3. Construyendo el índice con hisat2-build...")
        subprocess.run(build_cmd, check=True, capture_output=True, text=True)
        
        logging.info(f"✅ Índice HISAT2 generado correctamente.")
    except subprocess.CalledProcessError as e:
        logging.error(f"❌ Error fatal construyendo el índice HISAT2.")
        logging.error(f"  Comando ejecutado: {' '.join(e.cmd)}")
        logging.error(f"  Salida de error (stderr):\n---INICIO--- \n{e.stderr}\n---FIN---")
        exit(1)


def generate_count_matrix(bam_dir, gtf_file, output_file, container_img, seq_type, threads, strand_specific=0):
    """Genera la matriz de conteo con featureCounts, compatible con PE y SE y Strandedness."""
    if os.path.exists(output_file):
        logging.info(f"⏩ La matriz de conteo '{os.path.basename(output_file)}' ya existe. Saltando."); return
    
    container_cmd = os.environ.get("APPTAINER_CMD", "apptainer")
    bam_files = sorted([os.path.join(bam_dir, f) for f in os.listdir(bam_dir) if f.endswith(".bam")])
    if not bam_files:
        logging.warning(f"⚠️ No se encontraron archivos BAM en {bam_dir}. No se puede generar la matriz de conteo."); return
        
    cmd = [container_cmd, "exec", container_img, "featureCounts", 
           "-T", str(threads), 
           "-s", str(strand_specific), 
           "-a", gtf_file, 
           "-o", output_file]

    if seq_type == "paired-end":
        cmd.append("-p")
    cmd.extend(bam_files)
    
    logging.info(f"📊 Generando matriz de conteo (Strandedness={strand_specific}) desde {bam_dir}...")
    try:
        subprocess.run(cmd, check=True, text=True, capture_output=True)
        logging.info(f"✅ Matriz de conteo generada: {output_file}")
    except subprocess.CalledProcessError as e:
        logging.error(f"❌ Error en featureCounts:\n{e.stderr}"); exit(1)

def run_stringtie_quantification(bam_dir, gtf_file, output_dir, container_img, threads):
    """Ejecuta StringTie en modo 'solo cuantificación' para cada archivo BAM."""
    create_directory(output_dir)
    apptainer_cmd = os.environ.get("APPTAINER_CMD", "apptainer")
    bam_files = [f for f in os.listdir(bam_dir) if f.endswith(".bam")]
    logging.info(f"🧬 Iniciando cuantificación (TPM/FPKM) con StringTie para {len(bam_files)} muestras...")
    for bam_file in bam_files:
        sample_name = re.sub(r'_Aligned\.sortedByCoord\.out\.bam$', '', bam_file)
        bam_path = os.path.join(bam_dir, bam_file)
        sample_out_dir = os.path.join(output_dir, sample_name)
        abund_file = os.path.join(sample_out_dir, "gene_abundances.tsv")
        if os.path.exists(abund_file):
            logging.info(f"⏩ Cuantificación de StringTie para {sample_name} ya existe. Saltando.")
            continue
        create_directory(sample_out_dir)
        cmd = [apptainer_cmd, "exec", container_img, "stringtie", bam_path, "-G", gtf_file, "-p", str(threads), "-e", "-A", abund_file, "-o", os.path.join(sample_out_dir, f"{sample_name}.gtf")]
        logging.info(f"  -> Procesando {sample_name}...")
        try:
            subprocess.run(cmd, check=True, capture_output=True, text=True)
            logging.info(f"✅ Cuantificación completada para {sample_name}")
        except subprocess.CalledProcessError as e:
            logging.error(f"❌ Error en StringTie para {sample_name}:\n{e.stderr}")

def assemble_normalized_matrices(stringtie_dir, output_prefix, methods_to_assemble):
    """Ensambla los archivos de abundancia de StringTie en matrices FPKM y/o TPM."""
    logging.info(f"📊 Ensamblando matrices finales para: {', '.join(m.upper() for m in methods_to_assemble)}...")
    sample_dirs = sorted([d for d in os.listdir(stringtie_dir) if os.path.isdir(os.path.join(stringtie_dir, d))])
    for method in methods_to_assemble:
        metric_col_name = 'TPM' if method.lower() == 'tpm' else 'FPKM'
        list_of_series = []
        for sample_name in sample_dirs:
            abund_file = os.path.join(stringtie_dir, sample_name, "gene_abundances.tsv")
            if not os.path.exists(abund_file):
                logging.warning(f"⚠️ No se encontró el archivo de abundancias para {sample_name}. Se omitirá.")
                continue
            try:
                df_sample = pd.read_csv(abund_file, sep='\t', usecols=['Gene ID', metric_col_name])
                df_sample = df_sample.groupby('Gene ID')[metric_col_name].sum().reset_index()
                sample_series = df_sample.set_index('Gene ID')[metric_col_name]
                sample_series.name = sample_name
                list_of_series.append(sample_series)
            except Exception as e:
                logging.warning(f"⚠️ No se pudo procesar el archivo para {sample_name}: {e}")
        if not list_of_series:
            logging.error(f"❌ No se pudo generar la matriz de {method.upper()}.")
            continue
        final_matrix = pd.concat(list_of_series, axis=1, join='outer').fillna(0)
        final_matrix.index.name = 'gene_id'
        output_file = f"{output_prefix}_{method}_matrix.tsv"
        final_matrix.to_csv(output_file, sep='\t')
        logging.info(f"✅ Matriz de {method.upper()} guardada en: {output_file}")

def run_exploratory_analysis(config, matrix_path, output_dir):
    """Ejecuta el script de R para análisis exploratorio usando la estrategia --bind."""
    logging.info(f"📈 Iniciando Análisis Exploratorio en {output_dir}")
    create_directory(output_dir)
    setup_params = config.get("project_setup", {}); scripts_config = config.get("scripts", {}); images_config = config.get("container_images", {}); deseq2_config = config.get("deseq2_experiment", {}); annotation_config = config.get("annotation", {})
    host_bind_dir = setup_params.get("host_bind_dir")
    container_workspace = "/workspace"
    if not host_bind_dir: logging.error("❌ Falta 'host_bind_dir' en el JSON."); return
    r_script_host = os.path.abspath(scripts_config.get("r_exploratory_script_path")); r_container_host = images_config.get("r_deseq2"); matrix_host = os.path.abspath(matrix_path); metadata_host = os.path.abspath(deseq2_config.get("metadata_path")); output_dir_host = os.path.abspath(output_dir)
    r_script_container = r_script_host.replace(host_bind_dir, container_workspace); matrix_container = matrix_host.replace(host_bind_dir, container_workspace); metadata_container = metadata_host.replace(host_bind_dir, container_workspace); output_dir_container = output_dir_host.replace(host_bind_dir, container_workspace)
    apptainer_cmd = os.environ.get("APPTAINER_CMD", "apptainer")
    matrix_type = "TPM" if "tpm" in matrix_path.lower() else "FPKM" if "fpkm" in matrix_path.lower() else "Matrix"
    cmd = [apptainer_cmd, "exec", "--bind", f"{host_bind_dir}:{container_workspace}", "--pwd", container_workspace, r_container_host, "Rscript", r_script_container, "--matrix_file", matrix_container, "--metadata_file", metadata_container, "--output_dir", output_dir_container, "--grouping_variable", deseq2_config.get("grouping_variable"), "--matrix_type", matrix_type, "--organism_db", annotation_config.get("organism_db"), "--key_type", annotation_config.get("key_type")]
    logging.info(f"  -> Comando a ejecutar: {' '.join(cmd)}")
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        logging.info(f"✅ Análisis Exploratorio completado. Gráficos en: {output_dir}")
    except subprocess.CalledProcessError as e:
        logging.error(f"❌ Error CRÍTICO en el script de R (Análisis Exploratorio).\n--- STDOUT de R ---\n{e.stdout}\n--- STDERR de R ---\n{e.stderr}")

def run_deseq2(config, output_dir, counts_file_path, gtf_file, alignments_dir=None):
    """
    Prepara un metadata corregido y ejecuta DESeq2 usando la estrategia --bind.
    """
    logging.info(f"🔬 Iniciando análisis de Expresión Diferencial en {output_dir}")
    create_directory(output_dir)
    
    # 1. Leer el metadata original del usuario.
    original_metadata_path = config["deseq2_experiment"]["metadata_path"]
    metadata_df = pd.read_csv(original_metadata_path)
    
    # 2. Corregir los nombres de las muestras (reemplazar guión por punto).
    sample_col_name = metadata_df.columns[0]
    metadata_df[sample_col_name] = metadata_df[sample_col_name].str.replace('-', '.', regex=False)
    
    # 3. Guardar el metadata corregido en un archivo temporal en la misma carpeta que el original.
    corrected_metadata_path = os.path.join(os.path.dirname(os.path.abspath(original_metadata_path)), "metadata_corregido.csv")
    metadata_df.to_csv(corrected_metadata_path, index=False)
    logging.info(f"    -> Metadata temporal corregido creado en: {corrected_metadata_path}")

    setup_params = config.get("project_setup", {}); scripts_config = config.get("scripts", {}); images_config = config.get("container_images", {})
    host_bind_dir = setup_params.get("host_bind_dir")
    container_workspace = "/workspace"
    if not host_bind_dir: logging.error("❌ Falta 'host_bind_dir' en el JSON."); exit(1)
    
    r_script_host = os.path.abspath(scripts_config.get("r_deseq2_script_path"))
    r_container_host = images_config.get("r_deseq2")
    r_script_container = r_script_host.replace(host_bind_dir, container_workspace)
    counts_file_container = os.path.abspath(counts_file_path).replace(host_bind_dir, container_workspace)
    metadata_container = os.path.abspath(corrected_metadata_path).replace(host_bind_dir, container_workspace)
    output_dir_container = os.path.abspath(output_dir).replace(host_bind_dir, container_workspace)
    gtf_file_container = os.path.abspath(gtf_file).replace(host_bind_dir, container_workspace) if gtf_file else "NULL"
    
    apptainer_cmd = os.environ.get("APPTAINER_CMD", "apptainer")
    deseq2_config = config.get("deseq2_experiment", {})
    annotation_config = config.get("annotation", {})
    analysis_thresholds = config.get("tool_parameters", {}).get("analysis_thresholds", {})
    func_analysis_config = config.get("functional_analysis", {})
    
    cmd = [
        apptainer_cmd, "exec", "--bind", f"{host_bind_dir}:{container_workspace}", "--pwd", container_workspace,
        r_container_host, "Rscript", r_script_container,
        "--counting_method", setup_params.get("counting_method"),
        "--counts_file", counts_file_container,
        "--metadata_file", metadata_container,
        "--output_dir", output_dir_container,
        "--gtf_file", gtf_file_container,
        "--design_formula", deseq2_config.get("design_formula"),
        "--control_group", deseq2_config.get("control_group"),
        "--organism_db", annotation_config.get("organism_db"),
        "--key_type", annotation_config.get("key_type"),
        "--padj_threshold", str(analysis_thresholds.get("padj", 0.05)),
        "--log2fc_threshold", str(analysis_thresholds.get("log2fc", 1.0)),
        "--strip_gene_version", str(annotation_config.get("strip_gene_version", False)).upper()
    ]
    
    if func_analysis_config.get("gprofiler_organism_code"):
        cmd.extend([
            "--run_kegg", "TRUE", 
            "--gprofiler_organism", func_analysis_config.get("gprofiler_organism_code", ""),
            "--kegg_padj_threshold", str(func_analysis_config.get("kegg_padj_threshold", 0.05))
        ])
    
    logging.info(f"  -> Comando a ejecutar: {' '.join(cmd)}")
    try:
        process = subprocess.run(cmd, check=True, capture_output=True, text=True)
        logging.info("✅ Análisis DESeq2 completado exitosamente.")
        logging.debug(f"--- STDOUT de R ---\n{process.stdout}\n--- FIN STDOUT ---")
    except subprocess.CalledProcessError as e:
        logging.error(f"❌ Error CRÍTICO en el script de R (DESeq2).\n--- STDOUT de R ---\n{e.stdout}\n--- STDERR de R ---\n{e.stderr}"); exit(1)



def run_enrichment_visualization(config, deseq2_results_dir):
    """
    Ejecuta el script de visualización R (Modo Híbrido).
    Ahora incluye parámetros dinámicos para SEA y GSEA desde el JSON.
    """
    func_analysis_config = config.get("functional_analysis", {})
    
    # 1. Verificar si está habilitado en el JSON
    if not func_analysis_config.get("run_enrichment_plots", False): 
        logging.info("📊 Visualización de enriquecimiento no habilitada en JSON. Saltando.")
        return
        
    logging.info(f"📊 Iniciando visualización de enriquecimiento funcional...")
    
    # 2. Cargar configuraciones
    setup_params = config.get("project_setup", {})
    scripts_config = config.get("scripts", {})
    images_config = config.get("container_images", {})
    annotation_config = config.get("annotation", {})
    analysis_thresholds = config.get("tool_parameters", {}).get("analysis_thresholds", {})
    plot_params = func_analysis_config.get("plot_parameters", {})
    
    # 3. Configurar rutas y contenedores
    host_bind_dir = setup_params.get("host_bind_dir")
    container_workspace = "/workspace"
    if not host_bind_dir: 
        logging.error("❌ Falta la clave 'host_bind_dir' en el JSON."); return
    
    r_script_host = os.path.abspath(scripts_config.get("r_enrichment_plotter_script_path"))
    r_container_host = images_config.get("r_deseq2")
    
    # Mapeo de rutas Host -> Contenedor
    r_script_container = r_script_host.replace(host_bind_dir, container_workspace)
    pwd_container = os.path.abspath(deseq2_results_dir).replace(host_bind_dir, container_workspace)
    
    # 4. Validaciones previas
    if not os.path.exists(r_script_host): 
        logging.error(f"❌ No se encontró el script de R en la ruta del host: {r_script_host}"); return
        
    # Verificar si hay archivos de entrada (output de DESeq2/gProfiler)
    # Buscamos "Analisis_Rutas_Enriquecidas_" que genera el script anterior
    if not any(f.startswith("Analisis_Rutas_Enriquecidas_") for f in os.listdir(deseq2_results_dir)):
        logging.warning(f"⚠️ No se encontraron archivos 'Analisis_Rutas_Enriquecidas_*.txt' en {deseq2_results_dir}. Saltando visualización.")
        return
        
    apptainer_cmd = os.environ.get("APPTAINER_CMD", "apptainer")
    
    cmd = [
        apptainer_cmd, "exec", 
        "--bind", f"{host_bind_dir}:{container_workspace}", 
        "--pwd", pwd_container, 
        r_container_host, "Rscript", r_script_container
    ]
    
    # --- Parámetros Generales (Organismo y Thresholds) ---
    cmd.extend([
        "--kegg_species_code", func_analysis_config.get("pathview_kegg_code"), 
        "--key_type", annotation_config.get("key_type"), 
        "--organism_db", annotation_config.get("organism_db"),
        "--log2fc", str(analysis_thresholds.get("log2fc", 1.0)), 
        "--padj", str(analysis_thresholds.get("padj", 0.05))
    ])
    
    # --- Parámetros de SEA (ORA) ---
    if func_analysis_config.get("run_sea_analysis", False):
        cmd.append("--run_sea_analysis") # Flag booleano
        cmd.extend([
            "--sea_padj_cutoff", str(func_analysis_config.get("sea_padj_cutoff", 0.05)), 
            "--sea_qvalue_cutoff", str(func_analysis_config.get("sea_qvalue_cutoff", 0.1)), 
            "--sea_ontologies"
        ])
        cmd.extend(func_analysis_config.get("sea_ontologies", ["BP", "MF", "CC"]))

    # --- Parámetros de GSEA ---
    if func_analysis_config.get("run_gsea_analysis", False):
        cmd.append("--run_gsea_analysis") # Flag booleano
        cmd.extend([
            "--gsea_padj_cutoff", str(func_analysis_config.get("gsea_padj_cutoff", 0.05))
        ])

    # --- Parámetros de Gráficos (Plotting) ---
    cmd.extend([
        "--top_n_emap", str(plot_params.get("top_n_emap", 15)),
        "--top_n_cnet", str(plot_params.get("top_n_cnet", 10)),
        "--top_n_ridge", str(plot_params.get("top_n_ridge", 15)),
        "--top_n_gseaplot", str(plot_params.get("top_n_gseaplot", 5))
    ])

    # 6. Ejecución del Comando
    final_cmd = [str(c) for c in cmd if c is not None]
    logging.info(f"  -> Comando a ejecutar: {' '.join(final_cmd)}")
    
    try:
        process = subprocess.run(final_cmd, check=True, capture_output=True, text=True)
        logging.info(f"✅ Gráficos de enriquecimiento generados exitosamente en: {deseq2_results_dir}")
        logging.debug(f"--- STDOUT de R ---\n{process.stdout}\n--- FIN STDOUT ---")
    except subprocess.CalledProcessError as e:
        logging.error(f"❌ Error CRÍTICO en el script de R (Visualización).\n--- STDOUT de R ---\n{e.stdout}\n--- STDERR de R ---\n{e.stderr}")
        exit(1)
def run_pdf_report_generator(config, deseq2_results_dir):
    
    func_analysis_config = config.get("functional_analysis", {})

    # 1. Comprobar si este paso está habilitado en el JSON
    if not func_analysis_config.get("run_final_pdf_reports", False):
        logging.info("📜 Generación de informes PDF 'tochos' no habilitada en JSON. Saltando.")
        return

    logging.info(f"📜 Iniciando generación de informes PDF 'tochos' en: {deseq2_results_dir}")

    # 2. Obtener la configuración necesaria
    setup_params = config.get("project_setup", {})
    scripts_config = config.get("scripts", {})
    images_config = config.get("container_images", {})

    host_bind_dir = setup_params.get("host_bind_dir")
    container_workspace = "/workspace"
    if not host_bind_dir: 
        logging.error("❌ Falta la clave 'host_bind_dir' en el JSON. No se pueden generar los PDFs.")
        return

    # 3. Obtener la ruta del script R del JSON
    r_script_host = os.path.abspath(scripts_config.get("r_pdf_report_script_path"))
    r_container_host = images_config.get("r_deseq2") # Reutilizamos el mismo entorno de R
    r_script_container = r_script_host.replace(host_bind_dir, container_workspace)

    # El directorio de trabajo dentro del contenedor será la carpeta de resultados
    pwd_container = os.path.abspath(deseq2_results_dir).replace(host_bind_dir, container_workspace)

    if not os.path.exists(r_script_host): 
        logging.error(f"❌ No se encontró el script 'Informes_generator.R' en la ruta del host: {r_script_host}")
        return

    # 4. Comprobar si los archivos de entrada (de DESeq2) existen
    if not any(f.startswith("Resultados_Completos_") for f in os.listdir(deseq2_results_dir)):
        logging.warning(f"⚠️ No se encontraron archivos 'Resultados_Completos_*.txt' en {deseq2_results_dir}. Saltando generación de PDFs.")
        return

    apptainer_cmd = os.environ.get("APPTAINER_CMD", "apptainer")

    # 5. Obtener el organismo 
    organism_code = func_analysis_config.get("gprofiler_organism_code")
    if not organism_code:
        logging.error("❌ No se encontró 'gprofiler_organism_code' en el JSON. No se pueden generar los PDFs.")
        return

    cmd = [
        apptainer_cmd, "exec", 
        "--bind", f"{host_bind_dir}:{container_workspace}", 
        "--pwd", pwd_container,  
        r_container_host, "Rscript", r_script_container,
        "--input_dir", ".",     
        "--organism", organism_code
    ]

    final_cmd = [str(c) for c in cmd if c is not None]
    logging.info(f"  -> Comando a ejecutar: {' '.join(final_cmd)}")

    try:
        process = subprocess.run(final_cmd, check=True, capture_output=True, text=True)
        logging.info(f"✅ Informes PDF 'tochos' generados exitosamente en: {deseq2_results_dir}")
        logging.debug(f"--- STDOUT de R (Informes PDF) ---\n{process.stdout}\n--- FIN STDOUT ---")
    except subprocess.CalledProcessError as e:
        logging.error(f"❌ Error CRÍTICO en el script de R (Informes_generator.R).\n--- STDOUT de R ---\n{e.stdout}\n--- STDERR de R ---\n{e.stderr}")




def run_multiqc(dirs_to_scan, output_dir, container_img):
    if not container_img:
        logging.warning("⚠️ No se proporcionó imagen de MultiQC. Saltando informe.")
        return
    logging.info(f"📜 Generando informe MultiQC en {output_dir}...")
    create_directory(output_dir)
    container_cmd = os.environ.get("APPTAINER_CMD", "apptainer")
    existing_dirs = [d for d in dirs_to_scan if os.path.isdir(d)]
    if not existing_dirs:
        logging.warning("⚠️ No se encontraron directorios válidos para escanear con MultiQC.")
        return
    cmd = [container_cmd, "exec", container_img, "multiqc"] + existing_dirs + ["-o", output_dir, "--force"]
    try:
        subprocess.run(cmd, check=True, capture_output=True, text=True)
        logging.info(f"✅ Informe de MultiQC generado en: {output_dir}")
    except subprocess.CalledProcessError as e:
        logging.error(f"❌ Error en MultiQC: {e.stderr}")



def compare_and_analyze_workflows(config):
    """Compara los resultados de DESeq2 y de análisis funcional de los flujos de STAR y HISAT2."""
    logging.info("\n" + "="*20 + " INICIANDO COMPARACIÓN DE WORKFLOWS " + "="*20)
    
    base_dir = config.get("project_setup", {}).get("base_dir", ".")
    star_dir = os.path.join(base_dir, "DESEQ2_RESULTS_STAR")
    hisat2_dir = os.path.join(base_dir, "DESEQ2_RESULTS_HISAT2")
    output_dir_base = os.path.join(base_dir, "WORKFLOW_COMPARISON")
    create_directory(output_dir_base)

    if not os.path.isdir(star_dir) or not os.path.isdir(hisat2_dir):
        logging.warning("⚠️ No se encontraron las carpetas de resultados de DESeq2 para STAR y HISAT2. Saltando comparación.")
        return

    star_sig_files = {re.sub(r'^(Resultados_Significativos_|Analisis_Funcional_)|(\.txt|\.tsv)$', '', f): os.path.join(star_dir, f) 
                      for f in os.listdir(star_dir) if f.startswith("Resultados_Significativos_")}
    hisat2_sig_files = {re.sub(r'^(Resultados_Significativos_|Analisis_Funcional_)|(\.txt|\.tsv)$', '', f): os.path.join(hisat2_dir, f) 
                        for f in os.listdir(hisat2_dir) if f.startswith("Resultados_Significativos_")}
    
    star_func_files = {re.sub(r'^(Resultados_Significativos_|Analisis_Rutas_Enriquecidas_)|(\.txt|\.tsv)$', '', f): os.path.join(star_dir, f) 
                       for f in os.listdir(star_dir) if f.startswith("Analisis_Rutas_Enriquecidas_")}
    hisat2_func_files = {re.sub(r'^(Resultados_Significativos_|Analisis_Rutas_Enriquecidas_)|(\.txt|\.tsv)$', '', f): os.path.join(hisat2_dir, f) 
                         for f in os.listdir(hisat2_dir) if f.startswith("Analisis_Rutas_Enriquecidas_")}

    common_contrasts = sorted(list(set(star_sig_files.keys()).intersection(set(hisat2_sig_files.keys()))))
    
    if not common_contrasts:
        logging.warning("⚠️ No se encontraron contrastes comunes entre STAR y HISAT2 para comparar.")
        return
        
    logging.info(f"Se compararán los siguientes contrastes: {common_contrasts}")

    for contrast in common_contrasts:
        output_dir_contrast = os.path.join(output_dir_base, contrast)
        create_directory(output_dir_contrast)
        logging.info(f"\n--- Procesando contraste: {contrast} ---")

        # 1. Comparación de Genes
        try:
            logging.info("🧬 Comparando listas de genes significativos...")
            df_star = pd.read_csv(star_sig_files[contrast], sep='\t')
            df_hisat2 = pd.read_csv(hisat2_sig_files[contrast], sep='\t')

            set_star_genes = set(df_star['gene_id'])
            set_hisat2_genes = set(df_hisat2['gene_id'])
            
            common_genes = set_star_genes.intersection(set_hisat2_genes)
            unique_star_genes = set_star_genes.difference(set_hisat2_genes)
            unique_hisat2_genes = set_hisat2_genes.difference(set_star_genes)
            
            summary = (f"Resumen de Comparación de GENES para '{contrast}':\n"
                       f"--------------------------------------------------\n"
                       f"Total en STAR: {len(set_star_genes)} | Total en HISAT2: {len(set_hisat2_genes)}\n"
                       f"Comunes: {len(common_genes)} | Únicos de STAR: {len(unique_star_genes)} | Únicos de HISAT2: {len(unique_hisat2_genes)}")
            logging.info(summary.replace('\n', '\n     '))
            with open(os.path.join(output_dir_contrast, "resumen_comparacion_genes.txt"), 'w') as f: f.write(summary)

            df_star[df_star['gene_id'].isin(unique_star_genes)].to_csv(os.path.join(output_dir_contrast, "genes_unicos_STAR.tsv"), sep='\t', index=False)
            df_hisat2[df_hisat2['gene_id'].isin(unique_hisat2_genes)].to_csv(os.path.join(output_dir_contrast, "genes_unicos_HISAT2.tsv"), sep='\t', index=False)
            
            if common_genes:
                pd.merge(df_star, df_hisat2, on=["gene_id", "symbol"], suffixes=('_STAR', '_HISAT2')) \
                  .to_csv(os.path.join(output_dir_contrast, "genes_comunes_stats.tsv"), sep='\t', index=False)
        except Exception as e:
            logging.warning(f"⚠️ Error comparando genes para el contraste {contrast}: {e}")

        # 2. Comparación de Análisis Funcional
        if contrast in star_func_files and contrast in hisat2_func_files:
            try:
                logging.info("🔬 Comparando resultados de análisis funcional...")
                df_func_star = pd.read_csv(star_func_files[contrast], sep='\t')
                df_func_hisat2 = pd.read_csv(hisat2_func_files[contrast], sep='\t')

                set_star_terms = set(df_func_star['term_id'])
                set_hisat2_terms = set(df_func_hisat2['term_id'])

                common_terms = set_star_terms.intersection(set_hisat2_terms)
                unique_star_terms = set_star_terms.difference(set_hisat2_terms)
                unique_hisat2_terms = set_hisat2_terms.difference(set_star_terms)

                summary_func = (f"Resumen de Comparación FUNCIONAL para '{contrast}':\n"
                                f"--------------------------------------------------\n"
                                f"Términos enriquecidos en STAR: {len(set_star_terms)}\n"
                                f"Términos enriquecidos en HISAT2: {len(set_hisat2_terms)}\n"
                                f"Comunes: {len(common_terms)} | Únicos de STAR: {len(unique_star_terms)} | Únicos de HISAT2: {len(unique_hisat2_terms)}")
                logging.info(summary_func.replace('\n', '\n     '))
                with open(os.path.join(output_dir_contrast, "resumen_comparacion_funcional.txt"), 'w') as f: f.write(summary_func)

                df_func_star[df_func_star['term_id'].isin(unique_star_terms)].to_csv(os.path.join(output_dir_contrast, "funcional_terminos_unicos_STAR.tsv"), sep='\t', index=False)
                df_func_hisat2[df_func_hisat2['term_id'].isin(unique_hisat2_terms)].to_csv(os.path.join(output_dir_contrast, "funcional_terminos_unicos_HISAT2.tsv"), sep='\t', index=False)

                if common_terms:
                    pd.merge(df_func_star, df_func_hisat2, on=["term_id", "term_name", "source"], suffixes=('_STAR', '_HISAT2')) \
                      .to_csv(os.path.join(output_dir_contrast, "funcional_terminos_comunes_stats.tsv"), sep='\t', index=False)
            except Exception as e:
                logging.warning(f"⚠️ Error comparando análisis funcional para el contraste {contrast}: {e}")
        else:
            logging.info(f"🔬 No se encontraron archivos de análisis funcional para ambos workflows en el contraste {contrast}. Saltando comparación funcional.")





def pipeline_worker_for_sample(sample_info, config, paths):
    """
    Función "trabajador" que ejecuta el pipeline completo para UNA SOLA muestra.
    Incluye lógica de limpieza avanzada (Retroactiva y Post-ejecución).
    """
    sample_id = sample_info['id']
    r1_url = sample_info['r1_url']
    r2_url = sample_info.get('r2_url', None)

    try:
        # --- Extracción de Parámetros ---
        setup_params = config.get("project_setup", {})
        images = config.get("container_images", {})
        tool_params = config.get("tool_parameters", {})
        seq_type = setup_params.get("sequencing_type", "paired-end").lower()
        threads_per_sample = tool_params.get("threads_per_sample", 2)
        container_cmd = os.environ.get("APPTAINER_CMD", "apptainer")

        # --- Rutas de Archivos ---
        r1_raw_gz = os.path.join(
            paths['fastq_dir'],
            f"{sample_id}_1.fastq.gz" if seq_type == "paired-end" else f"{sample_id}.fastq.gz"
        )
        r2_raw_gz = os.path.join(paths['fastq_dir'], f"{sample_id}_2.fastq.gz") if r2_url else None

        r1_raw = r1_raw_gz.replace(".gz", "")
        r2_raw = r2_raw_gz.replace(".gz", "") if r2_raw_gz else None

        r1_trimmed = os.path.join(
            paths['trimmed_dir'],
            f"{sample_id}_1.trimmed.fastq.gz" if seq_type == "paired-end" else f"{sample_id}.trimmed.fastq.gz"
        )
        r2_trimmed = os.path.join(paths['trimmed_dir'], f"{sample_id}_2.trimmed.fastq.gz") \
            if seq_type == "paired-end" else None

        # ====================================================================
        # === 1. CHEQUEO RÁPIDO DE FINALIZACIÓN (CON LIMPIEZA RETROACTIVA) ===
        # ====================================================================

        if not paths['aligners_to_run']:
            return f"SALTADO (No Aligners): {sample_id}"

        all_bams_exist = True
        for aligner in paths['aligners_to_run']:
            final_bam_file = os.path.join(
                paths[f'alignments_dir_{aligner}'],
                f"{sample_id}_Aligned.sortedByCoord.out.bam"
            )
            if not os.path.exists(final_bam_file):
                all_bams_exist = False
                logging.info(f"🧬 [WORKER {sample_id}] BAM faltante: {os.path.basename(final_bam_file)}. Se debe procesar.")
                break 
        
        if all_bams_exist:
            logging.info(f"✅ [WORKER {sample_id}] Todos los BAMs finales ya existen.")
            
            retro_max = tool_params.get("retain_only_fastqc_and_bam", False)
            retro_med = tool_params.get("cleanup_only_fastq", False)
            
            if retro_max or retro_med:
                logging.info(f"🧹 [WORKER {sample_id}] Ejecutando limpieza retroactiva...")
                
                # 1. Borrar CRUDOS (Aplica a ambos modos)
                if os.path.exists(r1_raw): os.remove(r1_raw)
                if r2_raw and os.path.exists(r2_raw): os.remove(r2_raw)
                
                # 2. Borrar INTERMEDIOS (Solo modo Máximo)
                if retro_max:
                    if os.path.exists(r1_trimmed): os.remove(r1_trimmed)
                    if r2_trimmed and os.path.exists(r2_trimmed): os.remove(r2_trimmed)
                    
                    if 'alignments_dir_HISAT2' in paths:
                        sam_file = os.path.join(paths['alignments_dir_HISAT2'], f"{sample_id}.sam")
                        if os.path.exists(sam_file): os.remove(sam_file)
                        
                    if 'alignments_dir_STAR' in paths:
                        star_out_prefix = os.path.join(paths['alignments_dir_STAR'], f"{sample_id}_")
                        star_tmp_dir = f"{star_out_prefix}STARtmp" 
                        if os.path.exists(star_tmp_dir): shutil.rmtree(star_tmp_dir, ignore_errors=True)
                        if os.path.exists(star_tmp_dir.replace("STARtmp", "_STARtmp")): shutil.rmtree(star_tmp_dir.replace("STARtmp", "_STARtmp"), ignore_errors=True)

            return f"SALTADO (BAMs OK): {sample_id}"

        # Si no existen los BAMs, continuamos con el pipeline normal
        logging.info(f"🚀 [WORKER {sample_id}] Iniciando pipeline...")
        
        # ====================================================================
        # 2. DESCARGA Y DESCOMPRESIÓN
        # ====================================================================

        # --- R1 ---
        if not os.path.exists(r1_raw):
            if not os.path.exists(r1_raw_gz):
                logging.info(f"⬇️ [WORKER {sample_id}] Descargando {os.path.basename(r1_url)}...")
                subprocess.run(["wget", "-q", "-O", r1_raw_gz, r1_url], check=True, capture_output=True, text=True)
            
            logging.info(f"📦 [WORKER {sample_id}] Descomprimiendo {os.path.basename(r1_raw_gz)}...")
            with gzip.open(r1_raw_gz, 'rb') as f_in, open(r1_raw, 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)
            os.remove(r1_raw_gz) 
        else:
            logging.info(f"⏩ [WORKER {sample_id}] R1 raw ya existe.")

        # --- R2 ---
        if seq_type == "paired-end" and r2_url:
            if not os.path.exists(r2_raw):
                if not os.path.exists(r2_raw_gz):
                    logging.info(f"⬇️ [WORKER {sample_id}] Descargando {os.path.basename(r2_url)}...")
                    subprocess.run(["wget", "-q", "-O", r2_raw_gz, r2_url], check=True, capture_output=True, text=True)
                
                logging.info(f"📦 [WORKER {sample_id}] Descomprimiendo {os.path.basename(r2_raw_gz)}...")
                with gzip.open(r2_raw_gz, 'rb') as f_in, open(r2_raw, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)
                os.remove(r2_raw_gz)
            else:
                logging.info(f"⏩ [WORKER {sample_id}] R2 raw ya existe.")

        # ====================================================================
        # 3. FastQC Inicial
        # ====================================================================
        fastqc_check_file = os.path.join(
            paths['fastqc_dir'],
            f"{os.path.basename(r1_raw).replace('.fastq', '')}_fastqc.html"
        )

        if not os.path.exists(fastqc_check_file):
            logging.info(f"🔍 [WORKER {sample_id}] Ejecutando FastQC inicial...")
            fastqc_cmd = [
                container_cmd, "exec", images.get("fastqc"), "fastqc",
                "-o", paths['fastqc_dir'], r1_raw
            ]
            if r2_raw and os.path.exists(r2_raw):
                fastqc_cmd.append(r2_raw)

            subprocess.run(fastqc_cmd, check=True, capture_output=True, text=True)
        else:
            logging.info(f"⏩ [WORKER {sample_id}] FastQC inicial ya existe.")

        # ====================================================================
        # 4. Trimmomatic
        # ====================================================================
        if not os.path.exists(r1_trimmed):
            logging.info(f"✂️ [WORKER {sample_id}] Ejecutando Trimmomatic...")

            trimmomatic_config = tool_params.get("trimmomatic", {})
            trimmomatic_extra_args = trimmomatic_config.get("extra_args", None)
            
            sliding_w = trimmomatic_config.get("sliding_window", "4:15")
            min_len = trimmomatic_config.get("min_len", 36)
            leading = trimmomatic_config.get("leading", 3)
            trailing = trimmomatic_config.get("trailing", 3)

            trim_cmd_base = [container_cmd, "exec", images.get("trimmomatic"), "trimmomatic"]

            if trimmomatic_extra_args:
                trim_cmd_base.extend(trimmomatic_extra_args.split())

            trim_params = [
                f"ILLUMINACLIP:{paths['adapters_file']}:2:30:10",
                f"LEADING:{leading}",
                f"TRAILING:{trailing}",
                f"SLIDINGWINDOW:{sliding_w}",
                f"MINLEN:{min_len}"
            ]

            # Validación de existencia de crudos antes de trim
            if not os.path.exists(r1_raw):
                 raise FileNotFoundError(f"FASTQ RAW no encontrado para {sample_id} antes de Trimmomatic")

            if seq_type == "paired-end":
                out1_unp = os.path.join(paths['trimmed_dir'], f"{sample_id}_1.unpaired.fastq.gz")
                out2_unp = os.path.join(paths['trimmed_dir'], f"{sample_id}_2.unpaired.fastq.gz")

                trim_cmd = trim_cmd_base + [
                    "PE", "-threads", str(threads_per_sample),
                    r1_raw, r2_raw,
                    r1_trimmed, out1_unp,
                    r2_trimmed, out2_unp
                ] + trim_params

                subprocess.run(trim_cmd, check=True, capture_output=True, text=True)
                if os.path.exists(out1_unp): os.remove(out1_unp)
                if os.path.exists(out2_unp): os.remove(out2_unp)

            else:
                trim_cmd = trim_cmd_base + [
                    "SE", "-threads", str(threads_per_sample),
                    r1_raw, r1_trimmed
                ] + trim_params

                subprocess.run(trim_cmd, check=True, capture_output=True, text=True)

            logging.info(f"✅ [WORKER {sample_id}] Trimmomatic completado.")
        else:
            logging.info(f"⏩ [WORKER {sample_id}] Trimmed ya existe.")

        # ====================================================================
        # 5. Alineamiento
        # ====================================================================
        for aligner in paths['aligners_to_run']:
            alignments_dir = paths[f'alignments_dir_{aligner}']
            out_prefix = os.path.join(alignments_dir, f"{sample_id}_")
            final_bam_file = f"{out_prefix}Aligned.sortedByCoord.out.bam"

            if not os.path.exists(final_bam_file):
                logging.info(f"🧬 [WORKER {sample_id}] Ejecutando alineamiento con {aligner}...")

                if aligner == "STAR":
                    align_cmd = [
                        container_cmd, "exec", images.get("star"), "STAR",
                        "--runThreadN", str(threads_per_sample),
                        "--genomeDir", paths['reference_dir'],
                        "--outFileNamePrefix", out_prefix,
                        "--outSAMtype", "BAM", "SortedByCoordinate",
                        "--readFilesCommand", "zcat",
                        "--readFilesIn", r1_trimmed
                    ]
                    if seq_type == "paired-end":
                        align_cmd.append(r2_trimmed)

                    subprocess.run(align_cmd, check=True, capture_output=True, text=True)

                elif aligner == "HISAT2":
                    sam_output = os.path.join(alignments_dir, f"{sample_id}.sam")
                    align_cmd = [
                        container_cmd, "exec", images.get("hisat2"), "hisat2",
                        "-p", str(threads_per_sample),
                        "-x", paths['hisat2_index_prefix'],
                        "-S", sam_output
                    ]
                    if seq_type == "paired-end":
                        align_cmd.extend(["-1", r1_trimmed, "-2", r2_trimmed])
                    else:
                        align_cmd.extend(["-U", r1_trimmed])

                    align_result = subprocess.run(align_cmd, check=True, text=True, capture_output=True)
                    with open(os.path.join(alignments_dir, f"{sample_id}_hisat2_summary.log"), 'w') as f:
                        f.write(align_result.stderr)

                    sam_to_bam_cmd = [
                        container_cmd, "exec", images.get("star"), "samtools",
                        "sort", "-@", str(threads_per_sample),
                        "-o", final_bam_file, sam_output
                    ]
                    subprocess.run(sam_to_bam_cmd, check=True, capture_output=True, text=True)
                    os.remove(sam_output) 

                logging.info(f"✅ [WORKER {sample_id}] Alineamiento {aligner} completado.")
            else:
                logging.info(f"⏩ [WORKER {sample_id}] BAM final de {aligner} ya existe.")

        # ====================================================================
        # 6. Gestión del Ciclo de Vida de Datos (POST-EJECUCIÓN)
        # ====================================================================
        
        # Leemos parámetros (igual que en la limpieza retroactiva)
        retain_strict = tool_params.get("retain_only_fastqc_and_bam", False)
        cleanup_simple = tool_params.get("cleanup_only_fastq", False)

        # MODO AHORRO MÁXIMO
        if retain_strict:
            logging.info(f"🧹 [WORKER {sample_id}] MODO AHORRO MÁXIMO: Purgando intermedios post-run...")
            if os.path.exists(r1_raw): os.remove(r1_raw)
            if r2_raw and os.path.exists(r2_raw): os.remove(r2_raw)
            if os.path.exists(r1_trimmed): os.remove(r1_trimmed)
            if r2_trimmed and os.path.exists(r2_trimmed): os.remove(r2_trimmed)
            
            if 'alignments_dir_HISAT2' in paths:
                sam_file = os.path.join(paths['alignments_dir_HISAT2'], f"{sample_id}.sam")
                if os.path.exists(sam_file): os.remove(sam_file)
            
            if 'alignments_dir_STAR' in paths:
                star_out_prefix = os.path.join(paths['alignments_dir_STAR'], f"{sample_id}_")
                star_tmp_dir = f"{star_out_prefix}STARtmp"
                # Limpieza de carpetas temporales
                if os.path.exists(star_tmp_dir): shutil.rmtree(star_tmp_dir, ignore_errors=True)
                if os.path.exists(star_tmp_dir.replace("STARtmp", "_STARtmp")): shutil.rmtree(star_tmp_dir.replace("STARtmp", "_STARtmp"), ignore_errors=True)

        # MODO AHORRO INTERMEDIO
        elif cleanup_simple:
            logging.info(f"🧹 [WORKER {sample_id}] MODO AHORRO INTERMEDIO: Borrando crudos...")
            if os.path.exists(r1_raw): os.remove(r1_raw)
            if r2_raw and os.path.exists(r2_raw): os.remove(r2_raw)

        else:
            logging.info(f"💾 [WORKER {sample_id}] MODO DEBUG: Se conservan todos los archivos.")

        logging.info(f"🎉 [WORKER {sample_id}] Pipeline finalizado con éxito.")
        return f"OK: {sample_id}"

    except subprocess.CalledProcessError as e:
        logging.error(f"❌ [WORKER {sample_id}] ERROR FATAL. Comando: {' '.join(e.cmd)}")
        return f"ERROR: {sample_id}"

    except Exception as e:
        logging.error(f"❌ [WORKER {sample_id}] ERROR INESPERADO: {e}")
        return f"ERROR: {sample_id}"
       
# ==============================================================================
# SECCIÓN 3: FUNCIÓN PRINCIPAL Y ORQUESTACIÓN (CORREGIDA)
# ==============================================================================

def main():
    """Función principal que orquesta todo el pipeline."""
    parser = argparse.ArgumentParser(description="Pipeline de RNA-seq de extremo a extremo")
    parser.add_argument("-c", "--config", required=True, help="Archivo de configuración JSON.")
    args = parser.parse_args()
    
    try:
        with open(os.path.abspath(args.config), 'r') as f: config = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"❌ Error con el archivo de configuración: {e}"); return
    
    base_dir = config.get("project_setup", {}).get("base_dir", ".")
    create_directory(base_dir)
    setup_logging(os.path.join(base_dir, "pipeline.log"))
    
    logging.info("="*60 + "\n🚀 INICIANDO PIPELINE DE RNA-SEQ 🚀\n" + "="*60)

    setup_params = config.get("project_setup", {})
    source_params = config.get("source_data", {})
    images = config.get("container_images", {})
    tool_params = config.get("tool_parameters", {})
    threads = tool_params.get("threads", 8)
    download_threads = tool_params.get("download_threads", 8)
    counting_method = setup_params.get("counting_method", "featureCounts").lower()

    # =======================================================================
    # === LÓGICA CONDICIONAL PARA DISTINGUIR EL TIPO DE WORKFLOW ===
    # =======================================================================

    if counting_method == "precomputed_csv":
        # --- CAMINO A: Workflow desde Matriz de Conteos Precalculada ---
        logging.info("\n" + "="*20 + " INICIANDO WORKFLOW DESDE MATRIZ PRECALCULADA " + "="*20)
        
        reference_dir = os.path.join(base_dir, "REFERENCE_GENOMES_FILES")
        counts_dir = os.path.join(base_dir, "COUNTS")
        deseq2_dir = os.path.join(base_dir, "DESEQ2_RESULTS_PRECOMPUTED")
        for d in [reference_dir, counts_dir, deseq2_dir]: create_directory(d)

        logging.info("\n--- PASO 1: Descarga y Preparación de Datos ---")
        
        logging.info("🧠 Modo precalculado: buscando solo el archivo GTF necesario...")
        all_genome_urls = source_params.get("genome_urls", [])
        gtf_urls = [url for url in all_genome_urls if url.endswith(".gtf.gz")]
        
        if not gtf_urls:
            logging.error("❌ No se encontró una URL de archivo GTF en el JSON. Es necesario para la anotación."); return

        run_parallel_downloads(gtf_urls, reference_dir, download_threads)
        
        with concurrent.futures.ProcessPoolExecutor(max_workers=threads) as executor:
            unzip_files_parallel(reference_dir, executor)
        
        _, gtf_file = get_reference_files(reference_dir)
        if not gtf_file:
            logging.error("❌ No se encontró archivo GTF. Es necesario para el análisis funcional. Abortando."); return

        matrix_url = source_params.get("count_matrix_url")
        if not matrix_url:
            logging.error("❌ 'counting_method' es 'precomputed_csv' pero no se proveyó 'count_matrix_url'."); return
        
        counts_file_path = download_and_prepare_matrix(matrix_url, counts_dir)
        if not counts_file_path:
            logging.error("❌ No se pudo preparar la matriz de conteos. Abortando."); return

        logging.info("\n--- PASO 2: Análisis de Expresión Diferencial (DESeq2) ---")
        run_deseq2(config, deseq2_dir, counts_file_path, gtf_file)
        
        logging.info("\n--- PASO 3: Visualización de Análisis Funcional ---")
        run_enrichment_visualization(config, deseq2_dir)
        run_pdf_report_generator(config, deseq2_dir)

        

    else:
        # --- CAMINO B: Workflow desde FASTQ ---
        logging.info("\n" + "="*20 + " WORKFLOW COMPLETO DESDE FASTQ " + "="*20)

        # Definición de directorios como en tu original
        reference_dir = os.path.join(base_dir, "REFERENCE_GENOMES_FILES")
        fastq_dir = os.path.join(base_dir, "FASTQ_FILES")
        fastqc_dir = os.path.join(base_dir, "FASTQC")
        trimmed_dir = os.path.join(base_dir, "TRIMMED_READS")
        counts_dir = os.path.join(base_dir, "COUNTS")
        for d in [reference_dir, fastq_dir, fastqc_dir, trimmed_dir, counts_dir]: create_directory(d)
        
        # --- FASE 1: PREPARACIÓN DE RECURSOS GLOBALES (Genoma, Índices, Adaptadores) ---
        logging.info("\n--- FASE 1: Preparando Genoma y construyendo Índices ---")
        
        run_parallel_downloads(source_params.get("genome_urls", []), reference_dir, download_threads)
        with concurrent.futures.ProcessPoolExecutor(max_workers=threads) as executor:
            unzip_files_parallel(reference_dir, executor)
        
        fasta_file, gtf_file = get_reference_files(reference_dir)
        if not fasta_file or not gtf_file:
            logging.error("❌ No se encontraron archivos FASTA y/o GTF. Abortando."); return

        aligner_choice = setup_params.get("aligner", "star").lower()
        aligners_to_run = ["STAR", "HISAT2"] if aligner_choice == "both" else [aligner_choice.upper()] if aligner_choice in ["star", "hisat2"] else []
        
        # Diccionario 'paths' para pasar a los workers
        paths = {
            'fastq_dir': fastq_dir,
            'fastqc_dir': fastqc_dir, 
            'trimmed_dir': trimmed_dir,
            'reference_dir': reference_dir,
            'aligners_to_run': aligners_to_run
        }
        
        with concurrent.futures.ProcessPoolExecutor(max_workers=len(aligners_to_run) or 1) as executor:
            futures = []
            if "STAR" in aligners_to_run:
                alignments_dir_star = os.path.join(base_dir, "ALIGMENTS_STAR")
                create_directory(alignments_dir_star)
                paths['alignments_dir_STAR'] = alignments_dir_star
                futures.append(executor.submit(build_star_index, fasta_file, gtf_file, reference_dir, images.get("star"), threads, tool_params.get("star", {}).get("sjdbOverhang", 99)))
            if "HISAT2" in aligners_to_run:
                alignments_dir_hisat2 = os.path.join(base_dir, "ALIGMENTS_HISAT2")
                create_directory(alignments_dir_hisat2)
                paths['alignments_dir_HISAT2'] = alignments_dir_hisat2
                paths['hisat2_index_prefix'] = os.path.join(reference_dir, os.path.splitext(os.path.basename(fasta_file))[0])
                futures.append(executor.submit(build_hisat2_index, fasta_file, gtf_file, paths['hisat2_index_prefix'], images.get("hisat2")))
            concurrent.futures.wait(futures)

        logging.info("👍 Índices de alineadores construidos.")
        paths['adapters_file'] = prepare_adapters(base_dir, tool_params.get("trimmomatic", {}).get("adapter_fasta_url"))

        # --- FASE 2: PROCESAMIENTO DE MUESTRAS EN PARALELO ---
        logging.info("\n--- FASE 2: Procesando todas las muestras en paralelo ---")
        
        fastq_list_path = source_params.get("fastq_list_file")
        fastq_urls = read_urls_from_file(fastq_list_path) if fastq_list_path else []
        seq_type = setup_params.get("sequencing_type", "paired-end").lower()
        samples_to_process = group_fastqs_into_samples(fastq_urls, seq_type)

        if not samples_to_process:
            logging.error("❌ No se encontraron muestras para procesar. Verifica tu archivo de URLs."); return
        
        logging.info(f"Se procesarán {len(samples_to_process)} muestras.")
        
        max_parallel_samples = tool_params.get("max_parallel_samples", 4)
        with concurrent.futures.ProcessPoolExecutor(max_workers=max_parallel_samples) as executor:
            worker_func = partial(pipeline_worker_for_sample, config=config, paths=paths)
            results = list(executor.map(worker_func, samples_to_process))

        if any("ERROR" in res for res in results):
            logging.error("❌ Hubo errores durante el procesamiento de las muestras. Revisa el log. Abortando la fase de agregación."); return
        
        logging.info("✅ Todas las muestras han sido procesadas hasta la generación de BAMs.")

        # --- FASE 3: AGREGACIÓN Y ANÁLISIS FINAL (post-procesamiento) ---
        logging.info("\n--- FASE 3: Agregación, Conteo y Análisis Diferencial ---")
        
        for aligner in aligners_to_run:
            logging.info(f"\n{'='*20} WORKFLOW PARA {aligner} {'='*20}")
            
            alignments_dir = os.path.join(base_dir, f"ALIGMENTS_{aligner}")
            
            # --- PASO 5.5 (Opcional): Cuantificación (StringTie) y Análisis Exploratorio ---
            quant_options = setup_params.get("quantification_options", {})
            eda_output_dir = None
            if quant_options and quant_options.get("run_for", {}).get(aligner.lower()):
                logging.info(f"\n--- PASO ADICIONAL ({aligner}): Cuantificación y EDA ---")
                stringtie_dir = os.path.join(base_dir, f"STRINGTIE_{aligner}")
                matrix_prefix = os.path.join(counts_dir, f"{aligner}")
                run_stringtie_quantification(alignments_dir, gtf_file, stringtie_dir, images.get("stringtie"), threads)
                quant_methods = quant_options.get("run_for", {}).get(aligner.lower(), [])
                if quant_methods:
                    assemble_normalized_matrices(stringtie_dir, matrix_prefix, quant_methods)
                
                if quant_options.get("run_exploratory_analysis", False):
                    for matrix_type in quant_options.get("explore_on", []):
                        matrix_file_to_explore = f"{matrix_prefix}_{matrix_type}_matrix.tsv"
                        if os.path.exists(matrix_file_to_explore):
                            eda_output_dir = os.path.join(base_dir, f"EDA_RESULTS_{aligner}_{matrix_type.upper()}")
                            run_exploratory_analysis(config, matrix_file_to_explore, eda_output_dir)
                        else:
                            logging.warning(f"⚠️ No se encontró la matriz {matrix_file_to_explore} para EDA.")
            
            # --- PASO 6: Conteo (featureCounts) ---
            counts_file = os.path.join(counts_dir, f"counts_{aligner}.txt")
            logging.info(f"\n--- PASO FINAL 1 ({aligner}): Conteo ---")
            strand_val = tool_params.get("featurecounts", {}).get("strand_specific", 0)
            generate_count_matrix(alignments_dir, gtf_file, counts_file, images.get("featurecounts"), seq_type, threads, strand_val)
            
            # --- PASO 7: Análisis Diferencial (DESeq2) ---
            deseq2_dir = os.path.join(base_dir, f"DESEQ2_RESULTS_{aligner}")
            logging.info(f"\n--- PASO FINAL 2 ({aligner}): DESeq2 ---")
            run_deseq2(config, deseq2_dir, counts_file, gtf_file)
            # --- PASO 7.5: Visualizaciones y Reportes (Controlado por JSON), apagado encendido opciones de análisis de enrriquecimiento funcional y generacion pdf gprofiler
            func_config = config.get("functional_analysis", {})

            if func_config.get("run_enrichment_plots", False):
                logging.info(f"Iniciando Visualización de Enriquecimiento (r4) para {aligner}...")
                run_enrichment_visualization(config, deseq2_dir)
            else:
                logging.info(f"Visualización de Enriquecimiento (r4) no habilitada en JSON para {aligner}. Saltando.")

            if func_config.get("run_final_pdf_reports", False):
                logging.info(f"Iniciando Generación de PDF 'tocho' (r3) para {aligner}...")
                run_pdf_report_generator(config, deseq2_dir)
            else:
                logging.info(f"Generación de PDF 'tocho' (r3) no habilitada en JSON para {aligner}. Saltando.")
            
            # --- PASO 8: Informe Agregado (MultiQC) ---
            multiqc_dir = os.path.join(base_dir, f"MULTIQC_{aligner}_REPORT")
            logging.info(f"\n--- PASO FINAL 3 ({aligner}): MultiQC ---")
            paths_for_multiqc = [fastqc_dir, alignments_dir, counts_dir, deseq2_dir]
            if eda_output_dir: 
                paths_for_multiqc.append(eda_output_dir)
            run_multiqc(paths_for_multiqc, multiqc_dir, images.get("multiqc"))

        if aligner_choice == "both":
            compare_and_analyze_workflows(config)

    logging.info("\n🎉 ENHORABUENA. Pipeline completado exitosamente. 🎉")

if __name__ == "__main__":
    main()