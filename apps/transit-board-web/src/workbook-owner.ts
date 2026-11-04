import {
  WorkbookSession,
  validateWorkbook,
  type WorkbookCell,
  type WorkbookStatus,
  type WorkbookValidation,
  type WorkbookView,
} from "@transit/query-client/workbook";
import { readFailure } from "./observation";

/** Scheduling and disclosure are independent of folds, selection and display order. */
export class WorkbookOwner {
  cells: WorkbookCell[] = [];
  validation: WorkbookValidation | null = null;
  status: WorkbookStatus | null = null;
  views = new Map<string, WorkbookView>();
  busy = false;
  validating = false;
  live = false;
  error = "";
  cleanup = "";
  composing = false;
  private manual: { target: string; revision: number } | null = null;
  private active = false;
  private disposed = false;
  private revision = 0;
  private validated = -1;
  private disclosure = 0;
  private pending = new Set<string>();
  private dirty = new Set<string>();
  private hidden = new Set<string>();
  private dependencies: WorkbookValidation["bindings"] = [];
  private session: WorkbookSession | null = null;
  private quiet: ReturnType<typeof setTimeout> | undefined;
  private observation: ReturnType<typeof setTimeout> | undefined;
  constructor(
    private readonly changed: () => void,
    private readonly denied: () => void,
    private readonly create = () => new WorkbookSession(),
    private readonly validate = validateWorkbook,
  ) {}
  get unresolved() {
    return this.session?.unresolved ?? false;
  }
  get remaining() {
    return this.status?.remaining ?? 32;
  }
  edit(cells: WorkbookCell[], changed: string) {
    this.cells = cells.map((cell) => ({ ...cell }));
    this.revision++;
    this.validation = null;
    this.dirty.add(changed);
    this.pending.add(changed);
    for (let pass = 0; pass < 4; pass++)
      for (const binding of this.dependencies) {
        if (binding.input && this.dirty.has(binding.input)) this.dirty.add(binding.cell);
      }
    this.schedule();
    this.notify();
  }
  activity(value: boolean) {
    if (value === this.active || this.disposed) return;
    this.active = value;
    this.disclosure++;
    this.views.clear();
    if (!value) {
      this.manual = null;
      this.live = false;
      clearTimeout(this.quiet);
      clearTimeout(this.observation);
    } else if (!this.busy && this.session) void this.refresh();
    this.notify();
  }
  enable() {
    if (!this.active || this.disposed || this.unresolved || this.remaining === 0) return;
    this.live = true;
    for (const cell of this.cells) if (!this.current(cell.id)) this.pending.add(cell.id);
    this.schedule();
    this.notify();
  }
  pause() {
    this.live = false;
    clearTimeout(this.quiet);
    this.notify();
  }
  composition(value: boolean) {
    this.composing = value;
    if (value) clearTimeout(this.quiet);
    else this.schedule();
  }
  private schedule() {
    clearTimeout(this.quiet);
    if (this.active && !this.disposed && !this.composing)
      this.quiet = setTimeout(() => void this.flush(), 300);
  }
  async flush(target?: string) {
    clearTimeout(this.quiet);
    if (!this.active || this.disposed || this.composing || this.cells.length === 0) return;
    if (this.busy) {
      // Blur validation can start between pointerdown and click on Run. Retain one
      // explicit request for this exact draft, without queuing further evaluations.
      if (target && this.validating) this.manual = { target, revision: this.revision };
      return;
    }
    const revision = this.revision;
    const cells = this.cells;
    this.busy = true;
    this.validating = this.validated !== revision;
    this.error = "";
    clearTimeout(this.observation);
    this.notify();
    try {
      if (this.validated !== revision) {
        const validation = await this.validate(cells);
        if (this.disposed || revision !== this.revision || !this.active) return;
        this.validation = validation;
        this.validated = revision;
        if (validation.issue) return;
        this.dependencies = validation.bindings;
        this.dirty.clear();
      }
      this.validating = false;
      if (this.validation?.issue || this.unresolved || (!target && !this.live)) return;
      const targets = target
        ? [target]
        : [...this.pending].filter((id) => cells.some((cell) => cell.id === id));
      if (!targets.length) return;
      if (!this.session) {
        this.session = this.create();
        this.status = await this.session.open();
      }
      // An edit, pause or activity change while opening must not admit a stale candidate.
      if (this.disposed || !this.active || revision !== this.revision || (!target && !this.live))
        return;
      for (const id of targets) {
        this.pending.delete(id);
        this.hidden.delete(id);
      }
      this.status = await this.session.evaluate(cells, targets, !target, Boolean(target));
      if (revision === this.revision)
        for (const id of this.pending) if (this.current(id)) this.pending.delete(id);
      if (this.status.failure || this.remaining === 0) this.live = false;
      if (this.active && !this.disposed) await this.loadViews();
    } catch (cause) {
      this.failed(cause);
    } finally {
      this.busy = false;
      this.validating = false;
      const manual = this.manual;
      this.manual = null;
      if (manual?.revision === this.revision && this.active && !this.disposed) {
        void this.flush(manual.target);
      }
      if (!this.disposed && this.active && revision !== this.revision) this.schedule();
      this.poll();
      this.notify();
    }
  }
  private binding(id: string) {
    return this.status?.results.find((value) => value.cell === id);
  }
  current(id: string, seen = new Set<string>()): boolean {
    if (seen.has(id) || this.dirty.has(id)) return false;
    seen.add(id);
    const cell = this.cells.find((value) => value.id === id);
    const result = this.binding(id);
    if (!cell || !result || cell.sql !== result.sql || cell.name !== result.name) return false;
    const input = this.dependencies.find((value) => value.cell === id)?.input;
    return input
      ? this.current(input, seen) && this.binding(input)?.result === result.input
      : result.input === null;
  }
  private async loadViews() {
    const session = this.session;
    if (!session || !this.active || this.disposed) return;
    const disclosure = this.disclosure;
    const results = this.status?.results ?? [];
    for (const binding of results) {
      if (this.hidden.has(binding.cell)) continue;
      const old = this.views.get(binding.cell);
      const offset = old?.binding.result === binding.result ? Number(old.view.start) : 0;
      const value = await session.observe(binding, offset);
      if (this.disposed || !this.active || disclosure !== this.disclosure) return;
      this.views.set(binding.cell, value);
    }
    for (const id of this.views.keys())
      if (!results.some((value) => value.cell === id)) this.views.delete(id);
  }
  async refresh() {
    if (!this.active || this.disposed || this.busy || !this.session) return;
    this.busy = true;
    this.notify();
    try {
      this.status = await this.session.status();
      this.error = "";
      await this.loadViews();
    } catch (cause) {
      this.failed(cause);
    } finally {
      this.busy = false;
      this.poll();
      this.notify();
    }
  }
  async next(id: string) {
    const current = this.views.get(id);
    const binding = this.binding(id);
    if (!current || !binding || !this.session || !this.active || this.busy || this.disposed) return;
    const disclosure = this.disclosure;
    this.busy = true;
    this.notify();
    try {
      const next = await this.session.observe(binding, Number(current.view.delivered));
      if (!this.disposed && this.active && disclosure === this.disclosure) this.views.set(id, next);
    } catch (cause) {
      this.failed(cause);
    } finally {
      this.busy = false;
      this.poll();
      this.notify();
    }
  }
  hide(id: string) {
    this.hidden.add(id);
    this.views.delete(id);
    this.notify();
  }
  private failed(cause: unknown) {
    const failure = readFailure(cause);
    this.error = failure.code;
    this.live = false;
    this.views.clear();
    if (failure.kind === "denied") {
      this.status = null;
      this.cells = [];
      this.pending.clear();
      this.dirty.clear();
      this.validation = null;
      this.denied();
    }
  }
  private poll() {
    clearTimeout(this.observation);
    if (this.active && !this.disposed && this.session)
      this.observation = setTimeout(() => void this.refresh(), 5000);
  }
  async dispose() {
    if (this.disposed) return;
    this.disposed = true;
    this.live = false;
    this.views.clear();
    clearTimeout(this.quiet);
    clearTimeout(this.observation);
    try {
      await this.session?.close();
    } catch {
      this.cleanup = "Workbook release is unconfirmed; its server lifetime still applies.";
    }
  }
  private notify() {
    if (!this.disposed) this.changed();
  }
}
