const fs = require("node:fs");
const vizRenderStringSync = require("@aduh95/viz.js/sync");
const PDFDocument = require("pdfkit");
const SVGtoPDF = require("svg-to-pdfkit");

const dotPath = "docs/context-diagram.dot";
const pdfPath = "docs/context-diagram.pdf";

function ensureDotExists() {
  if (!fs.existsSync(dotPath)) {
    throw new Error(`Kan DOT-bestand niet vinden op ${dotPath}`);
  }
}

function render() {
  ensureDotExists();
  const dot = fs.readFileSync(dotPath, "utf8");
  const svg = vizRenderStringSync(dot);

  const doc = new PDFDocument({ size: "A4", margin: 32 });
  const stream = fs.createWriteStream(pdfPath);

  doc.pipe(stream);

  SVGtoPDF(doc, svg, 32, 32, {
    width: doc.page.width - 64,
    height: doc.page.height - 64,
    preserveAspectRatio: "xMidYMid meet",
    assumePt: true
  });

  const logSuccess = () => console.log(`Contextdiagram geschreven naar ${pdfPath}`);
  const logError = (error) => {
    console.error("Fout tijdens opslaan van PDF", error);
    process.exitCode = 1;
  };

  stream.on("finish", logSuccess);
  stream.on("error", logError);

  doc.end();
}

try {
  render();
} catch (error) {
  console.error("Genereren contextdiagram mislukt:", error);
  process.exit(1);
}
