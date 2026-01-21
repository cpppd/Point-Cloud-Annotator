/**
 * Annotation API Module
 * Handles communication with the AWS API Gateway backend for annotation persistence.
 */



export const AnnotationAPI = {
  /**
   * Get the API endpoint URL
   * @returns {string} The API endpoint URL
   */
  getEndpoint() {
    if (typeof window !== 'undefined' && window.ANNOTATION_API_ENDPOINT) {
      return window.ANNOTATION_API_ENDPOINT;
    }
    console.warn('window.ANNOTATION_API_ENDPOINT is not defined. Annotation features may not work.');
    return '';
  },

  /**
   * Fetch all annotations from the backend
   * @returns {Promise<Array>} Array of annotation objects
   */
  async getAnnotations() {
    try {
      const response = await fetch(`${this.getEndpoint()}/annotations`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();

      if (data.success) {
        return data.annotations;
      } else {
        console.error('API returned error:', data.error);
        return [];
      }
    } catch (error) {
      console.error('Failed to fetch annotations:', error);
      return [];
    }
  },

  /**
   * Save or update an annotation
   * @param {Object} annotation - The annotation object to save
   * @returns {Promise<boolean>} True if successful, false otherwise
   */
  async saveAnnotation(annotation) {
    try {
      // Extract the data we need to persist
      var pos = annotation.position || {};
      var camPos = annotation.cameraPosition || {};
      var camTarget = annotation.cameraTarget || {};
      var titleValue = annotation._title;

      const annotationData = {
        uuid: annotation.uuid,
        title: typeof titleValue === 'string' ? titleValue : (titleValue && titleValue.toString ? titleValue.toString() : 'No Title'),
        description: annotation._description || '',
        // Position
        positionX: pos.x !== undefined ? pos.x : 0,
        positionY: pos.y !== undefined ? pos.y : 0,
        positionZ: pos.z !== undefined ? pos.z : 0,
        // Camera position
        cameraPositionX: camPos.x !== undefined ? camPos.x : null,
        cameraPositionY: camPos.y !== undefined ? camPos.y : null,
        cameraPositionZ: camPos.z !== undefined ? camPos.z : null,
        // Camera target
        cameraTargetX: camTarget.x !== undefined ? camTarget.x : null,
        cameraTargetY: camTarget.y !== undefined ? camTarget.y : null,
        cameraTargetZ: camTarget.z !== undefined ? camTarget.z : null,
        // Optional radius
        radius: annotation.radius !== undefined ? annotation.radius : null
      };

      const response = await fetch(`${this.getEndpoint()}/annotations`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(annotationData)
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();

      if (data.success) {
        return true;
      } else {
        console.error('API returned error:', data.error);
        return false;
      }
    } catch (error) {
      console.error('Failed to save annotation:', error);
      return false;
    }
  },

  /**
   * Delete an annotation from the backend
   * @param {string} uuid - The UUID of the annotation to delete
   * @returns {Promise<boolean>} True if successful, false otherwise
   */
  async deleteAnnotation(uuid) {
    try {
      const response = await fetch(`${this.getEndpoint()}/annotations`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ uuid })
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();

      if (data.success) {
        return true;
      } else {
        console.error('API returned error:', data.error);
        return false;
      }
    } catch (error) {
      console.error('Failed to delete annotation:', error);
      return false;
    }
  },

  /**
   * Convert API response data to Potree Annotation constructor args
   * @param {Object} data - The annotation data from API
   * @returns {Object} Constructor args for Potree.Annotation
   */
  toAnnotationArgs(data) {
    return {
      position: [data.positionX, data.positionY, data.positionZ],
      title: data.title || 'No Title',
      description: data.description || '',
      cameraPosition: data.cameraPositionX != null ? [data.cameraPositionX, data.cameraPositionY, data.cameraPositionZ] : undefined,
      cameraTarget: data.cameraTargetX != null ? [data.cameraTargetX, data.cameraTargetY, data.cameraTargetZ] : undefined,
      radius: data.radius !== undefined ? data.radius : undefined
    };
  }
};

// Also export as default for flexibility
export default AnnotationAPI;
