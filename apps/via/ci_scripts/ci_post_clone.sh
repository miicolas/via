#!/bin/sh
# Xcode Cloud clones a bare repo: the untracked Configuration/Secrets.xcconfig
# never exists there, so the client key must arrive through the workflow's
# environment and be written back before the build reads the xcconfig chain.
set -eu

if [ -z "${VIA_API_CLIENT_KEY:-}" ]; then
    echo "error: VIA_API_CLIENT_KEY is not set on this Xcode Cloud workflow."
    echo "Add it as a secret environment variable in App Store Connect > Xcode Cloud > Workflow > Environment."
    exit 1
fi

cat > "$CI_PRIMARY_REPOSITORY_PATH/apps/via/Configuration/Secrets.xcconfig" <<EOF
VIA_API_CLIENT_KEY = $VIA_API_CLIENT_KEY
EOF
