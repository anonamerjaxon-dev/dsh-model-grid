/**
 * CSS builder for dsh-model-grid.
 *
 * Kept separate from the plugin entry so it can be imported and unit-tested
 * without a running DSH host.
 */

/** Defaults, also documented in README.md. */
export const DEFAULT_CONFIG = Object.freeze({
  /** Hard cap on the popup width, in CSS px. */
  maxWidth: 900,
  /** Minimum width of a single model card, in CSS px. */
  minCardWidth: 200,
  /** Gap between cards, in CSS px. */
  gap: 6,
  /** Cap on the popup height, in vh. */
  maxHeightVh: 76,
  /** Hide the long "· 14h 23m" countdown in the price badge. */
  hideCountdown: true,
  /** Set false to inject nothing. */
  enabled: true,
});

function numeric(value, fallback, min, max) {
  const n = typeof value === "number" ? value : Number.parseFloat(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

/**
 * Merge user config with defaults and clamp numeric values.
 * @param {object|undefined} input
 * @returns {typeof DEFAULT_CONFIG}
 */
export function resolveConfig(input) {
  const c = input !== null && typeof input === "object" ? input : {};
  return {
    maxWidth: numeric(c.maxWidth, DEFAULT_CONFIG.maxWidth, 240, 4000),
    minCardWidth: numeric(c.minCardWidth, DEFAULT_CONFIG.minCardWidth, 80, 1200),
    gap: numeric(c.gap, DEFAULT_CONFIG.gap, 0, 64),
    maxHeightVh: numeric(c.maxHeightVh, DEFAULT_CONFIG.maxHeightVh, 20, 100),
    hideCountdown:
      c.hideCountdown === undefined
        ? DEFAULT_CONFIG.hideCountdown
        : Boolean(c.hideCountdown),
    enabled:
      c.enabled === undefined ? DEFAULT_CONFIG.enabled : Boolean(c.enabled),
  };
}

/**
 * Build the stylesheet for the given config.
 *
 * Two pickers are supported:
 *  - the stock `dsh-client-ui-model-selection` dropdown, identified by its
 *    `[data-menu-group]` sections (attribute-based, no hashed class names);
 *  - the `dsh-peakrate` model menu, identified by its `dsh-peakrate-ms-*`
 *    classes.
 *
 * @param {object|undefined} input
 * @returns {string} CSS text (empty when disabled)
 */
export function buildCss(input) {
  const c = resolveConfig(input);
  if (!c.enabled) return "";

  const width = `min(${c.maxWidth}px, calc(100vw - 32px))`;
  const height = `min(${c.maxHeightVh}vh, calc(100vh - 96px))`;
  const columns = `repeat(auto-fill, minmax(min(${c.minCardWidth}px, 100%), 1fr))`;
  const gap = `${c.gap}px`;
  const hideCountdown = c.hideCountdown
    ? ".dsh-peakrate-ms-groups .dsh-peakrate-ms-rateCountdown{display:none!important}"
    : "";

  return `/* dsh-model-grid — generated from config; see README.md */
/* --- dsh-peakrate model menu --- */
.dsh-peakrate-ms-menu:has(.dsh-peakrate-ms-groups){width:${width}!important;min-width:${width}!important;max-width:${width}!important;max-height:${height}!important}
.dsh-peakrate-ms-groups .dsh-peakrate-ms-group{display:grid!important;grid-template-columns:${columns}!important;gap:${gap}!important;align-items:stretch!important}
.dsh-peakrate-ms-groups .dsh-peakrate-ms-groupTitle{grid-column:1/-1!important}
.dsh-peakrate-ms-groups .dsh-peakrate-ms-option{width:100%!important;min-width:0!important;max-width:100%!important}
.dsh-peakrate-ms-groups .dsh-peakrate-ms-optionCopy{flex:1 1 auto!important;min-width:0!important}
.dsh-peakrate-ms-groups .dsh-peakrate-ms-modelName{font-size:13px!important}
.dsh-peakrate-ms-groups .dsh-peakrate-ms-rate{flex:none!important;font-size:10px!important;padding:0 4px!important;gap:2px!important}
${hideCountdown}
.dsh-peakrate-ms-groups .dsh-peakrate-ms-check{flex:0 0 14px!important}
/* --- stock dsh-client-ui-model-selection dropdown (attribute-based) --- */
:has(> [role="menu"] > [data-menu-group]){width:${width}!important;max-width:${width}!important;max-height:${height}!important}
[data-menu-group]{display:grid!important;grid-template-columns:${columns}!important;gap:${gap}!important;align-items:stretch!important}
[data-menu-group]>[data-menu-group-heading],[data-menu-group]>[data-menu-group-start]{grid-column:1/-1!important}
[data-menu-group]>button{width:100%!important;min-width:0!important;max-width:100%!important}
`;
}
