# Bridge recipe: meta-imx-sdk expects edk2-firmware_202508, but walnascar
# meta-arm only ships 202502. Require the available version so that the
# stmm-imx dynamic layer can parse successfully.
require recipes-bsp/uefi/edk2-firmware_202502.bb
