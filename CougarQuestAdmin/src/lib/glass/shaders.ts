export const vertexShader = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

export const fragmentShader = /* glsl */ `
  precision highp float;

  uniform sampler2D uBackgroundTexture;
  uniform vec2 uResolution;
  uniform vec2 uElementPosition;
  uniform vec2 uElementSize;
  uniform float uThickness;
  uniform float uIor;
  uniform vec3 uDispersion;
  uniform float uOpacity;
  uniform float uBlurRadius;
  uniform float uTime;
  uniform vec2 uMouse;
  uniform float uBorderRadius;
  uniform vec4 uCornerRadii;  // tl, tr, br, bl (in normalized units)
  uniform vec2 uShapeSize;
  uniform int uShapeType;
  uniform float uReducedMotion;
  uniform float uAberrationIntensity;
  uniform vec2 uAspect;

  #define MAX_PEERS 4
  uniform int uPeerCount;
  uniform vec2 uPeerPositions[MAX_PEERS];
  uniform vec2 uPeerSizes[MAX_PEERS];
  uniform float uPeerOverlaps[MAX_PEERS];
  uniform vec3 uPeerColors[MAX_PEERS];
  uniform float uMorphSmoothness;
  uniform float uIsDragging;
  uniform vec3 uWallpaperTint;
  uniform vec2 uLightDir;
  uniform float uLightIntensity;
  uniform vec2 uDragVelocity;

  // Merge state per peer
  uniform float uPeerMergeStates[MAX_PEERS];
  uniform float uPeerReleaseTimes[MAX_PEERS];
  uniform float uPeerHoldProgress[MAX_PEERS];
  uniform float uHapticIntensity;

  varying vec2 vUv;

  #define PI 3.14159265

  // --- SDF ---

  // Per-corner rounded rect SDF (radii: tl, tr, br, bl)
  float sdRoundedRect4(vec2 p, vec2 size, vec4 radii) {
    float maxR = min(size.x, size.y);
    vec4 r = min(radii, vec4(maxR));
    // Select radius based on quadrant
    float radius = (p.x > 0.0)
      ? ((p.y > 0.0) ? r.y : r.z)  // tr or br
      : ((p.y > 0.0) ? r.x : r.w); // tl or bl
    vec2 d = abs(p) - size + radius;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
  }

  float sdRoundedRect(vec2 p, vec2 size, float radius) {
    return sdRoundedRect4(p, size, vec4(radius));
  }

  float sdCircle(vec2 p, float radius) {
    return length(p) - radius;
  }

  float sdPill(vec2 p, vec2 halfSize) {
    float r = min(halfSize.x, halfSize.y);
    float extent = max(halfSize.x - r, 0.0);
    p.x = abs(p.x);
    p.x = max(p.x - extent, 0.0);
    return length(p) - r;
  }

  float getMainSDF(vec2 uv) {
    vec2 p = (uv - 0.5) * uAspect;
    vec2 halfSize = uShapeSize * 0.5 * uAspect;
    if (uShapeType == 1) {
      return sdCircle(p, min(halfSize.x, halfSize.y));
    } else if (uShapeType == 2) {
      return sdPill(p, halfSize);
    } else {
      // Per-corner radii (uniform uCornerRadii: tl, tr, br, bl)
      float s = min(uAspect.x, uAspect.y);
      vec4 cr = uCornerRadii * s;
      return sdRoundedRect4(p, halfSize, cr);
    }
  }

  // --- Smooth min ---

  float smin(float a, float b, float k) {
    if (k < 0.0001) return min(a, b);
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k * (1.0 / 6.0);
  }

  // --- Peer SDF ---

  float getPeerSDF(vec2 uv, int idx) {
    vec2 p = (uv - 0.5) * uAspect;
    vec2 peerCenter = (uPeerPositions[idx] - 0.5) * uAspect;
    vec2 peerHalf = uPeerSizes[idx] * 0.5 * uAspect;
    vec2 d = p - peerCenter;
    vec2 safe = max(peerHalf, vec2(0.001));
    float r = length(d / safe);
    return (r - 1.0) * min(safe.x, safe.y);
  }

  // ============================================================================
  // COMBINED SDF — smooth union with physics simulation
  // ============================================================================

  float getCombinedSDF(vec2 uv) {
    float d = getMainSDF(uv);
    float originalD = d;
    vec2 p = (uv - 0.5) * uAspect;

    float mainRipple = 0.0;

    for (int i = 0; i < MAX_PEERS; i++) {
      if (i >= uPeerCount) break;
      float overlap = uPeerOverlaps[i];
      float ms = uPeerMergeStates[i];
      float hp = uPeerHoldProgress[i];
      float rt = uPeerReleaseTimes[i];

      if (overlap < 0.01 && ms < 0.5) continue;

      float peerD = getPeerSDF(uv, i);
      vec2 peerCenter = (uPeerPositions[i] - 0.5) * uAspect;

      // Release ripple: subtle sinusoidal wave on SDF boundary
      if (ms > 1.5) {
        float dist = length(p - peerCenter);
        float ripple = 0.02 * sin(2.0 * PI * 4.0 * rt - 8.0 * dist) * exp(-4.0 * rt);
        peerD += ripple;

        // Surface wobble on our own shape after snap-apart
        float ef = smoothstep(0.0, 0.1, -originalD + 0.05);
        mainRipple += ripple * 0.2 * ef;
      }

      // Directional: only deform the side facing the peer
      float pcLen = length(peerCenter);
      float pLen = length(p);
      float alignment = (pLen > 0.001 && pcLen > 0.001)
        ? dot(p / pLen, peerCenter / pcLen)
        : 0.0;
      float directional = smoothstep(-0.1, 0.5, alignment);

      float effectiveOverlap = max(overlap, hp * 0.5);
      float k = uMorphSmoothness * min(effectiveOverlap, 1.0) * directional;
      float overlapReduce = smoothstep(1.2, 2.0, overlap);
      k = mix(k, k * 0.25, overlapReduce);

      // Hold: slightly deeper fusion
      k *= 1.0 + hp * 0.4;

      d = smin(d, peerD, k);
    }

    d += mainRipple;
    d += uHapticIntensity * sin(uTime * 80.0) * 0.001;

    return d;
  }

  float getClosestPeerSDF(vec2 uv) {
    float closest = 10000.0;
    for (int i = 0; i < MAX_PEERS; i++) {
      if (i >= uPeerCount) break;
      float overlap = uPeerOverlaps[i];
      float ms = uPeerMergeStates[i];
      if (overlap < 0.01 && ms < 0.5) continue;
      closest = min(closest, getPeerSDF(uv, i));
    }
    return closest;
  }

  // --- Normal (for Fresnel, specular, rim — not for distortion) ---

  vec3 computeNormal(vec2 uv) {
    float eps = 0.012;
    float dx = getCombinedSDF(uv + vec2(eps, 0.0)) - getCombinedSDF(uv - vec2(eps, 0.0));
    float dy = getCombinedSDF(uv + vec2(0.0, eps)) - getCombinedSDF(uv - vec2(0.0, eps));
    float d = getCombinedSDF(uv);
    float distFromEdge = max(-d, 0.0);
    float curvatureWidth = 0.08 * max(uAspect.x, uAspect.y);
    float edgeFactor = 1.0 - smoothstep(0.0, curvatureWidth, distFromEdge);
    vec2 grad = vec2(dx, dy);
    float gl = length(grad);
    if (gl > 0.0001) grad /= gl;
    float tilt = 0.2 * edgeFactor;
    return normalize(vec3(-grad * tilt, 1.0));
  }

  // --- Optics ---

  float fresnelSchlick(float cosTheta, float ior) {
    float r0 = (1.0 - ior) / (1.0 + ior);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
  }

  float computeSpecular(vec3 normal) {
    vec3 lightDir = normalize(vec3(0.3, 0.5, 1.0));
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 halfVec = normalize(lightDir + viewDir);
    return pow(max(dot(normal, halfVec), 0.0), 56.0) * 0.35;
  }

  float beersLaw(float t) {
    return exp(-0.02 * t);
  }

  vec3 gaussianBlur(sampler2D tex, vec2 uv, vec2 texel, float radius) {
    if (radius < 0.001) return texture2D(tex, uv).rgb;
    vec3 col = vec3(0.0);
    float total = 0.0;
    float sigma = max(radius * 0.45, 0.001);
    float inv2s2 = 1.0 / (2.0 * sigma * sigma);
    for (int x = -3; x <= 3; x++) {
      for (int y = -3; y <= 3; y++) {
        float d2 = float(x * x + y * y);
        float w = exp(-d2 * inv2s2);
        vec2 off = vec2(float(x), float(y)) * texel * radius;
        col += texture2D(tex, clamp(uv + off, 0.0, 1.0)).rgb * w;
        total += w;
      }
    }
    return col / total;
  }

  vec3 computePeerReflection(vec2 uv, vec3 normal, float fresnel) {
    vec3 refl = vec3(0.0);
    for (int i = 0; i < MAX_PEERS; i++) {
      if (i >= uPeerCount) break;
      if (uPeerOverlaps[i] < 0.001) continue;
      vec3 pc = uPeerColors[i];
      float lum = dot(pc, vec3(0.299, 0.587, 0.114));
      vec2 tp = uPeerPositions[i] - uv;
      float dist = length(tp);
      float falloff = 1.0 / (1.0 + dist * dist * 10.0);
      float dm = max(dot(normalize(vec3(tp, 0.0)), normal), 0.0);
      refl += pc * lum * fresnel * falloff * dm * uPeerOverlaps[i] * 1.5;
    }
    return refl;
  }

  // --- MAIN ---

  void main() {
    vec2 uv = vUv;
    float mainD = getMainSDF(uv);
    float combinedD = getCombinedSDF(uv);

    float aaWidth = 1.5 / max(uResolution.x, uResolution.y);
    float shapeMask = 1.0 - smoothstep(-aaWidth, aaWidth, combinedD);
    if (shapeMask < 0.001) discard;

    // Territory — Voronoi split for bridge; hard cut for overlap
    float territoryAlpha = 1.0;
    float closestPeerD = 10000.0;

    if (uPeerCount > 0) {
      closestPeerD = getClosestPeerSDF(uv);

      if (mainD > 0.0 && closestPeerD < 10000.0) {
        // Bridge zone — wider blend for smoother morph seam
        float blend = 0.02 * max(uAspect.x, uAspect.y);
        float maxHold = 0.0;
        for (int i = 0; i < MAX_PEERS; i++) {
          if (i >= uPeerCount) break;
          maxHold = max(maxHold, uPeerHoldProgress[i]);
        }
        blend *= 1.0 + maxHold * 1.5;
        territoryAlpha = smoothstep(-blend, blend, closestPeerD - mainD);
        if (territoryAlpha < 0.001) discard;
      } else if (mainD <= 0.0 && closestPeerD < 0.0) {
        // Overlap zone — hard cut
        float bias = 0.005 * max(uAspect.x, uAspect.y);
        if (closestPeerD < mainD - bias) discard;
      }
    }

    // ========================================================================
    // RADIAL LENS DISTORTION — Apple Liquid Glass model
    // Convex lens: max distortion at edges, zero at center
    // Background pixels pushed radially outward → magnification effect
    // ========================================================================

    // Inversed SDF: 0 at edge, increases toward center
    float glassMinDim = min(uShapeSize.x, uShapeSize.y) * max(uAspect.x, uAspect.y) * 0.5;
    float inversedSDF = clamp(-combinedD / max(glassMinDim, 0.001), 0.0, 1.0);

    // Lens zone: distortion strongest in outer ~70% of shape
    float distFromCenter = 1.0 - clamp(inversedSDF / 0.35, 0.0, 1.0);

    // Quarter-circle lens profile: convex magnification
    float lensDistortion = 1.0 - sqrt(max(1.0 - distFromCenter * distFromCenter, 0.0));

    // Scale with thickness (thicker glass = more refraction)
    lensDistortion *= min(uThickness * 0.08, 0.35);

    // Fade lens distortion in bridge zone to prevent seam color mismatch
    float bridgeFactor = (mainD > 0.0 && combinedD < 0.0)
      ? smoothstep(0.0, 0.02, mainD) : 0.0;
    lensDistortion *= 1.0 - bridgeFactor;

    // Radial direction from geometric center (smooth, no medial axis artifacts)
    vec2 bgUvCenter = uElementPosition + vec2(0.5) * uElementSize;
    vec2 bgUvPixel = uElementPosition + uv * uElementSize;
    vec2 fromCenter = bgUvPixel - bgUvCenter;
    float fcLen = length(fromCenter);
    vec2 radialDir = fcLen > 0.0001 ? fromCenter / fcLen : vec2(0.0);

    // Displacement: radial outward push proportional to element size
    float maxOffset = max(uElementSize.x, uElementSize.y) * 0.5;
    vec2 lensOffset = lensDistortion * radialDir * maxOffset;

    vec2 bgUv = bgUvPixel - lensOffset;

    // Chromatic aberration: edge-biased radial R/B shift (Apple: ~3px)
    float caFade = smoothstep(0.0, 0.02, inversedSDF);
    vec2 caShift = radialDir * caFade * uAberrationIntensity * 0.0008;

    // Variable blur: center more blurred, edges less (Apple model)
    float depthBlur = 1.0 - distFromCenter * 0.4;
    float blurAmt = uBlurRadius / max(uResolution.x, 1.0) * 2.5 * depthBlur;
    vec2 texel = 1.0 / uResolution;

    vec3 refracted;
    if (uReducedMotion > 0.5) {
      refracted = gaussianBlur(uBackgroundTexture, bgUv, texel, blurAmt);
    } else {
      refracted.r = gaussianBlur(uBackgroundTexture, clamp(bgUv - caShift, 0.0, 1.0), texel, blurAmt).r;
      refracted.g = gaussianBlur(uBackgroundTexture, clamp(bgUv, 0.0, 1.0), texel, blurAmt).g;
      refracted.b = gaussianBlur(uBackgroundTexture, clamp(bgUv + caShift, 0.0, 1.0), texel, blurAmt).b;
    }

    // Normal (for Fresnel, specular, rim — distortion handled by lens above)
    vec3 normal = computeNormal(uv);
    // Flatten in bridge zone so both elements produce identical pixels at seam
    normal = mix(normal, vec3(0.0, 0.0, 1.0), bridgeFactor);

    float cosTheta = max(dot(normal, vec3(0.0, 0.0, 1.0)), 0.0);
    float fresnel = fresnelSchlick(cosTheta, uIor);
    float spec = computeSpecular(normal);
    float absorption = beersLaw(uThickness);

    // Env reflection
    vec3 envColor = gaussianBlur(uBackgroundTexture, bgUv, texel, blurAmt * 4.0);
    envColor = envColor * 0.55 + vec3(0.5);

    // Composite — reduce env reflection + specular in bridge to minimize seam
    float fresnelBridge = fresnel * (1.0 - bridgeFactor * 0.9);
    vec3 glass = mix(refracted, envColor, fresnelBridge * 0.25);
    glass *= absorption;
    glass += vec3(1.0) * spec * (1.0 - bridgeFactor * 0.8);

    // Narrow edge blend — only in the AA zone to prevent fringe
    // Skip in bridge zone (mainD > 0) to avoid dark crease between morphed elements
    vec3 rawBg = texture2D(uBackgroundTexture, bgUvPixel).rgb;
    float inBridge = mainD > 0.0 && combinedD < 0.0 ? 1.0 : 0.0;
    float edgeFade = smoothstep(0.0, aaWidth * 2.0, -combinedD);
    edgeFade = max(edgeFade, inBridge);
    glass = mix(rawBg, glass, edgeFade);

    // Gloss
    float glossAngle = max(dot(normal, normalize(vec3(-0.15, 0.35, 1.0))), 0.0);
    float gloss = pow(glossAngle, 2.5) * 0.12 * min(uThickness * 0.3, 1.0);
    vec3 glossTint = mix(vec3(1.0), uWallpaperTint * 0.3 + vec3(0.7), 0.2);
    glass += glossTint * gloss;

    // Rim light — cursor point light + wallpaper tinting + light mapping
    float edgeDist = -combinedD;
    float rimW = 0.006 * max(uAspect.x, uAspect.y);
    float rimMask = smoothstep(rimW, 0.0, edgeDist);

    float cursorDist = length(uMouse - uv);
    float cursorBright = exp(-cursorDist * cursorDist * 0.8);
    float rimFresnel = (1.0 - cosTheta) * 0.2;

    vec2 rimNorm2D = normal.xy;
    float lightMap = max(dot(normalize(rimNorm2D + vec2(0.001)), uLightDir), 0.0);
    float lightBoost = lightMap * uLightIntensity * 0.2;

    float rimIntensity = cursorBright * 0.6 + rimFresnel + lightBoost + 0.1;

    // iOS 26 directional rim: bright on edges facing the cursor, fades on opposite
    vec2 toLightRim = uMouse - uv;
    float tlRimLen = length(toLightRim);
    vec2 tlRimDir = tlRimLen > 0.001 ? toLightRim / tlRimLen : vec2(0.0);
    float rimFacing = max(dot(normalize(normal.xy + vec2(0.001)), tlRimDir), 0.0);
    float directionalFade = rimFacing * 0.82 + 0.1;
    rimIntensity *= directionalFade;

    vec3 rimTint = mix(vec3(0.85), uWallpaperTint, 0.3);
    vec3 rimColor = rimTint * 0.4 + vec3(0.6);
    glass += rimColor * rimIntensity * rimMask * territoryAlpha * (1.0 - bridgeFactor * 0.8);

    // Drag gleam
    float dragSpeed = length(uDragVelocity);
    if (dragSpeed > 0.01 && rimMask > 0.01) {
      vec2 dragDir = uDragVelocity / max(dragSpeed, 0.001);
      float gleamPos = fract(dot(uv - 0.5, dragDir) * 2.0 + uTime * 1.5);
      float gleam = exp(-pow((gleamPos - 0.5) * 5.0, 2.0));
      glass += vec3(1.0) * gleam * rimMask * 0.25 * smoothstep(0.01, 0.3, dragSpeed);
    }

    glass += computePeerReflection(uv, normal, fresnel);

    if (uIsDragging > 0.5) {
      glass += vec3(0.02, 0.03, 0.04);
    }

    // Subtle cool tint
    float lum = dot(refracted, vec3(0.299, 0.587, 0.114));
    vec3 tint = mix(vec3(0.85, 0.87, 0.92), vec3(1.0, 1.0, 1.0), lum);
    glass = mix(glass, glass * tint, 0.04);

    float alpha = shapeMask * uOpacity * territoryAlpha;

    gl_FragColor = vec4(glass, alpha);
  }
`;

