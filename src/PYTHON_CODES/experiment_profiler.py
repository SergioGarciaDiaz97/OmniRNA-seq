#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import requests
import argparse
import sys
import time
import re
from xml.etree import ElementTree as ET
import os

try:
    from bs4 import BeautifulSoup, NavigableString
except ImportError:
    print("ERROR: Necesitas instalar 'beautifulsoup4' y 'lxml'. Ejecuta: pip install beautifulsoup4 lxml")
    sys.exit(1)

# URLs de los servicios
EUTILS_BASE_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"
GEO_BROWSE_URL = "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi"
ENA_API_URL = "https://www.ebi.ac.uk/ena/portal/api/filereport"

# --- Base de datos de adaptadores comunes ---
ADAPTER_SEQUENCES = {
    "truseq": "AGATCGGAAGAGC",
    "nextera": "CTGTCTCTTATACACATCT",
    "small rna": "TGGAATTCTCGG"
}

def api_request_xml(url: str):
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        return ET.fromstring(response.content)
    except requests.exceptions.RequestException as e:
        print(f"ERROR: Fallo en la petición a la API: {e}")
    return None

def get_gse_from_prjna(project_id: str) -> str | None:
    print(f"INFO: 1/4 - Buscando el ID de GEO (GSE) para {project_id}...")
    search_url = f"{EUTILS_BASE_URL}esearch.fcgi?db=gds&term={project_id}[BioProject]"
    root = api_request_xml(search_url)
    if root is None: return None
    gds_id = root.find(".//Id")
    if gds_id is None: return None
    summary_url = f"{EUTILS_BASE_URL}esummary.fcgi?db=gds&id={gds_id.text}"
    summary_root = api_request_xml(summary_url)
    if summary_root is None: return None
    gse_el = summary_root.find(".//Item[@Name='Accession']")
    if gse_el is not None:
        return gse_el.text
    return None

def get_study_info_from_page(gse_id: str, first_gsm_id: str = None) -> dict:
    print(f"INFO: 2/4 - Obteniendo metadatos del estudio {gse_id}...")
    info = {
        "title": "No encontrado", "organism": "No encontrado", "summary": "No encontrado", 
        "data_processing": "No encontrado", "submission_date": "No encontrado", 
        "update_date": "No encontrado", "contact_name": "No encontrado",
        "assembly": "No especificado", "adapter_kit": "No especificado", "adapter_seq": "No especificada"
    }
    try:
        if first_gsm_id:
            gsm_response = requests.get(f"{GEO_BROWSE_URL}?acc={first_gsm_id}", timeout=30)
            gsm_soup = BeautifulSoup(gsm_response.text, 'lxml')

            def find_field_text(soup_obj, field_name):
                header = soup_obj.find(['td', 'th'], string=re.compile(r'^\s*' + field_name + r'\s*$', re.IGNORECASE))
                if header and header.find_next_sibling(['td', 'th']):
                    return header.find_next_sibling(['td', 'th']).get_text(separator="\n", strip=True)
                return None

            info["organism"] = find_field_text(gsm_soup, "Organism") or "No encontrado"
            info["data_processing"] = find_field_text(gsm_soup, "Data processing") or "No encontrado"
            info["contact_name"] = find_field_text(gsm_soup, "Contact name") or "No encontrado"
            info["submission_date"] = find_field_text(gsm_soup, "Submission date") or "No encontrado"
            info["update_date"] = find_field_text(gsm_soup, "Last update date") or "No encontrado"
            instrument_model = find_field_text(gsm_soup, "Instrument model") or ""
            library_prep_text = find_field_text(gsm_soup, "Extraction protocol") or ""
        
        # Obtenemos Título y Resumen general de la página principal del estudio
        gse_response = requests.get(f"{GEO_BROWSE_URL}?acc={gse_id}", timeout=30)
        gse_soup = BeautifulSoup(gse_response.text, 'lxml')
        info["title"] = find_field_text(gse_soup, "Title") or info["title"]
        info["summary"] = find_field_text(gse_soup, "Summary") or info["summary"]

        if info["data_processing"]:
            assembly_match = re.search(r"Assembly:\s*(.*)", info["data_processing"], re.IGNORECASE)
            if assembly_match: info["assembly"] = assembly_match.group(1).strip()
            
            found_adapter = False
            full_text_to_search = info["data_processing"] + " " + library_prep_text
            for adapter_key, adapter_seq in ADAPTER_SEQUENCES.items():
                if adapter_key in full_text_to_search.lower():
                    info["adapter_kit"] = adapter_key
                    info["adapter_seq"] = adapter_seq
                    found_adapter = True
                    break
            
            if not found_adapter and 'illumina' in instrument_model.lower():
                info["adapter_kit"] = "Inferido de 'Illumina'"
                info["adapter_seq"] = ADAPTER_SEQUENCES["truseq"]

    except Exception as e:
        print(f"AVISO: No se pudieron extraer los metadatos: {e}")
    return info

