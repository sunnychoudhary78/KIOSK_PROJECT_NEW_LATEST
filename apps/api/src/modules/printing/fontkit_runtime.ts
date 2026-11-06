import regeneratorRuntime from 'regenerator-runtime';

// @pdf-lib/fontkit's Devanagari shaper still calls the Babel runtime global.
const target = globalThis as { regeneratorRuntime?: typeof regeneratorRuntime };
target.regeneratorRuntime ??= regeneratorRuntime;
