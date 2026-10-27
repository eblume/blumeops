const failures = { labels: (_kw: object) => failures, inc: () => undefined };

export function reraises(path: string): string {
  try {
    return readFileSync(path);
  } catch (err) {
    console.warn("read failed", err);
    throw err;
  }
}

// Not log-only (an `if` statement follows the log), so it passes at the
// log-only test, before any throw/return search. It does not exercise a
// return inside a log-only body.
export function returnsNested(path: string, quiet: boolean): string | null {
  try {
    return readFileSync(path);
  } catch (err) {
    console.warn("read failed", err);
    if (quiet) {
      return null;
    }
  }
  return null;
}

export function counts(job: () => void): void {
  try {
    job();
  } catch (err) {
    console.error("job failed", err);
    failures.labels({ kind: "job" }).inc();
  }
}

export function observes(job: () => void, timer: { observe: (n: number) => void }): void {
  try {
    job();
  } catch (err) {
    console.error("job failed", err);
    timer.observe(1);
  }
}

export function notifies(job: () => void): void {
  try {
    job();
  } catch (err) {
    console.error("job failed", err);
    sendNtfy("job failed");
  }
}

export function assigns(job: () => void): string {
  let status = "ok";
  try {
    job();
  } catch (err) {
    console.error("job failed", err);
    status = "failed";
  }
  return status;
}

export function emptyHandler(path: string): void {
  try {
    removeFile(path);
  } catch {}
}

export function commentOnly(path: string): void {
  try {
    removeFile(path);
  } catch (err) {
    // the file being gone is the desired end state
  }
}