// ============================================================================
// CONTAINER FRAGMENT SHADER
// Single canvas renders ALL child shapes as a unified SDF via smooth union.
// No territory splitting, no seams — one glass surface.
// Up to 12 shapes, each with position, size, type, corner radius, animProgress.
// ============================================================================

export const containerFragmentShader = /* glsl */ `
  precision highp float;

  uniform sampler2D uBackgroundTexture;
  uniform vec2 uResolution;
  uniform vec2 uContainerPosition; // container top-left in screen UV
  uniform vec2 uContainerSize;     // container size in screen UV
  uniform float uThickness;
  uniform float uIor;
  uniform vec3 uDispersion;
  uniform float uOpacity;
  uniform float uBlurRadius;
  uniform float uTime;
  uniform vec2 uMouse;
  uniform float uReducedMotion;
  uniform float uAberrationIntensity;
  uniform vec3 uWallpaperTint;
  uniform vec2 uLightDir;
  uniform float uLightIntensity;
  uniform float uMorphSmoothness;
  uniform float uEdgeFalloff;
  uniform vec4 uGlassTint; // rgb = tint color, a = strength (0 = no tint)

  #define MAX_SHAPES 12
  uniform int uShapeCount;
  uniform vec2 uShapePositions[MAX_SHAPES];  // center in canvas UV [0,1]
  uniform vec2 uShapeSizes[MAX_SHAPES];      // half-size in canvas UV
  uniform int uShapeTypes[MAX_SHAPES];       // 0=rect, 1=circle, 2=pill
  uniform float uShapeRadii[MAX_SHAPES];     // border radius (normalized)
  uniform float uShapeAnim[MAX_SHAPES];      // 0=hidden, 1=shown, >1=bounce

  varying vec2 vUv;

  #define PI 3.14159265

  // --- SDF primitives ---

  float sdRoundedRect(vec2 p, vec2 size, float radius) {
    float r = min(radius, min(size.x, size.y));
    vec2 d = abs(p) - size + r;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
  }

  float sdCircle(vec2 p, float radius) {
    return length(p) - radius;
  }

  float sdPill(vec2 p, vec2 halfSize) {
    float r = min(halfSize.x, halfSize.y);
    float extent = max(halfSize.x - r, 0.0);
    p.x = abs(p.x);
    p.x = max(p.x - extent, 0.0);
    return length(p) - r;
  }

  float smin(float a, float b, float k) {
    if (k < 0.0001) return min(a, b);
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k * (1.0 / 6.0);
  }

  // --- Per-shape SDF ---

  float getShapeSDF(vec2 uv, int idx) {
    vec2 center = uShapePositions[idx];
    vec2 halfSize = uShapeSizes[idx] * uShapeAnim[idx];
    float radius = uShapeRadii[idx];
    int shapeType = uShapeTypes[idx];

    vec2 p = uv - center;

    // Aspect correction — work in pixel-proportional space
    float aspect = uResolution.x / max(uResolution.y, 1.0);
    vec2 aspectVec = vec2(
      aspect > 1.0 ? 1.0 : aspect,
      aspect > 1.0 ? 1.0 / aspect : 1.0
    );
    p *= aspectVec;
    vec2 hs = halfSize * aspectVec;

    if (shapeType == 1) {
      return sdCircle(p, min(hs.x, hs.y));
    } else if (shapeType == 2) {
      return sdPill(p, hs);
    } else {
      float s = min(aspectVec.x, aspectVec.y);
      return sdRoundedRect(p, hs, radius * s);
    }
  }

  // --- Combined SDF: smooth union of all shapes ---

  float getCombinedSDF(vec2 uv) {
    float d = 10000.0;
    for (int i = 0; i < MAX_SHAPES; i++) {
      if (i >= uShapeCount) break;
      if (uShapeAnim[i] < 0.001) continue; // hidden
      float shapeDist = getShapeSDF(uv, i);
      d = smin(d, shapeDist, uMorphSmoothness);
    }
    return d;
  }

  // --- Nearest shape center (for radial distortion direction) ---

  vec2 getNearestShapeCenter(vec2 uv) {
    float minD = 10000.0;
    vec2 nearest = vec2(0.5);
    for (int i = 0; i < MAX_SHAPES; i++) {
      if (i >= uShapeCount) break;
      if (uShapeAnim[i] < 0.001) continue;
      float d = getShapeSDF(uv, i);
      if (d < minD) {
        minD = d;
        nearest = uShapePositions[i];
      }
    }
    return nearest;
  }

  // --- Normal ---

  vec3 computeNormal(vec2 uv) {
    float eps = 0.012;
    float dx = getCombinedSDF(uv + vec2(eps, 0.0)) - getCombinedSDF(uv - vec2(eps, 0.0));
    float dy = getCombinedSDF(uv + vec2(0.0, eps)) - getCombinedSDF(uv - vec2(0.0, eps));
    float d = getCombinedSDF(uv);
    float distFromEdge = max(-d, 0.0);
    float aspect = uResolution.x / max(uResolution.y, 1.0);
    float maxAspect = max(aspect > 1.0 ? 1.0 : aspect, aspect > 1.0 ? 1.0 / aspect : 1.0);
    float curvatureWidth = 0.08 * maxAspect;
    float edgeFactor = 1.0 - smoothstep(0.0, curvatureWidth, distFromEdge);
    vec2 grad = vec2(dx, dy);
    float gl = length(grad);
    if (gl > 0.0001) grad /= gl;
    float tilt = 0.2 * edgeFactor;
    return normalize(vec3(-grad * tilt, 1.0));
  }

  // --- Optics ---

  float fresnelSchlick(float cosTheta, float ior) {
    float r0 = (1.0 - ior) / (1.0 + ior);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
  }

  float computeSpecular(vec3 normal) {
    vec3 lightDir = normalize(vec3(0.3, 0.5, 1.0));
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 halfVec = normalize(lightDir + viewDir);
    return pow(max(dot(normal, halfVec), 0.0), 56.0) * 0.35;
  }

  float beersLaw(float t) {
    return exp(-0.02 * t);
  }

  vec3 gaussianBlur(sampler2D tex, vec2 uv, vec2 texel, float radius) {
    if (radius < 0.001) return texture2D(tex, uv).rgb;
    vec3 col = vec3(0.0);
    float total = 0.0;
    float sigma = max(radius * 0.45, 0.001);
    float inv2s2 = 1.0 / (2.0 * sigma * sigma);
    for (int x = -3; x <= 3; x++) {
      for (int y = -3; y <= 3; y++) {
        float d2 = float(x * x + y * y);
        float w = exp(-d2 * inv2s2);
        vec2 off = vec2(float(x), float(y)) * texel * radius;
        col += texture2D(tex, clamp(uv + off, 0.0, 1.0)).rgb * w;
        total += w;
      }
    }
    return col / total;
  }

  // --- MAIN ---

  void main() {
    vec2 uv = vUv;
    float combinedD = getCombinedSDF(uv);

    float aaWidth = 1.5 / max(uResolution.x, uResolution.y);
    float shapeMask = 1.0 - smoothstep(-aaWidth, aaWidth, combinedD);
    if (shapeMask < 0.001) discard;

    // Aspect
    float aspect = uResolution.x / max(uResolution.y, 1.0);
    vec2 aspectVec = vec2(
      aspect > 1.0 ? 1.0 : aspect,
      aspect > 1.0 ? 1.0 / aspect : 1.0
    );

    // Find nearest shape for radial distortion center
    vec2 shapeCenter = getNearestShapeCenter(uv);

    // Radial lens distortion
    float glassMinDim = min(aspectVec.x, aspectVec.y) * 0.3;
    float inversedSDF = clamp(-combinedD / max(glassMinDim, 0.001), 0.0, 1.0);
    float distFromCenter = 1.0 - clamp(inversedSDF / 0.35, 0.0, 1.0);
    float lensDistortion = 1.0 - sqrt(max(1.0 - distFromCenter * distFromCenter, 0.0));
    lensDistortion *= min(uThickness * 0.08, 0.35);

    // Radial direction from nearest shape center
    vec2 bgUvCenter = uContainerPosition + shapeCenter * uContainerSize;
    vec2 bgUvPixel = uContainerPosition + uv * uContainerSize;
    vec2 fromCenter = bgUvPixel - bgUvCenter;
    float fcLen = length(fromCenter);
    vec2 radialDir = fcLen > 0.0001 ? fromCenter / fcLen : vec2(0.0);

    float maxOffset = max(uContainerSize.x, uContainerSize.y) * 0.5;
    vec2 lensOffset = lensDistortion * radialDir * maxOffset;
    vec2 bgUv = bgUvPixel - lensOffset;

    // Chromatic aberration
    float caFade = smoothstep(0.0, 0.02, inversedSDF);
    vec2 caShift = radialDir * caFade * uAberrationIntensity * 0.0008;

    // Variable blur
    float depthBlur = 1.0 - distFromCenter * 0.4;
    float blurAmt = uBlurRadius / max(uResolution.x, 1.0) * 2.5 * depthBlur;
    vec2 texel = 1.0 / uResolution;

    vec3 refracted;
    if (uReducedMotion > 0.5) {
      refracted = gaussianBlur(uBackgroundTexture, bgUv, texel, blurAmt);
    } else {
      refracted.r = gaussianBlur(uBackgroundTexture, clamp(bgUv - caShift, 0.0, 1.0), texel, blurAmt).r;
      refracted.g = gaussianBlur(uBackgroundTexture, clamp(bgUv, 0.0, 1.0), texel, blurAmt).g;
      refracted.b = gaussianBlur(uBackgroundTexture, clamp(bgUv + caShift, 0.0, 1.0), texel, blurAmt).b;
    }

    vec3 normal = computeNormal(uv);
    float cosTheta = max(dot(normal, vec3(0.0, 0.0, 1.0)), 0.0);
    float fresnel = fresnelSchlick(cosTheta, uIor);
    float spec = computeSpecular(normal);
    float absorption = beersLaw(uThickness);

    // Env reflection
    vec3 envColor = gaussianBlur(uBackgroundTexture, bgUv, texel, blurAmt * 4.0);
    envColor = envColor * 0.55 + vec3(0.5);

    vec3 glass = mix(refracted, envColor, fresnel * 0.25);
    glass *= absorption;
    glass += vec3(1.0) * spec;

    // Edge blend
    vec3 rawBg = texture2D(uBackgroundTexture, bgUvPixel).rgb;
    float edgeFade = smoothstep(0.0, aaWidth * 2.0, -combinedD);
    glass = mix(rawBg, glass, edgeFade);

    // Gloss
    float glossAngle = max(dot(normal, normalize(vec3(-0.15, 0.35, 1.0))), 0.0);
    float gloss = pow(glossAngle, 2.5) * 0.12 * min(uThickness * 0.3, 1.0);
    vec3 glossTint = mix(vec3(1.0), uWallpaperTint * 0.3 + vec3(0.7), 0.2);
    glass += glossTint * gloss;

    // Rim light
    float edgeDist = -combinedD;
    float maxAspect = max(aspectVec.x, aspectVec.y);
    float rimW = 0.006 * maxAspect;
    float rimMask = smoothstep(rimW, 0.0, edgeDist);

    float cursorDist = length(uMouse - uv);
    float cursorBright = exp(-cursorDist * cursorDist * 0.8);
    float rimFresnel = (1.0 - cosTheta) * 0.2;

    vec2 rimNorm2D = normal.xy;
    float lightMap = max(dot(normalize(rimNorm2D + vec2(0.001)), uLightDir), 0.0);
    float lightBoost = lightMap * uLightIntensity * 0.2;

    float rimIntensity = cursorBright * 0.6 + rimFresnel + lightBoost + 0.1;

    // iOS 26 directional rim: bright on edges facing the cursor, fades on opposite
    vec2 toLightRim = uMouse - uv;
    float tlRimLen = length(toLightRim);
    vec2 tlRimDir = tlRimLen > 0.001 ? toLightRim / tlRimLen : vec2(0.0);
    float rimFacing = max(dot(normalize(normal.xy + vec2(0.001)), tlRimDir), 0.0);
    float directionalFade = rimFacing * 0.82 + 0.1;
    rimIntensity *= directionalFade;

    vec3 rimTint = mix(vec3(0.85), uWallpaperTint, 0.3);
    vec3 rimColor = rimTint * 0.4 + vec3(0.6);
    glass += rimColor * rimIntensity * rimMask;

    // Cool tint
    float lum = dot(refracted, vec3(0.299, 0.587, 0.114));
    vec3 tint = mix(vec3(0.85, 0.87, 0.92), vec3(1.0, 1.0, 1.0), lum);
    glass = mix(glass, glass * tint, 0.04);

    // Glass color tint (e.g. gray for menus)
    glass = mix(glass, uGlassTint.rgb, uGlassTint.a);

    float alpha = shapeMask * uOpacity;
    gl_FragColor = vec4(glass, alpha);
  }
`;
