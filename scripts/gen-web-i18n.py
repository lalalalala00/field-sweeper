# 앱의 Localizable.xcstrings에서 웹 번역표(docs/assets/i18n.js)를 만든다.
# 사용: python3 scripts/gen-web-i18n.py
import json, re, sys
src = sys.argv[1] if len(sys.argv) > 1 else 'FieldSweeper/Localizable.xcstrings'
out = sys.argv[2] if len(sys.argv) > 2 else 'docs/assets/i18n.js'
d = json.load(open(src))['strings']
def conv(s):
    n = [0]
    def rep(m):
        if m.group(1): return '{%d}' % (int(m.group(1)) - 1)
        r = '{%d}' % n[0]; n[0] += 1; return r
    return re.sub(r'%(?:(\d+)\$)?(?:@|lld|d|ld)', rep, s).replace('%%', '%')
table = {}
for key, v in d.items():
    loc = v.get('localizations', {})
    row = []
    for l in ['en', 'ja', 'zh-Hans']:
        u = loc.get(l, {}).get('stringUnit', {}).get('value')
        row.append(conv(u) if u else None)
    if all(row): table[conv(key)] = row
open(out, 'w').write('// 앱의 Localizable.xcstrings에서 만든 번역표. [영어, 일본어, 중국어 간체]\n// 다시 만들기: python3 scripts/gen-web-i18n.py\nwindow.NEMO_I18N = ' + json.dumps(table, ensure_ascii=False, indent=0) + ';\n')
print(len(table))
