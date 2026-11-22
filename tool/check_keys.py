#!/usr/bin/env python3
"""يستخرج مفاتيح الترجمة المستعملة في lib/ ويقارنها بـ strings_ar.dart و strings_en.dart.
الاستخدام: python3 tool/check_keys.py [--list]"""
import re, sys, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
lib = root / 'lib'
KEY = re.compile(r"^[a-z][a-z0-9_]*$")
used = {}

def extract_args(src, start):
    """يعيد نص المعامل الأول للاستدعاء الذي يبدأ قوسه عند start (أول حرف بعد '(')."""
    depth = 1
    i = start
    in_str = None
    while i < len(src) and depth > 0:
        ch = src[i]
        if in_str:
            if ch == '\\':
                i += 1
            elif ch == in_str:
                in_str = None
        else:
            if ch in ('"', "'"):
                in_str = ch
            elif ch in '([{':
                depth += 1
            elif ch in ')]}':
                depth -= 1
                if depth == 0:
                    break
            elif ch == ',' and depth == 1:
                break
        i += 1
    return src[start:i]

call = re.compile(r"\b(?:tr|trf)\(")
for f in sorted(lib.rglob('*.dart')):
    if f.name in ('strings_ar.dart', 'strings_en.dart'):
        continue
    src = f.read_text(encoding='utf-8')
    for m in call.finditer(src):
        # تجاهل التعريفات: String tr(String key)
        pre = src[max(0, m.start() - 12):m.start()]
        arg = extract_args(src, m.end())
        if 'String key' in arg:
            continue
        for lit in re.findall(r"'([^'\\]*)'", arg):
            if KEY.match(lit):
                used.setdefault(lit, set()).add(f.relative_to(root).as_posix())

IGNORE = {'admin', 'kind', 'arab'}  # قيم مقارنة داخل وسائط tr(...) وليست مفاتيح
for k in IGNORE:
    used.pop(k, None)

# مفاتيح تُمرَّر عبر AppException('...') أو return 'err_...'
for f in sorted(lib.rglob('*.dart')):
    src = f.read_text(encoding='utf-8')
    for lit in re.findall(r"AppException\('([a-z_0-9]+)'\)", src):
        used.setdefault(lit, set()).add(f.relative_to(root).as_posix())
    if f.name == 'errors.dart':
        for lit in re.findall(r"return '(err_[a-z_0-9]+)'", src):
            used.setdefault(lit, set()).add('errors.dart')

for f in sorted(lib.rglob('*.dart')):
    if f.parent.name == 'l10n':
        continue
    for lit in re.findall(r"'(err_[a-z_0-9]+)'", f.read_text(encoding='utf-8')):
        used.setdefault(lit, set()).add(f.relative_to(root).as_posix())

def load(path):
    p = lib / 'core' / 'l10n' / path
    if not p.exists():
        return None
    src = p.read_text(encoding='utf-8')
    return set(re.findall(r"^\s*'([a-z][a-z0-9_]*)'\s*:", src, flags=re.M))

ar = load('strings_ar.dart')
en = load('strings_en.dart')

if '--list' in sys.argv:
    for k in sorted(used):
        print(k)
    sys.exit(0)

bad = False
if ar is None or en is None:
    print('strings maps missing'); sys.exit(1)
miss_ar = sorted(set(used) - ar)
miss_en = sorted(set(used) - en)
if miss_ar:
    bad = True
    print('missing in AR:', miss_ar)
if miss_en:
    bad = True
    print('missing in EN:', miss_en)
only_ar = sorted(ar - en)
only_en = sorted(en - ar)
if only_ar or only_en:
    bad = True
    print('AR only:', only_ar)
    print('EN only:', only_en)
unused = sorted((ar | en) - set(used))
print(f'used={len(used)} ar={len(ar)} en={len(en)} unused={len(unused)}')
if unused:
    print('unused keys (ok but check):', unused)
sys.exit(1 if bad else 0)
