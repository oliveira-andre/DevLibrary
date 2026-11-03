# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"

# Reader engines and widgets (constitution Principle I exception; research R1, R8). The
# libraries that load sibling files by relative URL live under versioned public/vendor/
# folders (see public/vendor/README.md). Nothing here preloads: only the reader page
# imports them, and only for the book's format.
pin "foliate-js/view", to: "/vendor/foliate-js/78914ae/view.js", preload: false
pin "pdfjs-dist", to: "/vendor/pdfjs-dist/6.4.299/build/pdf.min.mjs", preload: false
pin "pdfjs-dist/worker", to: "/vendor/pdfjs-dist/6.4.299/build/pdf.worker.min.mjs", preload: false
pin "@zip.js/zip.js", to: "@zip.js--zip.js@2.23.0.js", preload: false
pin "emoji-picker-element", to: "/vendor/emoji-picker-element/1.29.1/index.js", preload: false
pin_all_from "app/javascript/reader", under: "reader", preload: false
