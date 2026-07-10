// Scraped articles sometimes carry stray markup (e.g. WordPress feed
// thumbnails: `<img src="..." class="...">`) ahead of the real text, or
// leftover <script>/<style> blocks. Strip all of that so the API only ever
// returns readable article text.
const ENTITY_MAP = {
  nbsp: " ",
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  "#39": "'",
  apos: "'",
};

const decodeEntities = (input) =>
  input.replace(/&(#\d+|#x[0-9a-f]+|[a-z0-9]+);/gi, (match, code) => {
    if (code[0] === "#") {
      const codePoint = code[1].toLowerCase() === "x"
        ? parseInt(code.slice(2), 16)
        : parseInt(code.slice(1), 10);
      return Number.isNaN(codePoint) ? " " : String.fromCodePoint(codePoint);
    }
    return ENTITY_MAP[code.toLowerCase()] ?? " ";
  });

const stripHtml = (input) => {
  if (!input) return "";
  let s = String(input);
  // Drop script/style blocks entirely (tags + their content).
  s = s.replace(/<(script|style)[^>]*>[\s\S]*?<\/\1>/gi, " ");
  // Strip all remaining tags (e.g. <img ... src="...">, <p>, <br/>).
  s = s.replace(/<[^>]*>/g, " ");
  s = decodeEntities(s);
  // Collapse whitespace left behind by removed tags.
  s = s.replace(/\s+/g, " ").trim();
  return s;
};

module.exports = { stripHtml };
