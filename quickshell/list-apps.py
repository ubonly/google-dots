#!/usr/bin/env python3
# list-apps.py — Fast desktop entry parser for Quickshell
import os
import json
from pathlib import Path

def parse_desktop_file(filepath):
    app = {}
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            in_desktop_entry = False
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if line.startswith('['):
                    if line == '[Desktop Entry]':
                        in_desktop_entry = True
                    else:
                        in_desktop_entry = False
                    continue
                
                if not in_desktop_entry:
                    continue

                if '=' not in line:
                    continue
                
                key, val = line.split('=', 1)
                key = key.strip()
                val = val.strip()

                if key == 'Type':
                    if val != 'Application':
                        return None
                elif key == 'NoDisplay' and val.lower() == 'true':
                    return None
                elif key == 'Hidden' and val.lower() == 'true':
                    return None
                elif key == 'Name' and 'name' not in app:
                    app['name'] = val
                elif key == 'Icon' and 'icon' not in app:
                    app['icon'] = val
                elif key == 'Exec' and 'exec' not in app:
                    # Clean up exec arguments
                    for arg in ['%u', '%U', '%f', '%F', '%d', '%D', '%n', '%N', '%i', '%c', '%k', '%v', '%m']:
                        val = val.replace(arg, '')
                    app['exec'] = val.strip()

        if 'name' in app and 'exec' in app:
            if 'icon' not in app:
                app['icon'] = 'application-x-executable'
            return app
    except Exception:
        pass
    return None

def main():
    home = str(Path.home())
    dirs = [
        "/usr/share/applications",
        os.path.join(home, ".local/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
        os.path.join(home, ".local/share/flatpak/exports/share/applications"),
        "/var/lib/snapd/desktop/applications",
        "/usr/local/share/applications"
    ]

    apps = []
    seen_execs = set()

    for d in dirs:
        if not os.path.exists(d):
            continue
        for entry in os.scandir(d):
            if entry.is_file() and entry.name.endswith('.desktop'):
                app = parse_desktop_file(entry.path)
                if app:
                    # Basic deduplication by command and name
                    dedup_key = f"{app['name']}:{app['exec']}"
                    if dedup_key not in seen_execs:
                        seen_execs.add(dedup_key)
                        apps.append(app)

    print(json.dumps(apps))

if __name__ == "__main__":
    main()
