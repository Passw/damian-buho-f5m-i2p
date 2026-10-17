<!--
SPDX-FileCopyrightText: 2026 Damián Búho <damian.buho@proton.me>

SPDX-License-Identifier: MIT
-->

# Jinja2-rendered I2P configuration

- Router, tunnels, clients, wrapper, and JVM options all rendered from Jinja2 templates at startup.
- Rendered configuration is written into the router directory on every start, so changing an environment variable and recreating the container is enough — no volume wipe needed.
- Every I2P subsystem (SAM, IRC, POP3, SMTP, Jetty, SSH, browser launch) toggleable via environment variables.
- Inbound/outbound tunnel length and quantity configurable per eepsite tunnel.
