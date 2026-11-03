# Vendored browser libraries

Pinned through `config/importmap.rb` by absolute path (constitution Principle I exception;
see `specs/002-home-and-reader/research.md` R1 and R8). They live here, not in
`vendor/javascript`, because they load sibling files by relative URL and Propshaft only
serves digested asset URLs. Folder names carry the version, so the long public cache is
safe. To upgrade, add a new versioned folder, repoint the pin, and re-run the reader specs.

| Folder | Source | License |
|---|---|---|
| `foliate-js/78914ae/` | github.com/johnfactotum/foliate-js @ `78914aef4466eb960965702401634c2cb348e9b1`. Top-level modules, plus `vendor/zip.js` and `vendor/fflate.js`. Left out: `vendor/pdfjs/` (13 MB; DevLibrary renders PDF with pdf.js directly), the demo `reader.js`, `ui/`, `rollup/`, `tests/` and the build config | MIT |
| `pdfjs-dist/6.4.299/` | npm `pdfjs-dist@6.4.299`: `build/pdf.min.mjs`, `build/pdf.worker.min.mjs`, `cmaps/`, `standard_fonts/`, `wasm/`, `iccs/` | Apache-2.0 |
| `emoji-picker-element/1.29.1/` | npm `emoji-picker-element@1.29.1`: `index.js`, `picker.js`, `database.js`. `data.json` is `emoji-picker-element-data@1.8.0` `en/emojibase/data.json` | Apache-2.0 (picker), MIT (data) |

`vendor/javascript/@zip.js--zip.js@2.23.0.js` is npm `@zip.js/zip.js@2.23.0` `index.min.js`
(BSD-3-Clause). It is self-contained, so it goes through the normal asset pipeline.
