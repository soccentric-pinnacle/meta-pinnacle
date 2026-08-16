# mxsldr is a loader for the obsolete i.MX23/28 (not the Pinnacle i.MX93) and
# its upstream host (source.denx.de) is unreachable, so it cannot be fetched.
# Drop it from the SDK host package group.
RDEPENDS:${PN}:remove = "nativesdk-mxsldr"
