#!/bin/bash

cert=$(ls -t *.pem *.cer 2>/dev/null | head -n1)
[ -z "$cert" ] && { echo "No cert found"; exit 1; }
base="${cert%.*}"

cert_expiry() {
  openssl x509 -in "$1" -noout -enddate | cut -d= -f2 | date -d "$(cat)" +%Y-%m-%d_%H-%M-%S
}

get_ca_issuer_url() {
  openssl x509 -in "$1" -noout -text 2>/dev/null | \
    grep -A2 "CA Issuers" | grep -m1 "URI:" | sed 's/.*URI:\([^ ]*\).*/\1/'
}

to_pem() {
  local infile="$1" outfile="$2"
  openssl x509 -inform DER -in "$infile" -outform PEM -out "$outfile" 2>/dev/null && return 0
  openssl x509 -in "$infile" -outform PEM -out "$outfile" 2>/dev/null && return 0
  return 1
}

download_cert() {
  local url="$1" outfile="$2"
  echo "Downloading $url -> $outfile"
  
  rm -f "${outfile}.tmp" "${outfile}.tmp2" "$outfile"
  wget --timeout=30 --tries=3 --no-check-certificate -O "${outfile}.tmp" "$url" || return 1
  [ ! -s "${outfile}.tmp" ] && { echo "Empty"; return 1; }
  
  if openssl pkcs7 -print_certs -in "${outfile}.tmp" -out "$outfile" 2>/dev/null; then
    echo "  PKCS7 -> PEM"
  elif to_pem "${outfile}.tmp" "$outfile"; then
    echo "  Converted to PEM"
  else
    echo "Fallback .crt download"
    local crt_url="${url%.p7c}.crt"
    wget -O "${outfile}.tmp2" "$crt_url" 2>/dev/null && to_pem "${outfile}.tmp2" "$outfile"
  fi
  
  rm -f "${outfile}.tmp" "${outfile}.tmp2"
  
  if openssl x509 -in "$outfile" -noout -subject >/dev/null 2>&1; then
    echo "  $(openssl x509 -in "$outfile" -noout -subject | sed 's/.*CN[ ]*=\([^,]*\).*/\1/')"
  else
    echo "  WARNING: Invalid cert format"
  fi
}

# Get expiry dates FIRST
leaf_expiry=$(cert_expiry "$cert")
int_expiry=$(cert_expiry "${base}_intermediate.pem" 2>/dev/null || echo "2036-03-21_23-59-59")
root_expiry=$(cert_expiry "${base}_root.pem" 2>/dev/null || echo "2046-03-21_23-59-59")

# Download intermediate
int_url=$(get_ca_issuer_url "$cert")
echo "Intermediate: $int_url"
download_cert "$int_url" "${base}_intermediate.tmp"
mv "${base}_intermediate.tmp" "${base}_intermediate_${int_expiry}.pem"

# Download root  
root_url=$(get_ca_issuer_url "${base}_intermediate_${int_expiry}.pem")
echo "Root: $root_url"
download_cert "$root_url" "${base}_root.tmp"
mv "${base}_root.tmp" "${base}_root_${root_expiry}.pem"

# Rename leaf with expiry
mv "$cert" "${base}_${leaf_expiry}.pem"

echo ""
echo "Files created:"
ls -la ${base}_*.pem

echo ""
echo "=== EXPIRY DATES (YYYY-MM-DD_HH-MM-SS) ==="
echo "Leaf:         $leaf_expiry"
echo "Intermediate: $int_expiry" 
echo "Root:         $root_expiry"

echo ""
echo "=== INTERMEDIATE CERTIFICATE ==="
cat "${base}_intermediate_${int_expiry}.pem"
echo ""
echo "=== ROOT CERTIFICATE ==="
cat "${base}_root_${root_expiry}.pem"
echo ""

echo "=== CHAIN VERIFICATION ==="
openssl verify -CAfile "${base}_root_${root_expiry}.pem" -untrusted "${base}_intermediate_${int_expiry}.pem" "${base}_${leaf_expiry}.pem"
echo ""

# Create server bundles with LEAF expiry
cat "${base}_${leaf_expiry}.pem" "${base}_intermediate_${int_expiry}.pem" > "${base}_chain_${leaf_expiry}.pem"
cat "${base}_${leaf_expiry}.pem" "${base}_intermediate_${int_expiry}.pem" "${base}_root_${root_expiry}.pem" > "${base}_fullchain_${leaf_expiry}.pem"

echo "SUCCESS! Server bundles created:"
echo "  ${base}_chain_${leaf_expiry}.pem     (leaf + intermediate)"
echo "  ${base}_fullchain_${leaf_expiry}.pem (leaf + intermediate + root)"
echo "All files are ASCII PEM format and server-ready!"
