export class Poller {
  step(): void {
    throw new Error("step");
  }

  tick(): void {
    try {
      this.step();
    } catch (err) {
      this.logger.warn("tick failed", err);
    }
  }
}
