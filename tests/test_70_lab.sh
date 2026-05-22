#!/usr/bin/env bash
# shellcheck shell=bash
#
# tests/test_70_lab.sh — sandboxed tests for modules/70-lab.sh.
# Cannot exercise the real Docker, Avahi, or systemd state; instead asserts on:
#   - templates exist with the expected critical content
#   - the vendored avahi-aliases binary is present, executable, and Py3
#   - smoke_70_lab references each deep-scope acceptance criterion
#   - dry-run output enumerates the deep-scope work without side effects

test_70_traefik_compose_template_exists() {
    local f="${REPO_ROOT}/templates/srv/data/lab/compose/traefik/docker-compose.yml"
    if [[ ! -f "${f}" ]]; then
        printf 'file not found: %s\n' "${f}"
        return 1
    fi
    if ! grep -Fq 'image: traefik:' "${f}"; then
        printf "expected 'image: traefik:' in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq -- '--providers.docker.exposedByDefault=false' "${f}"; then
        printf "expected '--providers.docker.exposedByDefault=false' in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq -- '--entrypoints.web.address=:80' "${f}"; then
        printf "expected web entrypoint :80 in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq -- '--entrypoints.websecure.address=:443' "${f}"; then
        printf "expected websecure entrypoint :443 in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq '/var/run/docker.sock' "${f}"; then
        printf "expected docker.sock mount in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq 'external: true' "${f}"; then
        printf "expected 'external: true' (traefik-proxy network) in %s\n" "${f}"; return 1
    fi
    return 0
}

test_70b_whoami_compose_template_exists() {
    local f="${REPO_ROOT}/templates/srv/data/lab/compose/whoami/docker-compose.yml"
    if [[ ! -f "${f}" ]]; then
        printf 'file not found: %s\n' "${f}"; return 1
    fi
    if ! grep -Fq 'traefik/whoami' "${f}"; then
        printf "expected 'traefik/whoami' image in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq 'traefik.enable=true' "${f}"; then
        printf "expected 'traefik.enable=true' label in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq 'Host(`whoami.local`)' "${f}"; then
        printf "expected Host(\`whoami.local\`) rule in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq 'traefik.http.routers.whoami.entrypoints=web' "${f}"; then
        printf "expected web entrypoint on the whoami router in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq 'external: true' "${f}"; then
        printf "expected 'external: true' (traefik-proxy network) in %s\n" "${f}"; return 1
    fi
    return 0
}

test_71_avahi_aliases_service_template_exists() {
    local f="${REPO_ROOT}/templates/etc/systemd/system/avahi-aliases.service"
    if [[ ! -f "${f}" ]]; then
        printf 'file not found: %s\n' "${f}"; return 1
    fi
    if ! grep -Fq 'After=avahi-daemon.service' "${f}"; then
        printf "expected 'After=avahi-daemon.service' in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq 'ExecStart=/usr/local/sbin/avahi-aliases /etc/avahi/aliases' "${f}"; then
        printf "expected ExecStart pointing at vendored binary in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq 'Restart=always' "${f}"; then
        printf "expected 'Restart=always' in %s\n" "${f}"; return 1
    fi
    return 0
}

test_71b_avahi_aliases_path_template_exists() {
    local f="${REPO_ROOT}/templates/etc/systemd/system/avahi-aliases.path"
    if [[ ! -f "${f}" ]]; then
        printf 'file not found: %s\n' "${f}"; return 1
    fi
    if ! grep -Fq 'PathChanged=/etc/avahi/aliases' "${f}"; then
        printf "expected 'PathChanged=/etc/avahi/aliases' in %s\n" "${f}"; return 1
    fi
    if ! grep -Fq 'TriggerLimitIntervalSec=5' "${f}"; then
        printf "expected 'TriggerLimitIntervalSec=5' in %s\n" "${f}"; return 1
    fi
    return 0
}

test_72_vendored_avahi_aliases_binary_present_and_py3() {
    local f="${REPO_ROOT}/lib/avahi-aliases/avahi-aliases"
    if [[ ! -f "${f}" ]]; then
        printf 'file not found: %s\n' "${f}"; return 1
    fi
    if [[ ! -x "${f}" ]]; then
        printf 'file not executable: %s\n' "${f}"; return 1
    fi
    if ! head -1 "${f}" | grep -Eq '^#!/usr/bin/env python3'; then
        printf "expected python3 shebang in %s\n" "${f}"; return 1
    fi
    # smoke-check the source is valid Python 3 syntax
    if ! python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "${f}" >/dev/null 2>&1; then
        printf 'python3 ast.parse failed for %s\n' "${f}"; return 1
    fi
    if ! grep -Fq 'TYPE_CNAME' "${f}"; then
        printf "expected TYPE_CNAME constant in %s\n" "${f}"; return 1
    fi
    return 0
}

