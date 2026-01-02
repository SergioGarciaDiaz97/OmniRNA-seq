#!/bin/bash
#SBATCH --job-name=RNAseq_Master
#SBATCH --output=logs/RNAseq_Master_%j.out
#SBATCH --error=logs/RNAseq_Master_%j.err
#SBATCH --partition=main
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --time=24:00:00
#SBATCH --mem=280G

# ==============================================================================
# SCRIPT DE LANZAMIENTO (SLURM WRAPPER)
# ==============================================================================

# --- 1. Argumentos de entrada ---
# $1: Ruta al archivo de configuración JSON (OBLIGATORIO).
# $2: ID del proyecto (OPCIONAL: PRJNA..., SRP..., GSE...).

CONFIG_JSON=$1
PROJECT_ID=$2

# --- 2. Comprobación de seguridad ---
if [ -z "$CONFIG_JSON" ]; then
    echo "❌ Error: Falta el archivo de configuración JSON."
    echo "Uso correcto:"
    echo "  > Modo Híbrido/Auto: sbatch RNA_SEQ_LETS_TRY.sh JSON/config.json PRJNA12345"
    echo "  > Modo Local Puro:   sbatch RNA_SEQ_LETS_TRY.sh JSON/config.json"
    exit 1
fi

# --- 3. Configuración del Entorno ---
mkdir -p logs
set -e  # Detener script si hay errores (pero no -x para no saturar el log)

# Función de limpieza al terminar (Trap)
cleanup() {
    echo "🧹 [SLURM] Limpiando carpeta temporal de Apptainer..."
    if [ -d "$APPTAINER_TMPDIR" ]; then
        rm -rf "$APPTAINER_TMPDIR"
    fi
    echo "✅ Limpieza completada."
}
trap cleanup EXIT TERM INT

# Definición de rutas clave
# [IMPORTANTE] Cambia esta ruta por tu directorio HOME real antes de ejecutar
HOME_BEEGFS="/path/to/your/home/directory" 
# Ejemplo: HOME_BEEGFS="/mnt/beegfs/home/usuario"

# Configuración de temporales para Apptainer (Vital para evitar discos llenos)
export APPTAINER_TMPDIR="${HOME_BEEGFS}/apptainer_tmp/${SLURM_JOB_ID}"
mkdir -p "$APPTAINER_TMPDIR"
export APPTAINER_CACHEDIR="${HOME_BEEGFS}/apptainer_cache"
mkdir -p "$APPTAINER_CACHEDIR"

# Configuración de librerías de R (Para que no choque con las del sistema)
export R_LIBS_USER="${HOME_BEEGFS}/R_libs_personal"
mkdir -p "$R_LIBS_USER"
export APPTAINERENV_R_LIBS_USER=$R_LIBS_USER

# Detección inteligente del motor de contenedores
if command -v apptainer &> /dev/null; then
    export APPTAINER_CMD=apptainer
elif command -v singularity &> /dev/null; then
    export APPTAINER_CMD=singularity
else
    echo "❌ Error: No se encontró Apptainer ni Singularity."
    exit 1
fi
echo "🐳 Usando motor de contenedor: $APPTAINER_CMD"

# --- 4. Dependencias de Python ---
# Aseguramos que las librerías necesarias para el orquestador estén presentes
echo "🐍 [PYTHON] Verificando dependencias mínimas..."
python3 -m pip install --user --quiet pandas requests argparse

# --- 5. Ejecución del Script Maestro ---
echo "🚀 [START] Iniciando el orquestador del pipeline..."
echo "   📂 Configuración: $CONFIG_JSON"

# Lógica condicional para construir el comando
if [ -z "$PROJECT_ID" ]; then
    # CASO: MANUAL PURO (Sin ID) - El script Python leerá solo el JSON
    echo "   ℹ️  Modo detectado: LOCAL PURO (Sin Project ID)"
    python3 src/PYTHON_CODES/main.py -c "$CONFIG_JSON"
else
    # CASO: HÍBRIDO O AUTOMÁTICO (Con ID)
    echo "   ℹ️  Modo detectado: CON PROYECTO ($PROJECT_ID)"
    python3 src/PYTHON_CODES/main.py -c "$CONFIG_JSON" -p "$PROJECT_ID"
fi

echo "✅ [FIN] El job de SLURM ha finalizado correctamente."
