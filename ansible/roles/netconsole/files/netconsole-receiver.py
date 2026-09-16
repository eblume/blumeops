#!/usr/bin/env python3
"""Netconsole UDP receiver: append raw kernel printk datagrams to a size-capped log."""

import argparse
import os
import socket
import sys


def rotate(path, keep):
    stale = f"{path}.{keep}"
    if os.path.exists(stale):
        os.remove(stale)
    for i in range(keep - 1, 0, -1):
        older = f"{path}.{i}"
        if os.path.exists(older):
            os.replace(older, f"{path}.{i + 1}")
    os.replace(path, f"{path}.1")


def main():
    parser = argparse.ArgumentParser(
        description="Netconsole UDP receiver with rotation."
    )
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--file", required=True)
    parser.add_argument("--max-bytes", type=int, required=True)
    parser.add_argument("--keep", type=int, required=True)
    args = parser.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind(("0.0.0.0", args.port))
    except OSError as exc:
        print(
            f"netconsole-receiver: bind failed on 0.0.0.0:{args.port}: {exc}",
            file=sys.stderr,
        )
        sys.exit(1)

    while True:
        try:
            payload = sock.recv(65536)
            if (
                os.path.exists(args.file)
                and os.path.getsize(args.file) >= args.max_bytes
            ):
                rotate(args.file, args.keep)
            with open(args.file, "ab") as fh:
                fh.write(payload)
                if not payload.endswith(b"\n"):
                    fh.write(b"\n")
        except Exception as exc:  # noqa: BLE001 - keep the receiver alive per datagram
            print(f"netconsole-receiver: {exc}", file=sys.stderr)


if __name__ == "__main__":
    main()
