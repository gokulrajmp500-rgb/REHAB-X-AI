globalThis.rehabXPoseDetector = (() => {
  const landmarkNames = [
    'nose',
    'leftEyeInner',
    'leftEye',
    'leftEyeOuter',
    'rightEyeInner',
    'rightEye',
    'rightEyeOuter',
    'leftEar',
    'rightEar',
    'leftMouth',
    'rightMouth',
    'leftShoulder',
    'rightShoulder',
    'leftElbow',
    'rightElbow',
    'leftWrist',
    'rightWrist',
    'leftPinky',
    'rightPinky',
    'leftIndex',
    'rightIndex',
    'leftThumb',
    'rightThumb',
    'leftHip',
    'rightHip',
    'leftKnee',
    'rightKnee',
    'leftAnkle',
    'rightAnkle',
    'leftHeel',
    'rightHeel',
    'leftFootIndex',
    'rightFootIndex',
  ];
  let landmarker;

  return {
    async initialize() {
      if (landmarker) return true;
      const vision = await import(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/+esm'
      );
      const fileset = await vision.FilesetResolver.forVisionTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm',
      );
      const options = {
        baseOptions: {
          modelAssetPath:
            'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task',
        },
        runningMode: 'VIDEO',
        numPoses: 2,
        minPoseDetectionConfidence: 0.6,
        minPosePresenceConfidence: 0.6,
        minTrackingConfidence: 0.6,
      };
      try {
        landmarker = await vision.PoseLandmarker.createFromOptions(fileset, {
          ...options,
          baseOptions: { ...options.baseOptions, delegate: 'GPU' },
        });
      } catch (gpuError) {
        console.warn('MediaPipe GPU unavailable; using CPU inference.', gpuError);
        landmarker = await vision.PoseLandmarker.createFromOptions(fileset, options);
      }
      return true;
    },

    detect() {
      if (!landmarker) return JSON.stringify({ width: 0, height: 0, people: 0 });
      const video = [...document.querySelectorAll('video')].find(
        (candidate) =>
          candidate.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA &&
          candidate.videoWidth > 0 &&
          candidate.videoHeight > 0,
      );
      if (!video) return JSON.stringify({ width: 0, height: 0, people: 0 });

      const result = landmarker.detectForVideo(video, performance.now());
      const poses = result.landmarks ?? [];
      const landmarks = (poses[0] ?? []).flatMap((point, index) => {
        const name = landmarkNames[index];
        if (!name) return [];
        const confidence = Math.min(
          point.visibility ?? point.presence ?? 0,
          point.presence ?? point.visibility ?? 0,
        );
        return [{
          name,
          x: point.x * video.videoWidth,
          y: point.y * video.videoHeight,
          z: (point.z ?? 0) * video.videoWidth,
          confidence,
        }];
      });

      return JSON.stringify({
        width: video.videoWidth,
        height: video.videoHeight,
        people: poses.length,
        landmarks,
      });
    },
  };
})();
