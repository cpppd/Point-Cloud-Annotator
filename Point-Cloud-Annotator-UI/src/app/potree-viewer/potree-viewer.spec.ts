import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PotreeViewer } from './potree-viewer';

describe('PotreeViewer', () => {
  let component: PotreeViewer;
  let fixture: ComponentFixture<PotreeViewer>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({ imports: [PotreeViewer] }).compileComponents();

    fixture = TestBed.createComponent(PotreeViewer);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