def get_gsm_list_from_gse(gse_id: str) -> list[dict]:
    """Obtiene la lista básica de muestras (GSM y Título) de un GSE."""
    print(f"INFO: 3/4 - Obteniendo lista de muestras (GSM) para {gse_id}...")
    samples = []
    search_url = f"{EUTILS_BASE_URL}esearch.fcgi?db=gds&term={gse_id}[Accession]"
    root = api_request_xml(search_url)
    if root is None: return []
    gds_id = root.find(".//Id")
    if gds_id is None: return []
    summary_url = f"{EUTILS_BASE_URL}esummary.fcgi?db=gds&id={gds_id.text}"
    summary_root = api_request_xml(summary_url)
    if summary_root is None: return []
    for item in summary_root.findall(".//Item[@Name='Sample']"):
        acc = item.findtext("./Item[@Name='Accession']")
        title = item.findtext("./Item[@Name='Title']")
        if acc and title:
            samples.append({"gsm": acc, "title": title, "srr": "Buscando..."})
    print(f"INFO: Se encontraron {len(samples)} muestras.")
    return samples

def get_srr_from_gsm_page(gsm_id: str) -> str:
    """Visita la página de un GSM individual, extrae el SRX y lo convierte a SRR."""
    try:
        gsm_url = f"{GEO_BROWSE_URL}?acc={gsm_id}"
        response = requests.get(gsm_url, timeout=30)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, 'lxml')
        sra_link = soup.find('a', href=re.compile(r"term=SRX\d+"))
        if not sra_link: return "SRX not found"
        srx_id = sra_link.text.strip()
        ena_url = f"{ENA_API_URL}?accession={srx_id}&result=read_run&fields=run_accession&format=tsv"
        srr_response = requests.get(ena_url, timeout=30)
        srr_response.raise_for_status()
        srr_data = srr_response.text.strip().split('\n')
        if len(srr_data) > 1: return srr_data[1].strip()
        else: return "SRR not found"
    except Exception:
        return "Error"

def find_ensembl_urls(organism: str, data_processing_text: str) -> dict:
    """Construye y verifica los enlaces de descarga de Ensembl para el genoma y la anotación."""
    print("INFO: 4/4 - Buscando enlaces de genoma y anotación en Ensembl...")
    urls = {"fasta": "No encontrado", "gtf": "No encontrado"}
    if not organism or not data_processing_text or organism == "No encontrado":
        return urls
    
    match = re.search(r"Assembly:\s*([\w._-]+)\s*(?:version|\s*v)?\s*(\d+)", data_processing_text, re.IGNORECASE)
    if not match: return urls
    
    assembly_full_name, version = match.group(1).strip(), match.group(2).strip()
    organism_path = organism.lower().replace(" ", "_")
    organism_filename = organism.capitalize().replace(" ", "_")
    base_url = f"http://ftp.ensembl.org/pub/release-{version}"
    assembly_short_name = assembly_full_name.split('.')[-1]
    
    fasta_filename = f"{organism_filename}.{assembly_short_name}.dna.toplevel.fa.gz"
    gtf_filename = f"{organism_filename}.{assembly_short_name}.{version}.gtf.gz"
    fasta_url = f"{base_url}/fasta/{organism_path}/dna/{fasta_filename}"
    gtf_url = f"{base_url}/gtf/{organism_path}/{gtf_filename}"
    
    try:
        if requests.head(fasta_url, timeout=10).status_code == 200: urls["fasta"] = fasta_url
    except: pass
    try:
        if requests.head(gtf_url, timeout=10).status_code == 200: urls["gtf"] = gtf_url
    except: pass
    return urls

