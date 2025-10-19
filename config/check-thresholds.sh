#!/bin/bash

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Uso: $0 <archivo_resultados.jtl>"
    exit 1
fi

RESULTS_FILE="$1"
if [ ! -f "$RESULTS_FILE" ]; then
    echo "Error: Archivo de resultados $RESULTS_FILE no encontrado"
    exit 1
fi

CONFIG_FILE="$(dirname "$0")/test.properties"

echo "=== Verificando umbrales de rendimiento ==="
echo "Archivo de resultados: $RESULTS_FILE"
echo ""

get_property_value() {
    local file="$1"
    local key="$2"

    if [ ! -f "$file" ]; then
        return 1
    fi

    grep "^${key}=" "$file" | head -n 1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

get_config_value() {
    local default_value="$1"
    shift

    local value
    for key in "$@"; do
        value="$(get_property_value "$CONFIG_FILE" "$key")"
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    done

    echo "$default_value"
}

read_stats_from_csv() {
    awk -F',' 'NR > 1 {
        count++
        response = $2 + 0
        total += response
        if (response > max) max = response
        success = $8
        if (success != "true") errors++
    }
    END {
        if (count > 0) {
            avg = total / count
            error_rate = (errors / count) * 100
            printf "%.0f %.0f %.2f %.2f %.0f\n", count, max, avg, error_rate, errors
        }
    }' "$RESULTS_FILE"
}

stats=$(read_stats_from_csv)
if [ -z "$stats" ]; then
    echo "Error: No se pudieron calcular las estadísticas del archivo $RESULTS_FILE"
    exit 1
fi

read TOTAL_REQUESTS MAX_RESPONSE_TIME AVG_RESPONSE_TIME ERROR_RATE TOTAL_ERRORS <<< "$stats"

TOTAL_REQUESTS=$(echo "$TOTAL_REQUESTS" | tr -d '[:space:]')
MAX_RESPONSE_TIME=$(echo "$MAX_RESPONSE_TIME" | tr -d '[:space:]')
AVG_RESPONSE_TIME=$(echo "$AVG_RESPONSE_TIME" | tr -d '[:space:]')
ERROR_RATE=$(echo "$ERROR_RATE" | tr -d '[:space:]')
TOTAL_ERRORS=$(echo "$TOTAL_ERRORS" | tr -d '[:space:]')

cat <<EOF
=== RESULTADOS DE LA PRUEBA ===
Total de solicitudes: $TOTAL_REQUESTS
Tiempo de respuesta promedio: ${AVG_RESPONSE_TIME}ms
Tiempo de respuesta máximo: ${MAX_RESPONSE_TIME}ms
Tasa de error: ${ERROR_RATE}%
Total de errores: $TOTAL_ERRORS

=== VERIFICACIÓN DE UMBRALES ===
EOF

WARNING_RT=$(get_config_value 1000 response_time_threshold_warning)
ERROR_RT=$(get_config_value 3000 response_time_threshold_error)
WARNING_ER=$(get_config_value 5 error_rate_threshold_warning)
ERROR_ER=$(get_config_value 10 error_rate_threshold_error)

THRESHOLDS_PASSED=true

compare_numbers() {
    local value="$1"
    local warning="$2"
    local error="$3"

    if ! echo "$value" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        return 2
    fi
    if ! echo "$warning" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        return 2
    fi
    if ! echo "$error" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        return 2
    fi

    if (( $(echo "$value > $error" | bc -l) )); then
        return 1
    fi

    if (( $(echo "$value > $warning" | bc -l) )); then
        return 3
    fi

    return 0
}

check_threshold() {
    local value="$1"
    local warning="$2"
    local error="$3"
    local label="$4"
    
    if compare_numbers "$value" "$warning" "$error"; then
        result=0
    else
        result=$?
    fi

    case $result in
        0)
            echo "APROBADO: $label"
            ;;
        1)
            echo "FALLIDO: $label > umbral de error ($error)"
            THRESHOLDS_PASSED=false
            ;;
        2)
            echo "ADVERTENCIA: No se pudo evaluar $label por valores no numéricos"
            ;;
        3)
            echo "ADVERTENCIA: $label > umbral de warning ($warning)"
            ;;
    esac
}

check_threshold "$AVG_RESPONSE_TIME" "$WARNING_RT" "$ERROR_RT" "Tiempo de respuesta promedio (${AVG_RESPONSE_TIME}ms)"
check_threshold "$ERROR_RATE" "$WARNING_ER" "$ERROR_ER" "Tasa de error (${ERROR_RATE}%)"

echo ""
if [ "$THRESHOLDS_PASSED" = true ]; then
    echo "RESULTADO FINAL: PRUEBA APROBADA"
    exit 0
else
    echo "RESULTADO FINAL: PRUEBA FALLIDA"
    exit 1
fi
