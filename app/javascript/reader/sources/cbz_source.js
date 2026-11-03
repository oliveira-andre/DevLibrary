// Comic pages (CBZ) for the fixed-layout pager (002 research R1). zip.js reads the archive's
// directory and then each page by HTTP byte range, so a large comic never downloads in full.
import { configure, ZipReader, HttpRangeReader, BlobWriter } from "@zip.js/zip.js"

configure({ useWebWorkers: false })

const IMAGE_TYPES = { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", webp: "image/webp", gif: "image/gif", avif: "image/avif" }
const pageOrder = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" })

const imageType = (filename) => IMAGE_TYPES[filename.split(".").pop().toLowerCase()]
const hidden = (filename) => filename.split("/").some((part) => part.startsWith(".") || part === "__MACOSX")

export async function open(url) {
  const zip = new ZipReader(new HttpRangeReader(url))
  const entries = (await zip.getEntries())
    .filter((entry) => !entry.directory && imageType(entry.filename) && !hidden(entry.filename))
    .sort((a, b) => pageOrder.compare(a.filename, b.filename))
  if (entries.length === 0) throw new Error("This comic has no pages")

  const urls = new Map()
  const urlFor = (index) => {
    if (!urls.has(index)) {
      const entry = entries[index]
      urls.set(index, entry.getData(new BlobWriter(imageType(entry.filename))).then((blob) => URL.createObjectURL(blob)))
    }
    return urls.get(index)
  }

  return {
    pageCount: entries.length,

    async render(index) {
      const image = new Image()
      image.alt = ""
      image.decoding = "async"
      image.src = await urlFor(index)
      await image.decode()
      return image
    },

    release(index) {
      const url = urls.get(index)
      if (!url) return
      urls.delete(index)
      url.then((objectUrl) => URL.revokeObjectURL(objectUrl))
    },

    destroy() {
      for (const index of [ ...urls.keys() ]) this.release(index)
      zip.close()
    }
  }
}
