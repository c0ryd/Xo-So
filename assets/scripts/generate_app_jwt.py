#!/usr/bin/env python3
"""
Generate a Sign in with Apple client secret (ES256).

Apple requires:
- alg: ES256 (P-256 / secp256r1)
- iss: your Apple Team ID
- sub: your Service ID (client_id) / bundle ID used with Sign in with Apple
- aud: "https://appleid.apple.com"
- iat: now (epoch seconds)
- exp: <= 6 months from iat (<= 15,777,000 seconds)
- kid: Key ID of your Apple private key (from Certificates, IDs & Profiles)

Usage examples:
  python apple_client_secret.py \
    --team-id S69XJ274BR \
    --client-id com.cdawson.xoso \
    --key-id T5X8FQRJ98 \
    --key-file es256-private.pem \
    --ttl 15777000

  # Shorter lifetime (e.g., 30 days)
  python apple_client_secret.py ... --ttl $((30*24*3600))

Requires:
  pip install pyjwt cryptography
"""
import argparse
import json
import time
import sys
from pathlib import Path

import jwt  # PyJWT


MAX_TTL = 15_777_000  # Apple's 6-month limit (~182.5 days)
APPLE_AUD = "https://appleid.apple.com"


def read_text(path_or_text: str) -> str:
    """
    If the input looks like a file path that exists, read it.
    Otherwise, treat the value as the PEM string itself.
    """
    p = Path(path_or_text)
    if p.exists():
        return p.read_text(encoding="utf-8")
    return path_or_text


def parse_args():
    ap = argparse.ArgumentParser(description="Generate Apple Sign in client secret (ES256).")
    ap.add_argument("--team-id", required=True, help="Apple Team ID (iss)")
    ap.add_argument("--client-id", required=True, help="Service ID / Bundle ID (sub)")
    ap.add_argument("--key-id", required=True, help="Apple Key ID (kid)")
    ap.add_argument("--key-file", help="Path to ES256 private key PEM")
    ap.add_argument("--key", help="Inline ES256 private key PEM (use --key-file instead when possible)")
    ap.add_argument("--ttl", type=int, default=MAX_TTL, help=f"Lifetime in seconds (<= {MAX_TTL}; default = 6 months)")
    ap.add_argument("--no-validate", action="store_true", help="Skip TTL/audience sanity checks")
    ap.add_argument("--pretty", action="store_true", help="Print decoded header/payload after token")
    ap.add_argument("--out", help="Write token to this file instead of stdout")
    return ap.parse_args()


def main():
    args = parse_args()

    if not args.key_file and not args.key:
        print("ERROR: Provide --key-file or --key (PEM).", file=sys.stderr)
        sys.exit(2)

    if not args.no_validate and args.ttl > MAX_TTL:
        print(f"ERROR: ttl must be <= {MAX_TTL} (6 months). You passed {args.ttl}.", file=sys.stderr)
        sys.exit(2)

    private_key_pem = read_text(args.key_file or args.key)

    # Claims
    now = int(time.time())
    claims = {
        "iss": args.team_id,
        "iat": now,
        "exp": now + args.ttl,
        "aud": APPLE_AUD,
        "sub": args.client_id,
    }

    # Header
    headers = {
        "alg": "ES256",
        "kid": args.key_id,
        "typ": "JWT",
    }

    try:
        token = jwt.encode(
            claims,
            private_key_pem,
            algorithm="ES256",
            headers=headers,
        )
    except Exception as e:
        print(f"ERROR: Failed to sign token: {e}", file=sys.stderr)
        sys.exit(1)

    if args.out:
        Path(args.out).write_text(token, encoding="utf-8")
    else:
        print(token)

    if args.pretty:
        print("\n--- Decoded Header ---")
        print(json.dumps(jwt.get_unverified_header(token), indent=2))
        print("\n--- Decoded Payload ---")
        print(json.dumps(claims, indent=2))


if __name__ == "__main__":
    main()