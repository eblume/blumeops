try {
  boot();
} catch (err) {
  console.error("boot failed", err);
}

export function pollTwice(): void {
  try {
    step();
  } catch (err) {
    console.warn("first step failed", err);
  }
  try {
    step();
  } catch (err) {
    console.warn("second step failed", err);
  }
}
