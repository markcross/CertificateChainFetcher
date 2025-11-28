# CertificateChainFetcher
Useful when certificates are given to you before going into PRODUCTION and passing the intermediate and root certificates are often forgotten.
```
# Certificate Chain Fetcher

This simple Bash script automatically downloads the intermediate and root certificates for a given PEM leaf certificate, then verifies and bundles them for server use.

Useful when certificates are given to you before going into PRODUCTION and passing the intermediate and root certificates are often forgotten.

The download links are often to be found in the certifcate, IE the cert can be inspected for the intermediate and the intermediate inspected for the root.

$ openssl x509 -in google_cert.pem -noout -text | grep -A1 "CA Issuers"
                CA Issuers - URI:http://i.pki.goog/wr2.crt # INTERMEDIATE
$ openssl x509 -in google_intermediate.pem -noout -text | grep -A1 "CA Issuers"
                CA Issuers - URI:http://i.pki.goog/r1.crt  # ROOT


## Usage

1. Place your leaf certificate (e.g. `google.pem`) in the script directory.

$ ls -1
get_intermediate_and_root_certs.sh
google_cert.pem
README

2. Run the script:

   ```
   ./get_intermediate_and_root_certs.sh
   ```

3. The script outputs expiry-dated files and bundles, e.g.:

   $ ls -1 *.pem
   google_cert_2026-01-19_08-33-42.pem
   google_cert_chain_2026-01-19_08-33-42.pem
   google_cert_fullchain_2026-01-19_08-33-42.pem
   google_cert_intermediate_2025-11-28_00-00-00.pem
   google_cert_root_2025-11-28_00-00-00.pem

4. Use the `_fullchain.pem` file in your web servers (Nginx, Apache, HAProxy, etc.)

## Features

- Downloads correct intermediate and root certs using CA Issuer URLs.
- Handles Sectigo DER/PKCS7 certificate quirks automatically.
- Calculates certificate expiry dates and uses them in filenames.
- Verifies the complete certificate chain with OpenSSL.
- Produces server-ready PEM bundles with leaf and intermediate certificates.

## Example output

```
$ ./get_intermediate_and_root_certs.sh
=== CHAIN VERIFICATION ===
google_cert_2026-01-19_08-33-42.pem: OK

SUCCESS! Server bundles created:
  google_chain_2026-01-19_08-33-42.pem     (leaf + intermediate)
  google_fullchain_2026-01-19_08-33-42.pem (leaf + intermediate + root)
All files are ASCII PEM format and server-ready!

$ ls -1
get_intermediate_and_root_certs.sh
google_2026-01-19_08-33-42.pem
google_chain_2026-01-19_08-33-42.pem
google_fullchain_2026-01-19_08-33-42.pem
google_intermediate_2025-11-28_00-00-00.pem
google_root_2025-11-28_00-00-00.pem
README
```

## Requirements

- Bash shell
- OpenSSL CLI
- wget or curl available in your environment

## License

MIT License

---

*For detailed usage and script code, see `get_intermediate_and_root_certs.sh`.*
```

Releases
v1 2025-11-28 Mark Cross
