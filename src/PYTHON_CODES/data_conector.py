import argparse
import requests
import pandas as pd
import sys
from io import StringIO

def fetch_fastq_urls(project_id, output_file):
    """
    Se conecta al API de ENA para obtener las URLs de los archivos FASTQ
    de un proyecto y las guarda en un archivo de texto.
    """
    print(f"INFO: Conectando con la base de datos de ENA para el proyecto {project_id}...")
    
    # URL del API de ENA para obtener un informe de los archivos de un proyecto
    ENA_API_URL = (
        f"https://www.ebi.ac.uk/ena/portal/api/filereport?"
        f"accession={project_id}"
        f"&result=read_run"
        f"&fields=run_accession,fastq_ftp"
        f"&format=tsv"
        f"&download=true"
    )
    
    try:
        # Realizar la petición al API
        response = requests.get(ENA_API_URL)
        response.raise_for_status()  
        
        if not response.text.strip():
            print(f"AVISO: La base de datos no devolvió información para el proyecto {project_id}.")
            open(output_file, 'w').close()
            return

        df = pd.read_csv(StringIO(response.text), sep='\t')
        
        if 'fastq_ftp' not in df.columns:
            print(f"ERROR: No se encontró la columna 'fastq_ftp' para el proyecto {project_id}.")
            print("       El proyecto podría no tener datos de secuenciación públicos.")
            open(output_file, 'w').close()
            return

        # Procesar las URLs
        all_urls = []
        for urls in df['fastq_ftp'].dropna():
            all_urls.extend(urls.split(';'))
            
        if not all_urls:
            print(f"AVISO: No se encontraron URLs de FASTQ para el proyecto {project_id}.")
            open(output_file, 'w').close()
            return
            
        with open(output_file, 'w') as f:
            for url in all_urls:
                f.write(f"ftp://{url}\n")
        
        print(f"\n¡ÉXITO! Se ha generado el archivo '{output_file}' con {len(all_urls)} URLs.")

    except requests.exceptions.RequestException as e:
        print(f"ERROR: Fallo en la conexión con el API de ENA: {e}")
        sys.exit(1) 
    except Exception as e:
        print(f"ERROR: Ocurrió un error inesperado al procesar los datos: {e}")
        sys.exit(1) 


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generador automático de URLs de FASTQ a partir de un ID de proyecto SRA/GEO.")
    parser.add_argument("project_id", help="El ID del proyecto.")
    parser.add_argument("-o", "--output", help="Nombre del archivo de salida (opcional). Por defecto, se usará 'ID_DEL_PROYECTO_fastq_urls.txt'.")
    
    args = parser.parse_args()
    
    output_filename = args.output
    if not output_filename:
        output_filename = f"{args.project_id}_fastq_urls.txt"
    
    fetch_fastq_urls(args.project_id, output_filename)