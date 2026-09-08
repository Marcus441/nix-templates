import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import type { components } from '@app/contracts';
import { firstValueFrom } from 'rxjs';

export type Item = components['schemas']['Item'];

@Injectable({ providedIn: 'root' })
export class ItemsService {
  private readonly http = inject(HttpClient);

  list(): Promise<Item[]> {
    return firstValueFrom(this.http.get<Item[]>('/items'));
  }

  add(name: string): Promise<Item> {
    return firstValueFrom(this.http.post<Item>('/items', { name }));
  }
}
