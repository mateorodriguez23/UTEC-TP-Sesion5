#!/bin/sh

set -euo pipefail

mkdir -p /logs
JMETER_LOG=/logs/jmeter.log
echo "" > "$JMETER_LOG"

echo '=== Limpiando resultados previos ==='
rm -f /results/results.jtl
rm -rf /results/html-report
mkdir -p /results/html-report

echo '=== Iniciando pruebas de rendimiento ==='
jmeter -n -t /test-plans/api-performance.jmx \
  -p /config/test.properties \
  -l /results/results.jtl \
  -e -o /results/html-report \
  -j "$JMETER_LOG" || {
    echo '=== Error durante la ejecución de JMeter ==='
    echo 'Últimas líneas del log:'
    tail -n 50 "$JMETER_LOG"
    exit 1
  }
echo '=== Pruebas completadas, verificando umbrales ==='

/config/check-thresholds.sh /results/results.jtl

echo '=== Pipeline completado exitosamente ==='

