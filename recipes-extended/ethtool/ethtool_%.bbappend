# meta-imx adds 0001-netlink-fix-missing-headers-in-text-output.patch as a
# backport for ethtool 6.11, but it fails to apply (hunk mismatch at line 143)
# against the ethtool 6.11 version shipped in walnascar. The fix appears to
# not be needed for this version, so remove the patch.
SRC_URI:remove = "file://0001-netlink-fix-missing-headers-in-text-output.patch"
