/**
 * @license
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {Component, EventEmitter, Input, OnInit, Output, Inject} from '@angular/core';
import {MatDialog} from '@angular/material/dialog';
import {Subject} from 'rxjs';
import {switchMap} from 'rxjs/operators';
import {Session} from '../../core/models/Session';
import {SessionService, SESSION_SERVICE} from '../../core/services/session.service';
import { CommonModule } from '@angular/common';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {FormsModule} from '@angular/forms';
import {MatIconModule} from '@angular/material/icon';
import {MatButtonModule} from '@angular/material/button';

@Component({
    selector: 'app-session-tab',
    templateUrl: './session-tab.component.html',
    styleUrl: './session-tab.component.scss',
    imports: [
      CommonModule,
      MatFormFieldModule,
      MatInputModule,
      FormsModule,
      MatIconModule,
      MatButtonModule,
    ],
})
export class SessionTabComponent implements OnInit {
  @Input() appName: string = '';
  @Input() sessionId: string = '';

  @Output() readonly sessionSelected = new EventEmitter<Session>();
  @Output() readonly sessionReloaded = new EventEmitter<Session>();

  sessionList: any[] = [];
  userIdFilter: string = 'user';

  private refreshSessionsSubject = new Subject<void>();

  constructor(
    @Inject(SESSION_SERVICE) private sessionService: SessionService,
    private dialog: MatDialog,
  ) {}

  ngOnInit(): void {
    this.getSessionList();
  }

  getSessionList() {
    if (!this.userIdFilter) {
      this.sessionList = [];
      return;
    }
    this.sessionService.listSessions(this.appName, this.userIdFilter)
      .subscribe((res: any) => {
        this.sessionList = res ?? [];
        this.sessionList.sort(
          (a, b) => Number(b.lastUpdateTime) - Number(a.lastUpdateTime),
        );
      }, (error) => {
        this.sessionList = [];
        console.error('Error fetching sessions:', error);
      });
  }

  onFilterChange() {
    this.getSessionList();
  }

  clearFilter() {
    this.userIdFilter = '';
    this.sessionList = [];
  }

  getSession(sessionId: string) {
    this.sessionService
      .getSession(this.userIdFilter, this.appName, sessionId)
      .subscribe((res) => {
        const session = this.fromApiResultToSession(res);
        this.sessionSelected.emit(session);
      });
  }

  protected getDate(session: any): string {
    let timeStamp = session.lastUpdateTime;

    const date = new Date(timeStamp * 1000);

    return date.toLocaleString();
  }

  private fromApiResultToSession(res: any): Session {
    return {
      id: res?.id ?? '',
      appName: res?.appName ?? '',
      userId: res?.userId ?? '',
      state: res?.state ?? [],
      events: res?.events ?? [],
    };
  }

  reloadSession(sessionId: string) {
    this.sessionService
      .getSession(this.userIdFilter, this.appName, sessionId)
      .subscribe((res) => {
        const session = this.fromApiResultToSession(res);
        this.sessionReloaded.emit(session);
      });
  }

  refreshSession(session?: string) {
    this.getSessionList();
    if (this.sessionList.length <= 1) {
      return undefined;
    } else {
      let index = this.sessionList.findIndex((s) => s.id == session);
      if (index == this.sessionList.length - 1) {
        index = -1;
      }
      return this.sessionList[index + 1];
    }
  }
}
