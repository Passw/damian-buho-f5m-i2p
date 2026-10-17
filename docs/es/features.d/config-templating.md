<!--
SPDX-FileCopyrightText: 2026 Damián Búho <damian.buho@proton.me>

SPDX-License-Identifier: MIT
-->

<!-- textlint-disable terminology,common-misspellings -->

# Configuración de I2P renderizada con Jinja2

- El router, los túneles, los clientes, el wrapper y las opciones de la JVM se renderizan todos desde plantillas Jinja2 al inicio.
- La configuración renderizada se escribe en el directorio del router en cada inicio, así que cambiar una variable de entorno y recrear el contenedor es suficiente — no hace falta borrar el volumen.
- Cada subsistema de I2P (SAM, IRC, POP3, SMTP, Jetty, SSH, lanzamiento del navegador) se puede activar o desactivar mediante variables de entorno.
- La longitud y la cantidad de túneles de entrada y salida son configurables por túnel de eepsite.

<!-- textlint-enable -->
