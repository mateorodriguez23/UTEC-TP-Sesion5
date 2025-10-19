# Pipeline de Pruebas de Rendimiento con JMeter

Pipeline automatizado de pruebas de rendimiento usando **Apache JMeter** y **Docker** para evaluar APIs HTTP. Ejecuta pruebas contra `httpbin.org` y determina automáticamente pass/fail según umbrales configurables.

## Estructura del Proyecto

```
├── docker-compose.yml          # Orquestación del pipeline
├── test-plans/
│   └── api-performance.jmx     # Plan de pruebas JMeter
├── config/
│   ├── test.properties         # Configuración de parámetros
│   ├── run-tests.sh            # Script de ejecución
│   └── check-thresholds.sh     # Verificación de umbrales
├── results/                    # Resultados y reportes HTML
└── logs/                       # Logs de ejecución
```

## Configuración

### test.properties

Parámetros principales de la prueba:

```properties
# Carga
user_count=50                          # Usuarios concurrentes
ramp_up=120                            # Tiempo de rampeo (segundos)
test_duration=300                      # Duración total (segundos)

# API
base_protocol=https
base_host=httpbin.org

# Endpoints (simplificados)
endpoint_get=/get
endpoint_status_200=/status/200
endpoint_status_404=/status/404
endpoint_delay_1=/delay/1

# Umbrales
response_time_threshold_warning=1000   # Warning: >1s
response_time_threshold_error=3000     # Error: >3s
error_rate_threshold_warning=5         # Warning: >5%
error_rate_threshold_error=10          # Error: >10%
```

## Plan de Pruebas

El plan incluye 4 endpoints básicos de `httpbin.org`:

1. **GET /get** - Endpoint básico (espera 200)
2. **GET /status/200** - Código de estado exitoso (espera 200)
3. **GET /status/404** - Código de estado no encontrado (espera 404)
4. **GET /delay/1** - Endpoint con latencia de 1s (espera 200)

Todas las solicitudes se ejecutan con:
- **50 usuarios concurrentes**
- **Ramp-up de 2 minutos**
- **Duración de 5 minutos**
- **Loop infinito** durante la duración

## Verificación de Umbrales

El script `check-thresholds.sh` evalúa automáticamente:

| Métrica | Warning | Error | Resultado |
|---------|---------|-------|-----------|
| Tiempo de respuesta promedio | >1000ms | >3000ms | ADVERTENCIA / FALLIDO |
| Tasa de error | >5% | >10% | ADVERTENCIA / FALLIDO |

**Exit codes:**
- `0` = Prueba APROBADA (todos los umbrales dentro de límites)
- `1` = Prueba FALLIDA (al menos un umbral de error excedido)

## Uso

### Ejecución

```bash
# Ejecutar pruebas completas
docker compose up

# Ver logs en tiempo real
docker compose logs -f
```

### Resultados

Después de la ejecución se generan:

1. **`results/results.jtl`** - Resultados en formato CSV
2. **`results/html-report/`** - Dashboard HTML interactivo con gráficos y métricas detalladas
3. **`logs/jmeter.log`** - Logs de ejecución de JMeter

### Salida del Pipeline

```
=== Limpiando resultados previos ===
=== Iniciando pruebas de rendimiento ===
Created the tree successfully using /test-plans/api-performance.jmx
...
=== Pruebas completadas, verificando umbrales ===
=== Verificando umbrales de rendimiento ===

=== RESULTADOS DE LA PRUEBA ===
Total de solicitudes: 300
Tiempo de respuesta promedio: 3437.46ms
Tiempo de respuesta máximo: 28589ms
Tasa de error: 0.67%
Total de errores: 2

=== VERIFICACIÓN DE UMBRALES ===
FALLIDO: Tiempo de respuesta promedio (3437.46ms) > umbral de error (3000)
APROBADO: Tasa de error (0.67%)

RESULTADO FINAL: PRUEBA FALLIDA
```

## Personalización

Para ajustar los parámetros de prueba, modifica `config/test.properties`:

```properties
# Cambiar usuarios, duración, endpoints o umbrales
user_count=100
test_duration=600
response_time_threshold_error=5000
```

## Troubleshooting

- **Memoria insuficiente**: Ajustar `JVM_ARGS` en `docker-compose.yml`
- **Ver logs detallados**: `docker compose logs jmeter-master`
- **Limpiar resultados**: Automático en cada ejecución via `run-tests.sh`
- **Error de ejecución de scripts**: ejecutar chmod "+x" en el script que falla