test_72b_vendored_md_documents_upstream() {
    local f="${REPO_ROOT}/lib/avahi-aliases/VENDORED.md"
    if [[ ! -f "${f}" ]]; then
        printf 'file not found: %s\n' "${f}"; return 1
    fi
    if ! grep -Fq 'airtonix/avahi-aliases' "${f}"; then
        printf "expected upstream URL reference in %s\n" "${f}"; return 1
    fi
    if ! grep -Eq '[0-9a-f]{40}' "${f}"; then
        printf "expected upstream sha (40-hex) in %s\n" "${f}"; return 1
    fi
    return 0
}

test_72c_vendored_license_present() {
    local f="${REPO_ROOT}/lib/avahi-aliases/LICENSE"
    if [[ ! -f "${f}" ]]; then
        printf 'file not found: %s\n' "${f}"; return 1
    fi
    if ! grep -Fq 'MIT License' "${f}"; then
        printf "expected 'MIT License' in %s\n" "${f}"; return 1
    fi
    return 0
}

test_73_dry_run_70_lab_exits_zero_and_enumerates_deep_scope() {
    local sandbox output rc
    sandbox="$(mk_sandbox)"
    trap 'trap - RETURN; rm -rf -- "${sandbox}"' RETURN
    write_secrets "${sandbox}"
    output="$(HOME="${sandbox}/home" "${sandbox}/run.sh" --dry-run 70-lab 2>&1)" && rc=0 || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        printf 'expected exit 0 in dry-run mode, got %s\n' "${rc}"
        printf '%s\n' "${output}"
        return 1
    fi
    local needle
    for needle in "70-lab" "dry-run" "avahi" "traefik-proxy" "/etc/avahi/aliases" "compose"; do
        if [[ "${output}" != *"${needle}"* ]]; then
            printf "expected '%s' in dry-run output\n" "${needle}"
            printf '%s\n' "${output}"
            return 1
        fi
    done
    return 0
}

test_74_smoke_70_lab_covers_acceptance_criteria() {
    local body
    body="$(
        awk '
            /^smoke_70_lab\(\)[[:space:]]*\{/ { in_fn=1 }
            in_fn { print }
            in_fn && /^}[[:space:]]*$/ { exit }
        ' "${REPO_ROOT}/modules/70-lab.sh"
    )"

    if [[ -z "${body}" ]]; then
        printf 'smoke_70_lab not found in modules/70-lab.sh\n'
        return 1
    fi

    local needle
    for needle in \
            "docker-ce" \
            "DockerRootDir" \
            "/srv/data/docker" \
            "avahi-daemon" \
            "avahi-aliases.service" \
            "avahi-aliases.path" \
            "avahi-aliases-restart.service" \
            "/usr/local/sbin/avahi-aliases" \
            "traefik-proxy" \
            "whoami.local" \
            "curl"; do
        if [[ "${body}" != *"${needle}"* ]]; then
            printf "smoke_70_lab missing check for: %s\n" "${needle}"
            return 1
        fi
    done
    return 0
}

test_75_70_lab_uses_guards_for_destructive_verbs() {
    # The pre-commit hook enforces this, but worth a unit-level guard so the
    # tests catch regressions even when the hook isn't installed.
    local m="${REPO_ROOT}/modules/70-lab.sh"
    if ! grep -Fq 'guard::docker_network_exists traefik-proxy' "${m}"; then
        printf "expected guard::docker_network_exists traefik-proxy in %s\n" "${m}"; return 1
    fi
    if ! grep -Fq 'guard::container_running' "${m}"; then
        printf "expected guard::container_running in %s\n" "${m}"; return 1
    fi
    if ! grep -Fq 'guard::file_has_line /etc/avahi/aliases' "${m}"; then
        printf "expected guard::file_has_line for /etc/avahi/aliases in %s\n" "${m}"; return 1
    fi
    return 0
}
