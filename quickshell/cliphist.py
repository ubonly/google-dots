#!/usr/bin/env python3
import subprocess
import json
import os
import urllib.parse
from pathlib import Path

TMP_DIR = Path("/tmp/quickshell-cliphist")
TMP_DIR.mkdir(parents=True, exist_ok=True)

def main():
    try:
        # Get list from cliphist
        result = subprocess.run(['cliphist', 'list'], capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError:
        print(json.dumps([]))
        return

    items = []
    lines = result.stdout.strip().split('\n')
    
    # Process only the first 20 items to keep UI snappy
    for line in lines[:20]:
        if not line: continue
        parts = line.split('\t', 1)
        if len(parts) != 2: continue
        
        cid, data = parts[0], parts[1]
        
        item = {
            "id": cid,
            "raw": data,
            "type": "text",
            "preview": "",
            "imagePath": "",
            "filename": ""
        }
        
        if "[[ binary data" in data:
            item["type"] = "image"
            item["preview"] = "Image"
            img_path = TMP_DIR / f"{cid}.png"
            
            # Decode if not already decoded
            if not img_path.exists():
                try:
                    decode_proc = subprocess.Popen(['cliphist', 'decode', cid], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                    with open(img_path, 'wb') as f:
                        f.write(decode_proc.stdout.read())
                except Exception:
                    pass
                    
            item["imagePath"] = f"file://{img_path}"
            
        elif data.startswith("file://"):
            item["type"] = "file"
            
            # Extract first filename for display
            first_uri = data.split('\n')[0].strip()
            decoded_path = urllib.parse.unquote(first_uri[7:]) # remove file://
            basename = os.path.basename(decoded_path)
            
            # If multiple files
            file_count = len([x for x in data.split('\n') if x.strip()])
            if file_count > 1:
                item["filename"] = f"{basename} (+{file_count-1})"
            else:
                item["filename"] = basename
                
            item["preview"] = first_uri
            
        else:
            item["type"] = "text"
            # Truncate text for preview
            preview = data.strip().replace('\n', ' ')
            if len(preview) > 100:
                preview = preview[:100] + "..."
            item["preview"] = preview
            
        items.append(item)
        
    print(json.dumps(items))

if __name__ == "__main__":
    main()
