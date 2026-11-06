declare module 'regenerator-runtime' {
  const regeneratorRuntime: {
    wrap: (innerFn: unknown, outerFn?: unknown, self?: unknown, tryLocsList?: unknown) => unknown;
  };
  export default regeneratorRuntime;
}

declare module '@pdf-lib/fontkit/dist/fontkit.es.js' {
  const fontkit: unknown;
  export default fontkit;
}
