import re
import sys

path = sys.argv[1]
src = open(path, encoding="utf-8").read()

if "isCoreLibraryDesugaringEnabled" not in src:
    src, n = re.subn(
        r"(compileOptions\s*\{)",
        r"\1\n        isCoreLibraryDesugaringEnabled = true",
        src,
        count=1,
    )
    if n != 1:
        sys.exit("compileOptions block not found in " + path)

if "desugar_jdk_libs" not in src:
    src += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'

open(path, "w", encoding="utf-8").write(src)
