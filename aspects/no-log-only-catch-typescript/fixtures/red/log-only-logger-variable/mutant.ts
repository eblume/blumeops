const LOGGER = makeLogger("mutant");

const runMutant = (fn: () => number): number | undefined => {
  try {
    return fn();
  } catch (err) {
    LOGGER.debug("mutant failed", err);
  }
  return undefined;
};

export { runMutant };
