// One active workspace operation and at most one explicit action waiting for it.
// Polls may skip a busy workspace; an accepted retry click must not disappear
// between React rendering an enabled button and a status poll starting.
export class WorkspaceTasks {
  private active: Promise<void> | null = null;
  private waiting = false;

  async run(operation: () => Promise<void>, signal: AbortSignal, wait = false): Promise<void> {
    if (this.active || this.waiting) {
      if (!wait || this.waiting) return;
      this.waiting = true;
      await this.active;
      this.waiting = false;
    }
    if (signal.aborted) return;
    let finish!: () => void;
    this.active = new Promise<void>((resolve) => {
      finish = resolve;
    });
    try {
      await operation();
    } finally {
      this.active = null;
      finish();
    }
  }
}
