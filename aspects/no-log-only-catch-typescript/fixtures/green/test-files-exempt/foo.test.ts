function boom(): never {
  throw new Error("boom");
}

test("logs only", () => {
  try {
    boom();
  } catch (err) {
    console.warn("expected in test", err);
  }
});
