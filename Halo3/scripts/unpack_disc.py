"""Unpack an Xbox 360 game disc image (.iso, XDVDFS) into a folder.
Usage: python unpack_disc.py <image.iso> <output folder>
Skips files that are already unpacked with the right size, so it can be re-run."""
import os, struct, sys

def main():
    iso, out_dir = sys.argv[1], sys.argv[2]
    f = open(iso, 'rb')
    part = None
    for off in (0x0, 0xFD90000, 0x18300000, 0x2080000):
        f.seek(off + 0x10000)
        if f.read(20) == b'MICROSOFT*XBOX*MEDIA':
            part = off
            break
    if part is None:
        sys.exit('Not an Xbox 360 game disc image.')
    f.seek(part + 0x10000 + 20)
    root_sector, root_size = struct.unpack('<II', f.read(8))

    def read_dir(sector, size):
        f.seek(part + sector * 2048)
        return f.read(size)

    def walk(data, off, out):
        if off * 4 + 14 > len(data):
            return
        l, r, sec, sz, attr, nl = struct.unpack('<HHIIBB', data[off * 4:off * 4 + 14])
        if l == 0xFFFF and r == 0xFFFF:
            return
        name = data[off * 4 + 14:off * 4 + 14 + nl].decode('latin-1')
        if l:
            walk(data, l, out)
        out.append((name, sec, sz, attr))
        if r:
            walk(data, r, out)

    files = []
    def collect(sector, size, rel):
        entries = []
        if size:
            walk(read_dir(sector, size), 0, entries)
        for name, sec, sz, attr in entries:
            path = os.path.join(rel, name)
            if attr & 0x10:
                os.makedirs(os.path.join(out_dir, path), exist_ok=True)
                collect(sec, sz, path)
            else:
                files.append((path, sec, sz))
    os.makedirs(out_dir, exist_ok=True)
    collect(root_sector, root_size, '')
    total = sum(sz for _, _, sz in files)
    if os.environ.get('UNPACK_LIST'):
        for p, _, sz in files[:12]: print(sz, p)
        print(len(files), 'files', total / 1e9, 'GB'); return
    done = 0
    for i, (path, sec, sz) in enumerate(files, 1):
        dst = os.path.join(out_dir, path)
        if os.path.exists(dst) and os.path.getsize(dst) == sz:
            done += sz
            continue
        f.seek(part + sec * 2048)
        with open(dst, 'wb') as o:
            left = sz
            while left:
                chunk = f.read(min(left, 8 << 20))
                if not chunk:
                    sys.exit('Disc image ended early: ' + path)
                o.write(chunk)
                left -= len(chunk)
        done += sz
        print(f'[{i}/{len(files)}] {done * 100 // max(total, 1)}%  {path}', flush=True)
    print(f'Done: {len(files)} files, {total / 1e9:.1f} GB in {out_dir}')

main()
