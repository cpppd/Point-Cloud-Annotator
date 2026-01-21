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

import { environment } from '../../environments/environment';

const API_ENDPOINT = environment.potree.apiEndpoint;

@Component({
  selector: 'app-potree-viewer',
  imports: [],
  templateUrl: './potree-viewer.html',
  styleUrls: ['./potree-viewer.css'],
})
export class PotreeViewer implements AfterViewInit {
  @ViewChild('potreeRenderArea', { static: true }) renderArea!: ElementRef;

  constructor(@Inject(PLATFORM_ID) private platformId: Object) { }

  ngAfterViewInit(): void {
    if (isPlatformBrowser(this.platformId)) {
      this.initPotree();
    }
  }

  initPotree() {
    // Set API endpoint globally for the annotation-api module
    (window as any).ANNOTATION_API_ENDPOINT = API_ENDPOINT;

    Potree.scriptPath = `${window.location.origin}${environment.potree.assetsPath}`;
    Potree.resourcePath = `${window.location.origin}${environment.potree.assetsPath}/resources`;

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
      `${window.location.origin}${environment.potree.pointCloudsPath}/lion_takanawa/cloud.js`,
      'Lion',
      (e: any) => {
        const scene = viewer.scene;
        const pointcloud = e.pointcloud;
        const material = pointcloud.material;

        material.size = 1;
        material.pointSizeType = Potree.PointSizeType.ADAPTIVE;

        scene.addPointCloud(pointcloud);
        viewer.fitToScreen();

        // Load saved annotations from API after point cloud loads
        this.loadAnnotations(viewer);
      },
    );
  }

  /**
   * Fetch annotations from the backend API and add them to the viewer
   */
  async loadAnnotations(viewer: any) {
    try {
      const response = await fetch(`${API_ENDPOINT}/annotations`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        console.error('Failed to fetch annotations:', response.status);
        return;
      }

      const data = await response.json();

      if (data.success && data.annotations && data.annotations.length > 0) {
        for (const annotationData of data.annotations) {
          // Convert API data to Potree.Annotation constructor args
          const args: any = {
            position: [annotationData.positionX, annotationData.positionY, annotationData.positionZ],
            title: annotationData.title || 'No Title',
            description: annotationData.description || ''
          };

          // Add camera position if available
          if (annotationData.cameraPositionX != null) {
            args.cameraPosition = [
              annotationData.cameraPositionX,
              annotationData.cameraPositionY,
              annotationData.cameraPositionZ
            ];
          }

          // Add camera target if available
          if (annotationData.cameraTargetX != null) {
            args.cameraTarget = [
              annotationData.cameraTargetX,
              annotationData.cameraTargetY,
              annotationData.cameraTargetZ
            ];
          }

          // Add radius if available
          if (annotationData.radius != null) {
            args.radius = annotationData.radius;
          }

          // Create the annotation
          const annotation = new Potree.Annotation(args);

          // Preserve the UUID from the backend
          annotation.uuid = annotationData.uuid;

          // Add to scene
          viewer.scene.annotations.add(annotation);
        }
      }
    } catch (error) {
      console.error('Error loading annotations:', error);
    }
  }
}