def write_simple_sample_list(filename: str, samples: list[dict]):
    """Crea el archivo .txt simple con GSM, SRR y Título."""
    try:
        with open(filename, 'w', encoding='utf-8') as f:
            f.write("GSM\tSRR\tTitle\n")
            for sample in samples:
                f.write(f"{sample['gsm']}\t{sample['srr']}\t{sample['title']}\n")
        print(f"INFO: Creada lista simple de muestras en: {filename}")
    except IOError as e:
        print(f"ERROR: No se pudo crear la lista de muestras: {e}")

def main():
    parser = argparse.ArgumentParser(description="Genera un informe y una lista de muestras para un estudio de NCBI.")
    parser.add_argument("project_id", help="El ID del BioProject (ej. PRJNA843039) o GSE.")
    parser.add_argument("-d", "--directory", default=".", help="Directorio donde guardar los archivos de salida.")
    args = parser.parse_args()
    
    project_id = args.project_id.upper()
    gse_id = None
    if project_id.startswith("PRJNA"):
        gse_id = get_gse_from_prjna(project_id)
    elif project_id.startswith("GSE"):
        gse_id = project_id
    if not gse_id:
        print(f"ERROR: No se pudo encontrar un estudio GSE para {project_id}.")
        sys.exit(1)
        
    samples = get_gsm_list_from_gse(gse_id)
    first_gsm_id = samples[0]['gsm'] if samples else None
    study_info = get_study_info_from_page(gse_id, first_gsm_id)
    ensembl_urls = find_ensembl_urls(study_info['organism'], study_info['data_processing'])
    
    print(f"INFO: Buscando SRR para cada muestra. Esto puede tardar...")
    for i, sample in enumerate(samples):
        print(f"      Procesando muestra {i+1}/{len(samples)}: {sample['gsm']}", end='\r')
        sample['srr'] = get_srr_from_gsm_page(sample['gsm'])
        time.sleep(0.5)
    print("\nINFO: Búsqueda completada.")
    
    # --- Generar los dos archivos de salida ---
    report_filename = os.path.join(args.directory, f"info_experiment_{project_id}_{gse_id}.txt")
    list_filename = os.path.join(args.directory, f"list_of_samples_experiment_{project_id}_{gse_id}.txt")
    
    report_lines = [
        "==========================================================================================",
        f" INFORME DEL ESTUDIO: {gse_id} (desde {project_id})",
        "==========================================================================================",
        f"TÍTULO:           {study_info['title']}",
        f"Organismo:        {study_info['organism']}",
        f"Contacto:         {study_info['contact_name']}",
        f"Fecha de envío:   {study_info['submission_date']}",
        f"Última act.:      {study_info['update_date']}",
        "\n--- DISEÑO GENERAL (OVERALL DESIGN) ---",
        study_info['summary'],
        "\n--- PROCESAMIENTO DE DATOS (DATA PROCESSING) ---",
        study_info['data_processing'],
        "\n--- SUGERENCIAS PARA REPRODUCIBILIDAD ---",
        f"Se han encontrado los siguientes archivos en Ensembl para este ensamblaje:",
        f" - Genoma de Referencia (FASTA): {ensembl_urls['fasta']}",
        f" - Anotación del Genoma (GTF):   {ensembl_urls['gtf']}",
        f" - Adaptador sugerido (Trimming): {study_info['adapter_seq']} (basado en el kit/instrumento: '{study_info['adapter_kit']}')",
        "\n--- MUESTRAS ---",
        "GSM\t\tSRR\t\tTítulo",
        "------------------------------------------------------------------------------------------"
    ]
    for s in samples:
        report_lines.append(f"{s['gsm']:<15}{s['srr']:<15}{s['title']}")
    report_lines.append("==========================================================================================")
    
    try:
        with open(report_filename, 'w', encoding='utf-8') as f: f.write("\n".join(report_lines))
        print(f"\n✅ ¡Éxito! Informe completo guardado en: {report_filename}")
    except IOError as e:
        print(f"\n❌ ERROR: No se pudo escribir el informe en {report_filename}: {e}")

    write_simple_sample_list(list_filename, samples)

if __name__ == "__main__":
    main()