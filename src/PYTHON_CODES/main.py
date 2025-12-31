import argparse
import subprocess
import sys
import json
import os

# ==============================================================================
# SECCIÓN 1: FUNCIONES AUXILIARES
# ==============================================================================

def get_script_path(script_name):
    """Busca los scripts hermanos en la misma carpeta que este script."""
    base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, script_name)

def run_command(command, **kwargs):
    """Ejecuta un comando de sistema mostrando el output en tiempo real."""
    cmd_str = [str(c) for c in command]
    script_name = os.path.basename(command[0])
    
    print(f"INFO: Ejecutando sub-proceso -> {' '.join(cmd_str)}", flush=True)
    
    try:
        subprocess.run(
            [sys.executable] + cmd_str,
            check=True,
            capture_output=False, 
            text=True,
            **kwargs
        )
    except subprocess.CalledProcessError as e:
        print(f"\n❌ ERROR CRÍTICO: El script '{script_name}' falló.", flush=True)
        print(f"   Código de salida (Exit Code): {e.returncode}", flush=True)
        print(f"   Revisa los logs anteriores para ver el error específico.\n", flush=True)
        sys.exit(1)
    except FileNotFoundError:
        print(f"\n❌ ERROR: No se encontró el script '{command[0]}'.", flush=True)
        sys.exit(1)

