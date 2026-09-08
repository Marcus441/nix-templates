import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ItemsService, type Item } from './items.service';
import { normalizeName } from './validate';

@Component({
  selector: 'app-root',
  imports: [FormsModule],
  templateUrl: './app.html',
})
export class App {
  private readonly items$ = inject(ItemsService);

  protected readonly items = signal<Item[]>([]);
  protected readonly error = signal<string | null>(null);
  protected name = '';

  constructor() {
    void this.refresh();
  }

  protected async submit(): Promise<void> {
    const normalized = normalizeName(this.name);
    if (normalized === null) {
      return;
    }

    try {
      await this.items$.add(normalized);
    } catch {
      this.error.set('POST /items failed');
      return;
    }

    this.name = '';
    await this.refresh();
  }

  private async refresh(): Promise<void> {
    try {
      this.items.set(await this.items$.list());
      this.error.set(null);
    } catch {
      this.error.set('GET /items failed');
    }
  }
}
