#!/usr/bin/env python3
"""Dev server that disables browser caching so Godot re-exports load immediately."""

import http.server
import errno
import os

DEFAULT_PORT = 8000
PORT_SEARCH_LIMIT = 20


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


def _read_start_port() -> int:
    value = os.environ.get("PORT", str(DEFAULT_PORT))
    try:
        return int(value)
    except ValueError:
        return DEFAULT_PORT


def _serve(start_port: int) -> None:
    for port in range(start_port, start_port + PORT_SEARCH_LIMIT):
        try:
            server = http.server.ThreadingHTTPServer(("", port), NoCacheHandler)
        except OSError as error:
            if error.errno == errno.EADDRINUSE:
                continue
            raise

        if port != start_port:
            print(f"Port {start_port} is busy; using http://localhost:{port}")
        else:
            print(f"Serving http://localhost:{port}")

        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")
        finally:
            server.server_close()
        return

    last_port = start_port + PORT_SEARCH_LIMIT - 1
    raise SystemExit(f"No open port found from {start_port} to {last_port}.")

if __name__ == "__main__":
    _serve(_read_start_port())
