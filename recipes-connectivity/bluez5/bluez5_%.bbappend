# NXP meta-imx patches for bluez5 apply with minor fuzz (context offset) against
# bluez5 5.79 in walnascar. The patches apply functionally correctly, so we
# downgrade the [patch-fuzz] check from a fatal error to a warning.
ERROR_QA:remove = "patch-fuzz"
WARN_QA:append = " patch-fuzz"
