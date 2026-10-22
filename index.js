/**
 * dsh-model-grid — host half.
 *
 * Turns the composer model picker (the popup in the chat input bar) from a
 * long one-per-row list into a responsive card grid, one grid per provider.
 *
 * Delivery: the stylesheet is pushed through the `webserver/index-inject`
 * event, the same hook DSH's own plugin surfaces use to add a `<style>` to the
 * page `<head>`. It applies on every page load, survives a restart, and never
 * touches a client bundle — so unrelated local patches are never rebuilt.
 *
 * Supported pickers (see css.js):
 *  - the stock `dsh-client-ui-model-selection` dropdown;
 *  - the `dsh-peakrate` model menu, which replaces the stock trigger when it is
 *    installed.
 */

import { buildCss } from "./css.js";

export const name = "model-grid";

/**
 * @param {object} ctx cordis context
 * @param {object} [config] plugin config, see DEFAULT_CONFIG in css.js
 */
export function apply(ctx, config) {
  ctx.on("webserver/index-inject", (table) => {
    const css = buildCss(config);
    if (css) table.push({ kind: "style", text: css });
  });
}