# ==============================================================================
# SECCIÓN 2: LÓGICA PRINCIPAL (ORQUESTADOR)
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Script Maestro (Orquestador RNA-Seq)",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("-c", "--config", required=True, help="Ruta al archivo JSON de configuración.")
    parser.add_argument("-p", "--project_id", help="ID del proyecto (Opcional en modo Manual).")

    args = parser.parse_args()

    # --- 1. Localizar scripts satélite ---
    script_info = get_script_path("experiment_profiler.py")
    script_urls = get_script_path("data_conector.py") 
    script_core = get_script_path("01_pipeline_core.py")

    # Verificar que existen antes de hacer nada
    for s in [script_info, script_urls, script_core]:
        if not os.path.exists(s):
            print(f"❌ ERROR CONFIGURACIÓN: Falta el script necesario: {s}", flush=True)
            sys.exit(1)

    print("\nINFO: Leyendo configuración del JSON...", flush=True)
    try:
        config_path = os.path.abspath(args.config)
        with open(config_path, 'r') as f:
            config_data = json.load(f)

        # Extraer variables clave
        project_setup = config_data.get("project_setup", {})
        base_dir = project_setup.get("base_dir", ".")
        counting_method = project_setup.get("counting_method", "featurecounts")
        
        source_config = config_data.get("source_data", {})
        strategy = source_config.get("fastq_list_strategy", "automatic").lower()

        # Asegurar que el directorio base existe
        os.makedirs(base_dir, exist_ok=True)

    except Exception as e:
        print(f"❌ ERROR FATAL leyendo el archivo JSON: {e}", flush=True)
        sys.exit(1)

    # ====================================================================
    # --- VALIDACIÓN DE LOGICA SEGÚN ESTRATEGIA ---
    # ====================================================================
    
    # CASO: Estrategia AUTOMÁTICA -> El Project ID es OBLIGATORIO
    if strategy == "automatic" and not args.project_id:
        print("\n❌ ERROR DE LÓGICA: El JSON indica estrategia 'automatic'.")
        print("   Es OBLIGATORIO proporcionar un ID de proyecto (flag -p).", flush=True)
        sys.exit(1)

    # CASO: Estrategia MANUAL -> El Project ID es OPCIONAL.

    # ====================================================================
    # --- FASE 0: OBTENER INFORMACIÓN DEL EXPERIMENTO (PROFILER) ---
    # ====================================================================
    # Esta fase solo se ejecuta si el usuario proporcionó un ID (Modo Híbrido o Automático)
    if args.project_id:
        print("\n" + "-" * 10 + f" FASE 0: PROFILER ({args.project_id}) " + "-" * 10, flush=True)

        project_id_upper = args.project_id.upper()
        info_dir = os.path.join(base_dir, f"Info_{project_id_upper}")
        os.makedirs(info_dir, exist_ok=True)
        
        # Comprobar si ya existen datos para no descargarlos otra vez
        info_files = [f for f in os.listdir(info_dir) if f.startswith("info_") and f.endswith(".txt")]
        
        if info_files:
            print(f"✅ Información ya existente en {info_dir}. Saltando descarga de metadatos.", flush=True)
        else:
            run_command([script_info, args.project_id, "-d", info_dir])
    else:
        print("\nℹ️  FASE 0 OMITIDA: No se proporcionó Project ID (Modo Local Puro).", flush=True)

    # ====================================================================
    # --- CHECK DE FLUJO: ¿ES MATRIZ PRECALCULADA? ---
    # ====================================================================
    if counting_method == "precomputed_csv":
        print("\n" + "=" * 20 + " MODO: Matriz Precalculada " + "=" * 20, flush=True)
        print("ℹ️  Saltando gestión de FASTQ.", flush=True)
        run_command([script_core, "-c", config_path])
        return 

    # ====================================================================
    # --- FASE 1: GESTIÓN DE URLs FASTQ (Manual vs Automático) ---
    # ====================================================================
    print("\n" + "=" * 20 + " MODO: Análisis Completo desde FASTQ " + "=" * 20, flush=True)
    
    fastq_list_path_final = None

    if strategy == "manual":
        print("🟢 ESTRATEGIA DETECTADA: MANUAL", flush=True)
        print("   (Se usará el archivo de lista local indicado en el JSON)", flush=True)

        manual_fastq_list = source_config.get("fastq_list_file")
        if not manual_fastq_list:
            print("❌ ERROR: El campo 'fastq_list_file' está vacío en el JSON.", flush=True)
            sys.exit(1)

        # Resolver ruta absoluta si viene relativa
        if os.path.isabs(manual_fastq_list):
            fastq_list_path_final = manual_fastq_list
        else:
            config_dir = os.path.dirname(config_path)
            fastq_list_path_final = os.path.abspath(os.path.join(config_dir, manual_fastq_list))

        if not os.path.exists(fastq_list_path_final):
            print(f"❌ ERROR CRÍTICO: No existe el archivo manual: {fastq_list_path_final}", flush=True)
            print("   Asegúrate de haber ejecutado el script 'download_samples.sh' primero.", flush=True)
            sys.exit(1)

        print(f"📄 Archivo de muestras validado: {fastq_list_path_final}", flush=True)

    elif strategy == "automatic":
        print("🔵 ESTRATEGIA DETECTADA: AUTOMÁTICA", flush=True)
        print("   (Se buscarán las URLs de descarga en ENA/SRA)", flush=True)

        fastq_list_filename = f"{args.project_id}_fastq_urls.txt"
        fastq_list_path_autogen = os.path.join(base_dir, fastq_list_filename)

        if not os.path.exists(fastq_list_path_autogen) or os.path.getsize(fastq_list_path_autogen) == 0:
            print("⬇️  Generando lista de URLs automáticamente...", flush=True)
            run_command([script_urls, args.project_id, "-o", fastq_list_path_autogen])
        else:
            print(f"✅ Lista de URLs ya existe: {fastq_list_path_autogen}", flush=True)

        if not os.path.exists(fastq_list_path_autogen) or os.path.getsize(fastq_list_path_autogen) == 0:
            print("❌ ERROR: El Data Connector no generó URLs válidas.", flush=True)
            sys.exit(1)

        fastq_list_path_final = os.path.abspath(fastq_list_path_autogen)

        print("INFO: Actualizando JSON con la ruta de FASTQs automáticos...", flush=True)
        config_data['source_data']['fastq_list_file'] = fastq_list_path_final
        with open(config_path, 'w') as f:
            json.dump(config_data, f, indent=2)

    else:
        print(f"❌ ERROR: Estrategia desconocida en JSON: {strategy}", flush=True)
        sys.exit(1)

    # ====================================================================
    # --- FASE 2: EJECUTAR PIPELINE CORE ---
    # ====================================================================
    print("\n" + "-" * 10 + " FASE 2: INICIANDO PIPELINE CORE " + "-" * 10, flush=True)
    
    run_command([script_core, "-c", config_path])

    print("\n🎉 ¡ÉXITO TOTAL! El orquestador ha completado todas las tareas.", flush=True)

if __name__ == "__main__":
    main()