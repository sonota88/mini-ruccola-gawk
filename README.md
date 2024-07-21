AWK (gawk) port of [Mini Ruccola (vm2gol-v2)](https://github.com/sonota88/vm2gol-v2) compiler

AWK（gawk）でシンプルな自作言語のコンパイラを書いた  
https://qiita.com/sonota88/items/2e2fd758b491c94dc821

---

```
  $ gawk --version | head -1
GNU Awk 5.1.0, API: 3.0 (GNU MPFR 4.1.0, GNU MP 6.2.1)

```

```
git clone --recursive https://github.com/sonota88/mini-ruccola-gawk.git
cd mini-ruccola-gawk

./docker.sh build
./test.sh all
```

```
  LANG=C wc -l mrcl_*.awk lib/*.awk

  396 mrcl_codegen.awk
   74 mrcl_lexer.awk
  402 mrcl_parser.awk
  105 lib/json.awk
  114 lib/types.awk
   31 lib/utils.awk
 1122 total

  LANG=C wc -l mrcl_*.awk

  396 mrcl_codegen.awk
   74 mrcl_lexer.awk
  402 mrcl_parser.awk
  872 total
```
