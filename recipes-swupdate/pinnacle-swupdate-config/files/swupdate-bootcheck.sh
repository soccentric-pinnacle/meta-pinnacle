#!/bin/bash
# swupdate-bootcheck.sh — health check that confirms OTA or triggers rollback.
#
# Runs after local-fs.target (before network.target) to ensure the health
# check completes BEFORE network services start. If the health check fails,
# the system rolls back before any network exposure.

set -euo pipefail

BOOT_STATE=/boot/boot_state

if [[ ! -f "${BOOT_STATE}" ]]; then
    exit 0
fi

slot=""
tries_remaining=""
confirmed=""
while IFS='=' read -r key value; do
    case "${key}" in
        slot)            slot="${value}" ;;
        tries_remaining) tries_remaining="${value}" ;;
        confirmed)       confirmed="${value}" ;;
        \#*|"")          : ;;
    esac
done < "${BOOT_STATE}"

if [[ "${confirmed:-false}" == "true" ]]; then
    exit 0
fi

sleep 5

HEALTH_OK=true

# Check pinnacle-hal / pinnacle services are running (representative health check)
if ! systemctl is-active --quiet pinnacle-services.service 2>/dev/null; then
    HEALTH_OK=false
    logger -t swupdate-bootcheck "pinnacle-services.service not active"
fi

# Verify kernel/DTB files are intact
if [[ "${HEALTH_OK}" == "true" ]]; then
    for f in Image imx93-11x11-lpddr4x-frdm.dtb; do
        if [[ ! -f "/boot/${f}" ]]; then
            HEALTH_OK=false
            logger -t swupdate-bootcheck "${f} missing after boot"
            break
        fi
        SIZE=$(stat -c%s "/boot/${f}" 2>/dev/null || echo 0)
        case "${f}" in
            Image)
                MIN=$((1024 * 1024))
                MAX=$((50 * 1024 * 1024))
                ;;
            *.dtb)
                MIN=$((10 * 1024))
                MAX=$((5 * 1024 * 1024))
                ;;
        esac
        if [[ "${SIZE}" -lt "${MIN}" ]] || [[ "${SIZE}" -gt "${MAX}" ]]; then
            HEALTH_OK=false
            logger -t swupdate-bootcheck \
                "${f} size ${SIZE} bytes outside [${MIN}, ${MAX}]"
            break
        fi
    done
fi

if [[ "${HEALTH_OK}" == "true" ]]; then
    mount -o remount,rw /boot
    sed -i 's/confirmed=false/confirmed=true/' "${BOOT_STATE}"
    mount -o remount,ro /boot
    logger -t swupdate-bootcheck "Slot ${slot} confirmed healthy"
else
    logger -t swupdate-bootcheck "Slot ${slot} unhealthy — rolling back"
    mount -o remount,rw /boot
    if [[ -f /boot/extlinux/extlinux.conf.prev ]]; then
        cp /boot/extlinux/extlinux.conf.prev /boot/extlinux/extlinux.conf
    fi
    for f in Image imx93-11x11-lpddr4x-frdm.dtb; do
        [[ -f "/boot/${f}.prev" ]] && cp "/boot/${f}.prev" "/boot/${f}" || true
    done
    rm -f "${BOOT_STATE}" /boot/extlinux/extlinux.conf.prev \
          /boot/Image.prev /boot/imx93-11x11-lpddr4x-frdm.dtb.prev
    mount -o remount,ro /boot
    reboot
fi
