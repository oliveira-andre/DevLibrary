// PDF pages for the fixed-layout pager, drawn by pdf.js (002 research R1). Opened without
// streaming or auto-fetch, so pdf.js asks the server only for the byte ranges each page needs:
// a 500 MB book opens on its saved page without downloading the rest (SC-005).
import * as pdfjs from "pdfjs-dist"

const ROOT = "/vendor/pdfjs-dist/6.4.299/"
const MAX_PIXELS = 16_000_000 // keeps a single canvas within phone GPU memory

pdfjs.GlobalWorkerOptions.workerSrc = import.meta.resolve("pdfjs-dist/worker")

export async function open(url) {
  const pdf = await pdfjs.getDocument({
    url,
    disableStream: true,
    disableAutoFetch: true,
    cMapUrl: `${ROOT}cmaps/`,
    cMapPacked: true,
    standardFontDataUrl: `${ROOT}standard_fonts/`,
    wasmUrl: `${ROOT}wasm/`,
    iccUrl: `${ROOT}iccs/`
  }).promise
  const pages = new Map()
  const page = (index) => {
    if (!pages.has(index)) pages.set(index, pdf.getPage(index + 1))
    return pages.get(index)
  }

  return {
    pageCount: pdf.numPages,

    // A canvas that fits the box, drawn at the screen's density (up to 2×).
    async render(index, { width, height, pixelRatio }) {
      const pdfPage = await page(index)
      const natural = pdfPage.getViewport({ scale: 1 })
      const fit = Math.min(width / natural.width, height / natural.height)
      let scale = fit * pixelRatio
      if (natural.width * natural.height * scale * scale > MAX_PIXELS) {
        scale = Math.sqrt(MAX_PIXELS / (natural.width * natural.height))
      }

      const viewport = pdfPage.getViewport({ scale })
      const canvas = document.createElement("canvas")
      canvas.width = Math.floor(viewport.width)
      canvas.height = Math.floor(viewport.height)
      canvas.style.width = `${Math.floor(natural.width * fit)}px`
      canvas.style.height = `${Math.floor(natural.height * fit)}px`
      await pdfPage.render({ canvas, viewport }).promise
      return canvas
    },

    release() {},

    destroy() {
      pdf.destroy()
    }
  }
}
