import {
  Component,
  AfterViewInit,
  ViewChild,
  ElementRef,
  Inject,
  PLATFORM_ID,
} from '@angular/core';
import { isPlatformBrowser } from '@angular/common';

declare const Potree: any;
declare const $: any;
declare const THREE: any;

@Component({
  selector: 'app-potree-viewer',
  imports: [],
  template: `
    <div
      class="potree_container"
      style="position: absolute; width: 100%; height: 100%; left: 0px; top: 0px; "
    >
      <div id="potree_render_area" #potreeRenderArea></div>
      <div id="potree_sidebar_container"></div>
    </div>
  `,
  styles: ``,
})
export class PotreeViewer implements AfterViewInit {
  @ViewChild('potreeRenderArea', { static: true }) renderArea!: ElementRef;

  constructor(@Inject(PLATFORM_ID) private platformId: Object) {}

  ngAfterViewInit(): void {
    if (isPlatformBrowser(this.platformId)) {
      this.initPotree();
    }
  }

  initPotree() {
    Potree.scriptPath = `${window.location.origin}/potree`;
    Potree.resourcePath = `${window.location.origin}/potree/resources`;

    const viewer = new Potree.Viewer(this.renderArea.nativeElement);

    viewer.setEDLEnabled(true);
    viewer.setFOV(60);
    viewer.setPointBudget(1_000_000);
    viewer.loadSettingsFromURL();

    viewer.loadGUI(() => {
      viewer.setLanguage('en');
      $('#menu_appearance').next().show();
      // viewer.toggleSidebar();
    });

    Potree.loadPointCloud(
      `${window.location.origin}/pointclouds/lion_takanawa/cloud.js`,
      'Lion',
      (e: any) => {
        const scene = viewer.scene;
        const pointcloud = e.pointcloud;

        const material = pointcloud.material;
        material.size = 1;
        material.pointSizeType = Potree.PointSizeType.ADAPTIVE;

        scene.addPointCloud(pointcloud);

        viewer.fitToScreen();
      },
    );
  }
}
