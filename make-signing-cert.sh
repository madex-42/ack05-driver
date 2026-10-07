#!/bin/sh
# One-time setup: create a stable self-signed code-signing identity for ack05d.
#
#     ./make-signing-cert.sh          (asks for sudo once, to trust the cert)
#
# Ad-hoc signing (install.sh default) gives the binary a NEW identity on every
# rebuild, so macOS re-asks for Accessibility, re-announces the login item and
# re-prompts keychain ACLs each time. Signing with one persistent certificate
# keeps all those grants across rebuilds. install.sh picks this identity up
# automatically once it exists.
set -eu

NAME="ack05d-signing"

if security find-identity -p codesigning -v 2>/dev/null | grep -q "$NAME" || \
   security find-certificate -c "$NAME" "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1; then
    echo "Warning: A certificate or identity named '$NAME' already exists in your keychain."
    echo "Creating a new certificate without removing the old one will cause ambiguous certificate"
    echo "conflicts when codesign runs during ./install.sh."
    printf "Do you want to delete the existing '%s' certificate and recreate it? [y/N]: " "$NAME"
    read -r reply
    case "$reply" in
        [yY]|[yY][eE][sS])
            echo "==> removing existing certificate '$NAME' from login keychain"
            security delete-certificate -c "$NAME" "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null || true
            ;;
        *)
            echo "Aborted. Keeping existing certificate."
            exit 0
            ;;
    esac
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> generating certificate ($NAME, valid 10 years)"
openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -nodes -subj "/CN=$NAME" \
    -addext "keyUsage=digitalSignature" -addext "extendedKeyUsage=codeSigning"
LEGACY_FLAG=""
if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
    LEGACY_FLAG="-legacy"
fi
openssl pkcs12 -export -out "$TMP/cert.p12" -inkey "$TMP/key.pem" \
    -in "$TMP/cert.pem" -passout pass:temp $LEGACY_FLAG

echo "==> importing into login keychain (codesign pre-authorized)"
security import "$TMP/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P temp -T /usr/bin/codesign

echo "==> trusting certificate (sudo)"
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain "$TMP/cert.pem"

echo
echo "identity '$NAME' created. Run ./install.sh — it will sign with it from now on."
echo "Re-add the Accessibility grant ONE more time; after that it sticks."
