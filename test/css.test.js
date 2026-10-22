import test from "node:test";
import assert from "node:assert/strict";

import { DEFAULT_CONFIG, buildCss, resolveConfig } from "../css.js";
import { apply, name } from "../index.js";

test("exports the plugin name", () => {
  assert.equal(name, "model-grid");
});

test("resolveConfig fills defaults", () => {
  assert.deepEqual(resolveConfig(undefined), DEFAULT_CONFIG);
  assert.deepEqual(resolveConfig({}), DEFAULT_CONFIG);
  assert.deepEqual(resolveConfig(null), DEFAULT_CONFIG);
});

test("resolveConfig clamps numeric options", () => {
  assert.equal(resolveConfig({ maxWidth: 1 }).maxWidth, 240);
  assert.equal(resolveConfig({ maxWidth: 999999 }).maxWidth, 4000);
  assert.equal(resolveConfig({ minCardWidth: -5 }).minCardWidth, 80);
  assert.equal(resolveConfig({ gap: 999 }).gap, 64);
  assert.equal(resolveConfig({ maxHeightVh: 5 }).maxHeightVh, 20);
});

test("resolveConfig ignores non-numeric strings", () => {
  assert.equal(resolveConfig({ maxWidth: "wide" }).maxWidth, DEFAULT_CONFIG.maxWidth);
});

test("buildCss returns empty when disabled", () => {
  assert.equal(buildCss({ enabled: false }), "");
});

test("buildCss targets the peakrate menu", () => {
  const css = buildCss();
  assert.match(css, /\.dsh-peakrate-ms-menu:has\(\.dsh-peakrate-ms-groups\)/);
  assert.match(css, /\.dsh-peakrate-ms-groups \.dsh-peakrate-ms-group\{display:grid!important/);
  assert.match(css, /\.dsh-peakrate-ms-option\{width:100%!important;min-width:0!important/);
});

test("buildCss targets the stock model-selection dropdown", () => {
  const css = buildCss();
  assert.match(css, /:has\(> \[role="menu"\] > \[data-menu-group\]\)/);
  assert.match(css, /\[data-menu-group\]\{display:grid!important/);
  assert.match(css, /\[data-menu-group\]>\[data-menu-group-heading\]/);
  assert.match(css, /\[data-menu-group\]>button\{width:100%!important;min-width:0!important/);
});

test("buildCss hides the rate countdown by default", () => {
  assert.match(buildCss(), /dsh-peakrate-ms-rateCountdown\{display:none!important\}/);
  assert.doesNotMatch(buildCss({ hideCountdown: false }), /dsh-peakrate-ms-rateCountdown\{display:none/);
});

test("buildCss reflects custom dimensions", () => {
  const css = buildCss({ maxWidth: 1200, minCardWidth: 150, gap: 10, maxHeightVh: 80 });
  assert.match(css, /min\(1200px, calc\(100vw - 32px\)\)/);
  assert.match(css, /minmax\(min\(150px, 100%\), 1fr\)/);
  assert.match(css, /gap:10px!important/);
  assert.match(css, /min\(80vh, calc\(100vh - 96px\)\)/);
});

function makeCtx() {
  let handler = null;
  return {
    ctx: { on: (event, cb) => { if (event === "webserver/index-inject") handler = cb; } },
    fire: (table) => handler(table),
  };
}

test("apply pushes one style row", () => {
  const { ctx, fire } = makeCtx();
  apply(ctx, {});
  const table = [];
  fire(table);
  assert.equal(table.length, 1);
  assert.equal(table[0].kind, "style");
  assert.match(table[0].text, /dsh-peakrate-ms-groups/);
});

test("apply pushes nothing when disabled", () => {
  const { ctx, fire } = makeCtx();
  apply(ctx, { enabled: false });
  const table = [];
  fire(table);
  assert.equal(table.length, 0);
});
