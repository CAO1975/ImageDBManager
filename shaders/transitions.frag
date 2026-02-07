#version 450

// 输入 & 输出
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 1) in float v_facing; // 0: 正面（旧图）, 1: 背面（新图）
layout(location = 2) in float v_progress;
layout(location = 0) out vec4 fragColor;

// Qt ShaderEffect 自动提供的 uniform
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int effectType;
    vec3 backgroundColor;
};

// Samplers
layout(binding = 1) uniform sampler2D from;
layout(binding = 2) uniform sampler2D to;

// ========== 常量定义 ==========
const vec2 CENTER = vec2(0.5, 0.5);
const float PI = 3.14159;
const float TWO_PI = 6.28318;
const float HALF_PI = 1.5708;

// ========== 通用工具函数 ==========

// 伪随机函数
float random(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// 平滑步进函数（三次Hermite插值）
float smoothStep3(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// 旋转矩阵
mat2 rotationMatrix(float angle) {
    float c = cos(angle), s = sin(angle);
    return mat2(c, s, -s, c);
}

// 计算极坐标
void toPolar(vec2 uv, vec2 center, out float dist, out float angle) {
    vec2 offset = uv - center;
    dist = length(offset);
    angle = atan(offset.y, offset.x);
}

// RGB色差分离
vec4 rgbSplit(sampler2D tex, vec2 uv, float offset) {
    float r = texture(tex, uv + vec2(offset, 0.0)).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv - vec2(offset, 0.0)).b;
    return vec4(r, g, b, 1.0);
}

// 盒式模糊
vec4 boxBlur(sampler2D tex, vec2 uv, float blurAmount, int samples) {
    vec4 color = vec4(0.0);
    float total = 0.0;
    for (int x = -samples; x <= samples; x++) {
        for (int y = -samples; y <= samples; y++) {
            vec2 offset = vec2(float(x), float(y)) * blurAmount;
            color += texture(tex, uv + offset);
            total += 1.0;
        }
    }
    return color / total;
}

// 计算过渡阶段（前半段/后半段）
struct PhaseInfo {
    float t;           // 0-1的归一化进度
    bool isFirstHalf;  // 是否前半段
};

PhaseInfo getPhase(float p) {
    PhaseInfo info;
    info.isFirstHalf = p < 0.5;
    info.t = info.isFirstHalf ? p * 2.0 : (p - 0.5) * 2.0;
    return info;
}

// 确保透明区域显示背景色
vec4 applyBackground(vec4 color, vec3 bg) {
    if (color.a < 0.01) return vec4(bg, 1.0);
    return vec4(color.rgb, 1.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 colorFrom = texture(from, uv);
    vec4 colorTo = texture(to, uv);
    float mixFactor = progress;

    // 根据效果类型选择不同的过渡方式
    switch(effectType) {
        case 0: // 溶解效果
        {
            float noise = random(uv);
            mixFactor = step(noise, progress);
            break;
        }

        case 1: // 马赛克
        {
            float tileSize = 0.05;
            vec2 tileUV = floor(uv / tileSize) * tileSize;
            float noise = random(tileUV);
            mixFactor = step(noise, progress);
            break;
        }

        case 2: // 水波扭曲
        {
            float waveIntensity = sin(progress * PI);
            float wave = sin(uv.y * 20.0 + progress * 10.0) * 0.02 * waveIntensity;
            colorFrom = texture(from, vec2(uv.x - wave, uv.y));
            colorTo = texture(to, vec2(uv.x + wave, uv.y));
            break;
        }

        case 3: // 从左向右擦除
        {
            mixFactor = step(uv.x, progress);
            break;
        }

        case 4: // 从右向左擦除
        {
            mixFactor = 1.0 - step(uv.x, 1.0 - progress);
            break;
        }

        case 5: // 从上向下擦除
        {
            mixFactor = step(uv.y, progress);
            break;
        }

        case 6: // 从下向上擦除
        {
            mixFactor = 1.0 - step(uv.y, 1.0 - progress);
            break;
        }

        case 7: // X轴窗帘（从中心向两侧）
        {
            mixFactor = step(abs(uv.x - 0.5), progress * 0.5);
            break;
        }

        case 8: // Y轴窗帘（从中心向上下）
        {
            mixFactor = step(abs(uv.y - 0.5), progress * 0.5);
            break;
        }

        case 9: // 故障艺术
        {
            float offset = 0.01 * sin(progress * 20.0);
            colorFrom = rgbSplit(from, uv, offset);

            float noise = random(uv);
            float glitch = step(noise, progress * 0.1);
            if (progress > 0.3 && progress < 0.7) {
                colorFrom = mix(colorFrom, vec4(1.0), glitch);
            }
            break;
        }

        case 10: // 旋转效果
        {
            float angleFrom = progress * PI;
            float angleTo = (1.0 - progress) * PI;
            vec2 uvFrom = CENTER + rotationMatrix(angleFrom) * (uv - CENTER);
            vec2 uvTo = CENTER + rotationMatrix(angleTo) * (uv - CENTER);
            colorFrom = texture(from, uvFrom);
            colorTo = texture(to, uvTo);
            break;
        }

        case 11: // 横向拉伸效果
        {
            vec2 offset = uv - CENTER;
            float angle = progress * PI;
            float scale = abs(cos(angle));
            vec2 scaledUV = CENTER + vec2(offset.x * scale, offset.y);
            
            if (angle < HALF_PI) {
                colorFrom = texture(from, scaledUV);
                mixFactor = 0.0;
            } else {
                colorFrom = texture(to, scaledUV);
                mixFactor = 1.0;
            }
            colorTo = colorFrom;
            break;
        }

        case 12: // 纵向拉伸效果
        {
            vec2 offset = uv - CENTER;
            float angle = progress * PI;
            float scale = abs(cos(angle));
            vec2 scaledUV = CENTER + vec2(offset.x, offset.y * scale);
            
            if (angle < HALF_PI) {
                colorFrom = texture(from, scaledUV);
                mixFactor = 0.0;
            } else {
                colorFrom = texture(to, scaledUV);
                mixFactor = 1.0;
            }
            colorTo = colorFrom;
            break;
        }

        case 13: // 百叶窗效果
        {
            // 百叶窗参数
            float numBlinds = 12.0;  // 百叶窗叶片数量
            float blindHeight = 1.0 / numBlinds;  // 每个叶片的高度

            // 计算当前像素所在的叶片编号
            float blindIndex = floor(uv.y / blindHeight);
            // 计算当前叶片内的相对位置 (0.0 到 1.0，0是叶片顶部，1是叶片底部)
            float blindPosition = fract(uv.y / blindHeight);

            // 百叶窗打开进度：progress从0到1
            // progress=0时完全关闭（全部显示旧图），progress=1时完全打开（全部显示新图）
            // 每个叶片交替从不同方向打开，形成百叶窗效果
            float blindPhase = mod(blindIndex, 2.0);  // 0或1，交替

            // 计算当前像素是否显示新图
            float showNew;

            if (blindPhase < 0.5) {
                // 叶片0,2,4,...：从下往上打开（下部先显示新图）
                showNew = smoothstep(blindPosition, blindPosition + 0.05, progress);
            } else {
                // 叶片1,3,5,...：从上往下打开（上部先显示新图）
            showNew = smoothstep(1.0 - blindPosition - 0.05, 1.0 - blindPosition, progress);
            }

            // mixFactor=0显示旧图，mixFactor=1显示新图
            mixFactor = showNew;

            break;
        }

        case 14: // 扭曲呼吸
        {
            vec2 offset = uv - CENTER;
            PhaseInfo phase = getPhase(progress);
            
            float scaleX = phase.isFirstHalf ? mix(1.0, 0.02, phase.t) : mix(0.02, 1.0, phase.t);
            float twistAngle = (phase.isFirstHalf ? phase.t : (1.0 - phase.t)) * PI;
            
            vec2 compressedUV = vec2(offset.x * scaleX, offset.y);
            float dist, angle;
            toPolar(compressedUV, vec2(0.0), dist, angle);
            
            float finalAngle = phase.isFirstHalf ? angle + twistAngle : angle - twistAngle;
            vec2 twistedUV = vec2(cos(finalAngle), sin(finalAngle)) * dist;
            
            if (phase.isFirstHalf) {
                colorFrom = texture(from, CENTER + twistedUV);
                mixFactor = 0.0;
            } else {
                colorFrom = texture(to, CENTER + twistedUV);
                mixFactor = 1.0;
            }
            colorTo = colorFrom;
            break;
        }

        case 15: // 涟漪扩散效果
        {
            float dist, angle;
            toPolar(uv, CENTER, dist, angle);
            vec2 dir = normalize(uv - CENTER);
            
            float ripple = sin(dist * 30.0 - progress * 15.0) * 0.02 * sin(progress * PI);
            vec2 uvRipple = uv + dir * ripple;
            colorFrom = texture(from, uvRipple);
            colorTo = texture(to, uvRipple);
            
            float waveRadius = progress * 0.9;
            mixFactor = 1.0 - smoothStep3(waveRadius - 0.1, waveRadius, dist);
            break;
        }

        case 16: // 鱼眼效果
        {
            vec2 offset = uv - CENTER;
            float dist = length(offset);
            PhaseInfo phase = getPhase(progress);
            
            float power = phase.isFirstHalf ? mix(1.0, 0.1, phase.t) : mix(0.1, 1.0, phase.t);
            float newDist = pow(dist, power);
            vec2 fishEyeUV = CENTER + normalize(offset) * newDist;
            
            if (phase.isFirstHalf) {
                colorFrom = texture(from, fishEyeUV);
                mixFactor = 0.0;
            } else {
                colorFrom = texture(to, fishEyeUV);
                mixFactor = 1.0;
            }
            colorTo = colorFrom;
            break;
        }

        case 17: // 横向切片效果
        {
            int numSlices = 20;
            float sliceHeight = 1.0 / float(numSlices);
            int sliceIndex = int(uv.y / sliceHeight);

            // 每个切片在垂直方向的位置 (0.0-1.0)
            float slicePos = fract(uv.y / sliceHeight);

            // 每个切片的滑动方向交替
            float direction = mod(float(sliceIndex), 2.0) > 0.5 ? 1.0 : -1.0;

            // 切片交替从不同方向开始过渡
            float phase = mod(float(sliceIndex), 2.0);
            float mixFactorSlice;

            if (phase < 0.5) {
                // 偶数切片：从下往上
                mixFactorSlice = smoothstep(slicePos, slicePos + 0.1, progress);
            } else {
                // 奇数切片：从上往下
                mixFactorSlice = smoothstep(1.0 - slicePos - 0.1, 1.0 - slicePos, progress);
            }

            mixFactor = mixFactorSlice;

            // 旧图片滑动偏移：向两侧滑动到图片外
            float slideOffset = progress * 1.2 * direction;

            // 旧图应用滑动
            vec2 slideUV = vec2(uv.x + slideOffset, uv.y);
            colorFrom = texture(from, slideUV);

            // 新图不滑动，直接采样
            colorTo = texture(to, uv);

            break;
        }

        case 18: // 纵向切片效果
        {
            int numSlices = 20;
            float sliceWidth = 1.0 / float(numSlices);
            int sliceIndex = int(uv.x / sliceWidth);

            // 每个切片在水平方向的位置 (0.0-1.0)
            float slicePos = fract(uv.x / sliceWidth);

            // 每个切片的滑动方向交替
            float direction = mod(float(sliceIndex), 2.0) > 0.5 ? 1.0 : -1.0;

            // 切片交替从不同方向开始过渡
            float phase = mod(float(sliceIndex), 2.0);
            float mixFactorSlice;

            if (phase < 0.5) {
                // 偶数切片：从左往右
                mixFactorSlice = smoothstep(slicePos, slicePos + 0.1, progress);
            } else {
                // 奇数切片：从右往左
                mixFactorSlice = smoothstep(1.0 - slicePos - 0.1, 1.0 - slicePos, progress);
            }

            mixFactor = mixFactorSlice;

            // 旧图片滑动偏移：向上下滑动到图片外
            float slideOffset = progress * 1.2 * direction;

            // 旧图应用滑动
            vec2 slideUV = vec2(uv.x, uv.y + slideOffset);
            colorFrom = texture(from, slideUV);

            // 新图不滑动，直接采样
            colorTo = texture(to, uv);

            break;
        }

        case 19: // 反色效果
        {
            vec4 invertedFrom = vec4(1.0 - colorFrom.rgb, colorFrom.a);
            vec4 invertedTo = vec4(1.0 - colorTo.rgb, colorTo.a);
            PhaseInfo phase = getPhase(progress);
            
            if (phase.isFirstHalf) {
                colorFrom = mix(colorFrom, invertedFrom, phase.t);
                mixFactor = 0.0;
            } else {
                colorFrom = mix(invertedTo, colorTo, phase.t);
                colorTo = colorFrom;
                mixFactor = 1.0;
            }
            break;
        }

        case 20: // 模糊渐变效果
        {
            PhaseInfo phase = getPhase(progress);
            float blurAmount = phase.isFirstHalf ? phase.t * 0.02 : (1.0 - phase.t) * 0.02;
            
            if (phase.isFirstHalf) {
                colorFrom = boxBlur(from, uv, blurAmount, 4);
                mixFactor = 0.0;
            } else {
                colorFrom = boxBlur(to, uv, blurAmount, 4);
                mixFactor = 1.0;
            }
            colorTo = colorFrom;
            break;
        }

        case 21: // 破碎效果
        {
            float dist, angle;
            toPolar(uv, CENTER, dist, angle);
            
            float numShards = 12.0;
            float shardAngle = TWO_PI / numShards;
            int shardIndex = int(mod(angle + PI, TWO_PI) / shardAngle);
            
            float seed = fract(sin(float(shardIndex) * 12.9898) * 43758.5453);
            vec2 shardDir = vec2(cos(float(shardIndex) * shardAngle), sin(float(shardIndex) * shardAngle));
            
            PhaseInfo phase = getPhase(progress);
            float flyDistance = (phase.isFirstHalf ? phase.t : (1.0 - phase.t)) * 0.3 * seed;
            vec2 shatteredUV = uv + shardDir * flyDistance * (phase.isFirstHalf ? 1.0 : -1.0);
            
            if (phase.isFirstHalf) {
                colorFrom = texture(from, shatteredUV);
                mixFactor = 0.0;
            } else {
                colorFrom = texture(to, shatteredUV);
                mixFactor = 1.0;
            }
            colorTo = colorFrom;
            break;
        }

        case 22: // 雷达扫描效果
        {
            float dist, angle;
            toPolar(uv, CENTER, dist, angle);
            
            float scanAngle = progress * TWO_PI;
            float normalizedAngle = mod(angle + PI, TWO_PI);
            
            mixFactor = smoothStep3(0.0, 0.05, scanAngle - normalizedAngle);
            colorFrom = texture(from, uv);
            colorTo = texture(to, uv);
            break;
        }

        case 23: // 万花筒效果（扇形展开/折叠过渡）
        {
            // 方案3：扇形展开/折叠过渡
            // 旧图 -> 扇形折叠成万花筒 -> 新图万花筒 -> 扇形展开成新图
            
            // 平滑进度曲线
            float t = smoothstep(0.0, 1.0, progress);
            
            // 分阶段参数
            float foldIn = smoothstep(0.0, 0.15, t);      // 0.15时完全折叠（加快）
            float unfoldOut = smoothstep(0.85, 1.0, t);     // 0.85时开始展开（加快）
            float mixOldNew = smoothstep(0.45, 0.55, t);      // 0.45-0.55之间混合旧新图（缩短）
            
            // 万花筒旋转参数（碎片持续旋转，减少圈数）
            float kaleidoRotation = t * 3.14159;  // 旋转180度（半圈）
            
            // 万花筒参数
            int numSegments = 6;
            float segmentAngle = 6.28318 / float(numSegments);
            
            // 中心点
            vec2 center = vec2(0.5, 0.5);
            
            // 计算相对坐标
            vec2 uv_rel = uv - center;
            
            // 计算极坐标
            float dist = length(uv_rel);
            float angle = atan(uv_rel.y, uv_rel.x);
            
            // 确保角度在0到2π之间
            if (angle < 0.0) angle += 6.28318;
            
            // 万花筒碎片旋转
            float rotatedAngle = angle + kaleidoRotation;
            
            // 计算当前点所在的扇形
            int segmentIndex = int(rotatedAngle / segmentAngle);
            
            // 计算扇形内的相对角度
            float segmentRelAngle = mod(rotatedAngle, segmentAngle);
            
            // 旧图的折叠强度：0.0-0.3逐渐从0增加到1
            float oldFoldStrength = foldIn;
            
            // 新图的展开强度：0.7-1.0逐渐从1减少到0
            float newUnfoldStrength = 1.0 - unfoldOut;
            
            // 镜像变换：扇形折叠/展开
            float mirroredAngle;
            if (segmentIndex % 2 == 0) {
                // 偶数扇形：正常角度 <-> 镜像角度
                float normalAngle = segmentRelAngle;
                float mirroredTarget = segmentAngle - segmentRelAngle;
                mirroredAngle = mix(normalAngle, mirroredTarget, oldFoldStrength);
            } else {
                // 奇数扇形：镜像角度 <-> 正常角度
                float mirroredTarget = segmentRelAngle;
                float normalAngle = segmentAngle - segmentRelAngle;
                mirroredAngle = mix(mirroredTarget, normalAngle, newUnfoldStrength);
            }
            
            // 转换回笛卡尔坐标
            vec2 oldNormalUV = center + vec2(cos(angle), sin(angle)) * dist;
            vec2 oldMirroredUV = center + vec2(cos(mirroredAngle), sin(mirroredAngle)) * dist;
            vec2 newNormalUV = center + vec2(cos(angle), sin(angle)) * dist;
            vec2 newMirroredUV = center + vec2(cos(mirroredAngle), sin(mirroredAngle)) * dist;
            
            // 确保UV坐标在有效范围内
            oldNormalUV = clamp(oldNormalUV, vec2(0.0), vec2(1.0));
            oldMirroredUV = clamp(oldMirroredUV, vec2(0.0), vec2(1.0));
            newNormalUV = clamp(newNormalUV, vec2(0.0), vec2(1.0));
            newMirroredUV = clamp(newMirroredUV, vec2(0.0), vec2(1.0));
            
            // 采样颜色
            vec4 oldNormal = texture(from, oldNormalUV);
            vec4 oldMirrored = texture(from, oldMirroredUV);
            vec4 newNormal = texture(to, newNormalUV);
            vec4 newMirrored = texture(to, newMirroredUV);
            
            // 计算旧图的混合强度：前半段逐渐增加（加快）
            float oldMixStrength = smoothstep(0.0, 0.15, t);
            
            // 计算新图的混合强度：后半段逐渐减少（加快）
            float newMixStrength = 1.0 - smoothstep(0.85, 1.0, t);
            
            // 混合旧图：正常 -> 镜像（折叠过程）
            vec4 oldColor = mix(oldNormal, oldMirrored, oldMixStrength);
            
            // 混合新图：镜像 -> 正常（展开过程）
            vec4 newColor = mix(newMirrored, newNormal, 1.0 - newMixStrength);
            
            // 设置最终颜色和混合因子
            colorFrom = oldColor;
            colorTo = newColor;
            mixFactor = mixOldNew;
            
            // 添加扇形边界线条效果
            float borderWidth = 0.005;
            float borderAngle = mod(rotatedAngle, segmentAngle);
            float border = smoothstep(0.0, borderWidth, borderAngle) + 
                         smoothstep(segmentAngle, segmentAngle - borderWidth, borderAngle);
            
            // 边界强度随折叠/展开强度变化
            float borderStrength = max(oldMixStrength, newMixStrength) * 0.3;
            
            vec3 borderColor = mix(vec3(1.0, 0.5, 0.0), vec3(0.0, 0.5, 1.0), t);
            colorFrom.rgb = mix(colorFrom.rgb, borderColor, border * borderStrength);
            colorTo.rgb = mix(colorTo.rgb, borderColor, border * borderStrength);

            break;
        }

        case 24: // 火焰燃烧效果
        {
            float distFromBottom = 1.0 - uv.y;
            float flameHeight = progress * 1.2;
            float flameJitter = sin(uv.x * 20.0 + progress * 10.0) * 0.02 * sin(progress * PI);
            float flameEdge = flameHeight + flameJitter;
            
            float burningZone = smoothStep3(flameEdge - 0.15, flameEdge, distFromBottom) *
                               (1.0 - smoothStep3(flameEdge, flameEdge + 0.05, distFromBottom));
            mixFactor = 1.0 - smoothStep3(flameEdge - 0.05, flameEdge + 0.05, distFromBottom);
            
            colorFrom = texture(from, uv);
            colorTo = texture(to, uv);
            
            if (burningZone > 0.01) {
                vec3 fireColor = mix(vec3(1.0, 0.0, 0.0), vec3(1.0, 0.5, 0.0), smoothStep3(0.0, 0.5, distFromBottom / flameEdge));
                fireColor = mix(fireColor, vec3(1.0, 0.8, 0.2), smoothStep3(0.5, 1.0, distFromBottom / flameEdge));
                float flicker = sin(uv.x * 30.0 + uv.y * 30.0 + progress * 20.0) * 0.5 + 0.5;
                fireColor *= (0.8 + 0.4 * flicker);
                colorFrom.rgb += fireColor * 0.5 * burningZone;
            }
            break;
        }

        case 25: // 水墨晕染效果
        {
            float dist = distance(uv, CENTER);
            float inkRadius = progress * 0.9;
            float inkJitter = random(uv) * 0.05 * sin(progress * PI);
            float inkEdge = inkRadius + inkJitter;
            
            mixFactor = smoothStep3(inkEdge - 0.1, inkEdge, dist);
            vec2 inkBlurUV = uv + random(uv * 10.0 + progress) * 0.01;
            colorFrom = texture(from, uv);
            colorTo = texture(to, inkBlurUV);
            break;
        }

        case 26: // 粒子爆炸效果
        {
            float dist = distance(uv, CENTER);

            // 粒子爆炸：旧图片碎裂成粒子向四周爆炸
            float particleSize = 0.05;  // 粒子大小（固定）
            float particleGridSize = 20.0;  // 粒子网格大小（20x20 = 400个粒子）

            // 计算粒子网格
            vec2 gridUV = uv * particleGridSize;
            vec2 gridID = floor(gridUV);
            vec2 gridPos = fract(gridUV);

            // 为每个粒子生成随机性
            float seed = fract(sin(dot(gridID, vec2(12.9898, 78.233))) * 43758.5453);
            float particleAngle = seed * 6.28318;  // 随机角度
            float particleSpeed = 0.3 + seed * 0.5;  // 随机速度 0.3-0.8

            // 粒子爆炸位置：随时间向外飞
            float explosionDist = progress * 1.2 * particleSpeed;
            vec2 particleOffset = explosionDist * vec2(cos(particleAngle), sin(particleAngle));

            // 从原始位置采样旧图（粒子飞走后留下的空隙）
            vec2 oldUV = uv + particleOffset;

            // 粒子形状：圆形
            float particleMask = smoothstep(0.5, 0.2, length(gridPos - 0.5));

            // 随着粒子飞远，逐渐变小
            particleMask *= smoothstep(1.2, 0.0, explosionDist);

            // 旧图只在粒子位置可见
            vec4 oldParticleColor = texture(from, oldUV);
            colorFrom = oldParticleColor * particleMask;

            // 新图从中心逐渐显现
            float newRadius = progress * 0.9;
            float distFromCenter = distance(uv, CENTER);
            float newMask = 1.0 - smoothstep(newRadius - 0.1, newRadius + 0.1, distFromCenter);

            // 新图采样
            colorTo = texture(to, uv) * newMask;

            // 混合：前半段主要是旧图粒子，后半段主要是新图
            mixFactor = progress;

            // 新图在粒子之间的空隙逐渐显示
            if (progress < 0.7) {
                colorTo = colorTo * (progress / 0.7);
            }

            break;
        }

        case 27: // 极光流动效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;

            // 极光流动效果
            float time = progress * 5.0;

            // 创建多层极光波
            float wave1 = sin(uvOffset.x * 10.0 + time) * 0.5 + 0.5;
            float wave2 = sin(uvOffset.y * 8.0 - time * 0.7) * 0.5 + 0.5;
            float wave3 = sin((uvOffset.x + uvOffset.y) * 12.0 + time * 1.3) * 0.5 + 0.5;

            // 极光色彩：绿色、紫色、蓝色
            vec3 auroraColor = mix(vec3(0.0, 0.8, 0.5), vec3(0.5, 0.0, 0.8), wave1);
            auroraColor = mix(auroraColor, vec3(0.0, 0.5, 1.0), wave2);
            auroraColor = mix(auroraColor, vec3(0.2, 1.0, 0.8), wave3);

            // 极光流动遮罩
            float auroraMask = (wave1 + wave2 + wave3) / 3.0;
            auroraMask *= smoothstep(0.0, 0.3, progress) * smoothstep(1.0, 0.7, progress);

            // 添加闪烁效果
            float sparkle = sin(time * 20.0 + uv.x * 50.0 + uv.y * 50.0) * 0.5 + 0.5;
            auroraColor += sparkle * 0.2;

            // 混合
            mixFactor = progress;
            colorFrom = texture(from, uv);
            colorTo = texture(to, uv);

            // 在过渡期间添加极光色彩
            vec4 aurora = vec4(auroraColor * auroraMask * 0.6, auroraMask * 0.5);
            colorFrom = mix(colorFrom, aurora, auroraMask * 0.5);
            colorTo = mix(colorTo, aurora, (1.0 - auroraMask) * 0.5);

            break;
        }

        case 28: // 赛博朋克故障效果
        {
            vec2 center = vec2(0.5, 0.5);

            // 故障强度随进度变化
            float glitchIntensity = sin(progress * 3.14159) * 0.02 + 0.005;

            // RGB分离效果
            float rgbOffset = glitchIntensity * 3.0;
            vec4 fromR = texture(from, uv + vec2(rgbOffset, 0.0));
            vec4 fromG = texture(from, uv);
            vec4 fromB = texture(from, uv - vec2(rgbOffset, 0.0));
            vec4 glitchFrom = vec4(fromR.r, fromG.g, fromB.b, fromR.a);

            vec4 toR = texture(to, uv + vec2(rgbOffset, 0.0));
            vec4 toG = texture(to, uv);
            vec4 toB = texture(to, uv - vec2(rgbOffset, 0.0));
            vec4 glitchTo = vec4(toR.r, toG.g, toB.b, toR.a);

            // 扫描线效果
            float scanline = sin(uv.y * 100.0 + progress * 20.0) * 0.5 + 0.5;
            float scanlineMask = mod(uv.y * 50.0, 2.0) < 1.0 ? 0.9 : 1.0;

            // 数字噪点
            float noise = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
            float noiseMask = smoothstep(0.95, 1.0, noise);
            vec2 noiseOffset = noiseMask * (vec2(noise, noise) - 0.5) * 0.1;

            // 随机位移
            float blockGlitch = step(0.97, fract(sin(uv.x * 10.0 + uv.y * 10.0 + progress * 5.0) * 43758.5453));
            vec2 blockOffset = blockGlitch * vec2(0.0, 0.05);

            // 应用所有效果
            mixFactor = progress;
            colorFrom = texture(from, uv + noiseOffset + blockOffset);
            colorTo = texture(to, uv + noiseOffset + blockOffset);

            // RGB分离
            colorFrom = glitchFrom;
            colorTo = glitchTo;

            // 扫描线
            colorFrom.rgb *= scanlineMask;
            colorTo.rgb *= scanlineMask;

            // 添加故障闪烁
            if (noiseMask > 0.5) {
                colorFrom.rgb = mix(colorFrom.rgb, vec3(0.0, 1.0, 1.0), 0.3);
                colorTo.rgb = mix(colorTo.rgb, vec3(1.0, 0.0, 1.0), 0.3);
            }

            break;
        }

        case 29: // 黑洞吞噬效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);
            float angle = atan(uvOffset.y, uvOffset.x);

            // 黑洞吞噬：旧图片被吸入黑洞并扭曲，新图片从黑洞中释放出来
            // 黑洞在progress=0.5时达到最大，然后新图片从黑洞区域开始扩散
            float blackholeRadius = min(progress * 1.0, 0.5);  // 黑洞半径在0.5时达到最大

            // 旧图扭曲效果
            float twistStrength = (1.0 - progress) * 3.14159;  // 扭曲强度
            float twistedAngle = angle + twistStrength * (1.0 - smoothstep(blackholeRadius, blackholeRadius + 0.3, dist));

            // 径向收缩
            float shrinkFactor = smoothstep(blackholeRadius, blackholeRadius + 0.5, dist);
            shrinkFactor = mix(shrinkFactor, 1.0, 1.0 - progress);

            vec2 oldUV = center + shrinkFactor * dist * vec2(cos(twistedAngle), sin(twistedAngle));

            // 黑洞边缘吸积盘效果
            float accretionDisk = smoothstep(blackholeRadius - 0.05, blackholeRadius, dist) *
                                   smoothstep(blackholeRadius + 0.1, blackholeRadius, dist);
            vec3 diskColor = vec3(1.0, 0.5, 0.0) * accretionDisk;

            // 新图：从黑洞区域开始扩散，扭曲逐渐恢复正常
            // 扭曲强度随progress逐渐减小（从最大扭曲到无扭曲）
            float newTwistStrength = (1.0 - progress) * 3.14159;
            float newTwistFactor = smoothstep(blackholeRadius, blackholeRadius + 0.3, dist);
            float newTwistedAngle = angle + newTwistStrength * newTwistFactor;

            // 径向扩张：从黑洞边缘开始，逐渐扩散到全图
            float newShrinkFactor = smoothstep(blackholeRadius - 0.1, blackholeRadius + 0.5, dist);
            newShrinkFactor = mix(newShrinkFactor, 1.0, smoothstep(0.5, 1.0, progress));

            vec2 newUV = center + newShrinkFactor * dist * vec2(cos(newTwistedAngle), sin(newTwistedAngle));

            // 混合
            mixFactor = progress;
            colorFrom = texture(from, oldUV);
            colorTo = texture(to, newUV);

            // 黑洞区域：前半段显示黑色，后半段显示新图片
            if (dist < blackholeRadius) {
                colorFrom = vec4(0.0, 0.0, 0.0, 1.0);
                colorTo = texture(to, uv);  // 黑洞区域显示新图片（正常无扭曲）
            }

            // 添加吸积盘发光
            colorFrom.rgb += diskColor * 0.5;
            colorTo.rgb += diskColor * 0.5;

            break;
        }

        case 30: // 全息投影效果
        {
            vec2 center = vec2(0.5, 0.5);

            // 全息扫描线效果
            float scanPosition = progress;
            float scanWidth = 0.1;
            float scanDistance = distance(uv.y, scanPosition);

            // 扫描线
            float scanline = smoothstep(scanWidth, 0.0, scanDistance);

            // 全息闪烁
            float flicker = sin(uv.x * 100.0 + uv.y * 100.0 + progress * 30.0) * 0.5 + 0.5;
            flicker = mix(flicker, 1.0, 0.7);

            // RGB分离（全息特征）
            float rgbOffset = 0.005;
            vec4 fromR = texture(from, uv + vec2(rgbOffset, 0.0));
            vec4 fromG = texture(from, uv);
            vec4 fromB = texture(from, uv - vec2(rgbOffset, 0.0));
            vec4 hologramFrom = vec4(fromR.r, fromG.g, fromB.b, fromR.a) * flicker;

            vec4 toR = texture(to, uv + vec2(rgbOffset, 0.0));
            vec4 toG = texture(to, uv);
            vec4 toB = texture(to, uv - vec2(rgbOffset, 0.0));
            vec4 hologramTo = vec4(toR.r, toG.g, toB.b, toR.a) * flicker;

            // 全息蓝绿色调
            vec3 hologramTint = vec3(0.0, 0.8, 1.0);
            hologramFrom.rgb = mix(hologramFrom.rgb, hologramTint, 0.3);
            hologramTo.rgb = mix(hologramTo.rgb, hologramTint, 0.3);

            // 水平扫描线网格
            float hGrid = mod(uv.y * 30.0, 1.0) < 0.1 ? 0.7 : 1.0;
            hologramFrom.rgb *= hGrid;
            hologramTo.rgb *= hGrid;

            // 混合
            mixFactor = progress;
            colorFrom = hologramFrom;
            colorTo = hologramTo;

            // 扫描线高亮
            if (scanline > 0.5) {
                colorFrom.rgb += vec3(0.0, 0.5, 1.0) * scanline * 0.5;
                colorTo.rgb += vec3(0.0, 0.5, 1.0) * scanline * 0.5;
            }

            break;
        }

        case 31: // 网格块效果
        {
            // 平滑的进度曲线
            float smoothProgress = smoothstep(0.0, 1.0, progress);
            
            // 俄罗斯方块参数
            float blockSize = 0.08;  // 方块大小
            
            // 计算当前像素所在的方块ID
            vec2 gridUV = uv / blockSize;
            vec2 gridID = floor(gridUV);
            vec2 gridPos = fract(gridUV);
            
            // 为每个方块生成随机性
            float seed = fract(sin(dot(gridID, vec2(12.9898, 78.233))) * 43758.5453);
            
            // 每个方块的下落开始时间（随机）
            float fallStart = seed * 0.7;
            // 每个方块的下落速度（随机）
            float fallSpeed = 0.8 + seed * 1.2;
            
            // 计算方块当前的下落进度
            // progress < fallStart: 方块在初始位置
            // progress >= fallStart: 方块开始下落
            float fallProgress = clamp((smoothProgress - fallStart) * fallSpeed, 0.0, 1.0);
            
            // 方块从当前位置向下掉落
            // 初始位置：gridPos.y
            // 掉落目标：超出屏幕底部（gridPos.y + 1.5）
            float blockY = mix(gridPos.y, gridPos.y + 1.5, fallProgress);
            
            // 检查方块是否已经掉出屏幕
            float dropMask = step(1.0, blockY);
            
            // 采样旧图片和新图片
            vec4 oldColor = texture(from, uv);
            vec4 newColor = texture(to, uv);
            
            // 平滑的混合因子，结合掉落进度和全局进度
            float blockMix = smoothstep(0.8, 1.0, blockY);  // 方块掉出时平滑过渡
            float globalMix = smoothProgress;  // 全局进度
            mixFactor = max(dropMask, blockMix * globalMix);
            
            // 设置采样结果
            colorFrom = oldColor;
            colorTo = newColor;
            
            // 添加方块下落的阴影效果
            if (dropMask < 0.5) {
                // 正在下落的方块，添加动态阴影
                float shadow = 1.0 - fallProgress * 0.4;
                colorFrom.rgb *= shadow;
                
                // 添加方块的下落位移效果
                vec2 fallingUV = uv + vec2(0.0, fallProgress * 0.02);
                colorFrom = texture(from, fallingUV);
            }
            
            // 添加方块边缘效果
            float edge = smoothstep(0.0, 0.02, min(min(gridPos.x, gridPos.y), min(1.0 - gridPos.x, 1.0 - gridPos.y)));
            colorFrom.rgb = mix(colorFrom.rgb, vec3(0.0, 0.0, 0.0), edge * 0.3);
            colorTo.rgb = mix(colorTo.rgb, vec3(0.0, 0.0, 0.0), edge * 0.1);
            
            break;
        }

        case 32: // 液体变形效果
        {
            // 平滑的进度曲线，确保过渡初期和结束时更平滑
            float smoothProgress = smoothstep(0.0, 1.0, progress);
            
            // 中心点
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);
            
            // 生成液体流动的噪声效果
            float noise1 = random(vec2(uv.y * 20.0, smoothProgress * 5.0)) * 0.2;  // 增大噪声振幅
            float noise2 = sin(uv.x * 30.0 + smoothProgress * 10.0) * 0.1;     // 增大噪声振幅
            float noise3 = sin(uv.y * 25.0 - smoothProgress * 8.0) * 0.08;    // 增大噪声振幅
            float totalNoise = noise1 + noise2 + noise3;
            
            // 液体变形参数 - 增大变形幅度（从0.3到0.6）
            float deformation = 0.6 * sin(smoothProgress * 3.14159);
            
            // 计算液体扭曲的UV坐标
            vec2 distortedUV = uv;
            
            // 添加液体流动效果
            vec2 flowDirection = vec2(
                cos(smoothProgress * 3.14159),
                sin(smoothProgress * 3.14159)
            );
            
            // 距离中心越近，变形越明显
            float deformationFalloff = 1.0 - smoothstep(0.0, 0.8, dist);  // 增大影响范围（从0.6到0.8）
            
            // 应用液体变形 - 增大变形幅度
            distortedUV += flowDirection * totalNoise * deformationFalloff * 0.3;  // 从0.1到0.3
            distortedUV += normalize(uvOffset) * deformation * deformationFalloff * 0.5;  // 从0.2到0.5
            
            // 确保UV坐标在有效范围内
            distortedUV = clamp(distortedUV, vec2(0.0), vec2(1.0));
            
            // 采样旧图片和新图片
            vec4 oldColor = texture(from, distortedUV);
            vec4 newColor = texture(to, distortedUV);
            
            // 平滑的混合因子，确保旧图片和新图片逐渐过渡
            mixFactor = smoothProgress;
            
            // 设置采样结果
            colorFrom = oldColor;
            colorTo = newColor;
            
            // 添加液体光泽效果
            float gloss = smoothstep(0.2, 0.0, dist) * 0.3;
            colorFrom.rgb += vec3(1.0, 1.0, 1.0) * gloss;
            colorTo.rgb += vec3(1.0, 1.0, 1.0) * gloss;
            
            break;
        }

        case 33: // 像素化效果
        {
            float pixelSize;

            if (progress < 0.5) {
                // 前半段：旧图逐渐像素化
                float t = progress * 2.0;
                pixelSize = mix(0.002, 0.05, t);

                vec2 pixelUV = floor(uv / pixelSize) * pixelSize + pixelSize * 0.5;
                colorFrom = texture(from, pixelUV);
                colorTo = colorFrom;
                mixFactor = 0.0;
            } else {
                // 后半段：新图从像素逐渐清晰
                float t = (progress - 0.5) * 2.0;
                pixelSize = mix(0.05, 0.002, t);

                vec2 pixelUV = floor(uv / pixelSize) * pixelSize + pixelSize * 0.5;
                colorFrom = texture(to, pixelUV);
                colorTo = colorFrom;
                mixFactor = 1.0;
            }

            break;
        }

        case 34: // 纸张撕裂效果
        {
            // 平滑的进度曲线，确保过渡初期和结束时更平滑
            float smoothProgress = smoothstep(0.0, 1.0, progress);
            
            // 生成更自然的撕裂曲线
            // 使用多层噪声生成复杂的撕裂形状
            float tearCurve = uv.y * 2.0;
            tearCurve += sin(uv.y * 10.0) * 0.1;
            tearCurve += sin(uv.y * 20.0 + progress * 5.0) * 0.05;
            tearCurve += random(vec2(uv.y * 5.0, progress)) * 0.1;
            
            // 撕裂线位置随进度变化
            float tearLine = 0.5 + tearCurve * (smoothProgress - 0.5) * 2.0;
            
            // 计算撕裂边缘的破碎效果
            float tearEdgeWidth = 0.05;
            float distanceToTear = abs(uv.x - tearLine);
            
            // 撕裂破碎效果：距离撕裂线越近，破碎越严重
            float tearStrength = smoothstep(0.0, tearEdgeWidth, distanceToTear);
            
            // 生成撕裂碎片的UV偏移
            vec2 tearOffset = vec2(0.0);
            
            // 左半部分向左撕裂
            if (uv.x < tearLine) {
                // 生成随机的碎片偏移
                float fragmentOffset = random(vec2(uv.y * 10.0, floor(uv.y * 50.0))) * 0.1 - 0.05;
                tearOffset = vec2(-smoothProgress * 0.2 + fragmentOffset * tearStrength, 0.0);
                
                // 采样旧图片
                colorFrom = texture(from, uv + tearOffset);
                colorTo = texture(to, uv);
                mixFactor = smoothProgress;
            } else {
                // 右半部分向右撕裂
                // 生成随机的碎片偏移
                float fragmentOffset = random(vec2(uv.y * 10.0, floor(uv.y * 50.0))) * 0.1 - 0.05;
                tearOffset = vec2(smoothProgress * 0.2 + fragmentOffset * tearStrength, 0.0);
                
                // 采样新图片
                colorFrom = texture(from, uv);
                colorTo = texture(to, uv + tearOffset);
                mixFactor = smoothProgress;
            }
            
            // 添加撕裂边缘的高光效果
            float highlight = smoothstep(0.005, 0.02, distanceToTear) * smoothstep(0.03, 0.01, distanceToTear);
            colorFrom.rgb += vec3(1.0, 1.0, 1.0) * highlight * 0.5;
            colorTo.rgb += vec3(1.0, 1.0, 1.0) * highlight * 0.5;
            
            // 添加撕裂边缘的阴影效果
            float shadow = smoothstep(0.01, 0.03, distanceToTear) * smoothstep(0.05, 0.02, distanceToTear);
            colorFrom.rgb *= (1.0 - shadow * 0.3);
            colorTo.rgb *= (1.0 - shadow * 0.3);
            
            break;
        }

        case 35: // 磁性吸附效果
        {
            // 磁铁位置（固定点，可调整）
            vec2 magnetPos = vec2(0.8, 0.2);
            
            // 计算当前UV到磁铁的向量和距离
            vec2 toMagnet = magnetPos - uv;
            float magnetDist = length(toMagnet);
            
            if (progress < 0.5) {
                // 前半段：旧图片在磁铁位置向外鼓出，然后淡出
                float t = progress * 2.0;  // 0.0 到 1.0
                
                // 鼓出强度：距离磁铁越近，鼓出越明显
                float bulgeStrength = t * 1.0;
                float falloff = smoothstep(0.0, 1.0, 1.0 - magnetDist);
                
                // 缩放：以磁铁位置为中心向外鼓出（最大鼓出到2.5倍）
                float scaleFactor = 1.0 + bulgeStrength * falloff * 1.5;
                vec2 distortedUV = magnetPos + (uv - magnetPos) * scaleFactor;
                
                // mixFactor=0显示colorFrom，mixFactor=1显示colorTo
                // 旧图片要淡出：mixFactor从0渐变到1
                colorFrom = texture(from, distortedUV);
                colorTo = vec4(0.0, 0.0, 0.0, 0.0);
                mixFactor = t;
            } else {
                // 后半段：新图片从鼓出的状态收缩回平面，然后淡入
                float t = (progress - 0.5) * 2.0;  // 0.0 到 1.0
                
                // 收缩强度：距离磁铁越近，收缩越明显
                float falloff = smoothstep(0.0, 1.0, 1.0 - magnetDist);
                
                // 缩放：从鼓出的状态收缩回平面
                float bulgeStart = 2.5;
                float scaleFactor = mix(bulgeStart, 1.0, t);
                scaleFactor = 1.0 + (scaleFactor - 1.0) * falloff;
                
                vec2 distortedUV = magnetPos + (uv - magnetPos) * scaleFactor;
                
                // mixFactor=0显示colorFrom，mixFactor=1显示colorTo
                // 新图片要淡入：mixFactor从0渐变到1
                colorFrom = vec4(0.0, 0.0, 0.0, 0.0);
                colorTo = texture(to, distortedUV);
                mixFactor = t;
            }

            break;
        }

        case 36: // 玻璃破碎效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);
            float angle = atan(uvOffset.y, uvOffset.x);

            // 破碎参数
            float numShards = 16.0;
            float shardAngle = 6.28318 / numShards;
            int shardIndex = int(mod(angle + 3.14159, 6.28318) / shardAngle);

            // 随机偏移
            float seed = fract(sin(float(shardIndex) * 12.9898) * 43758.5453);
            vec2 shardDir = vec2(cos(float(shardIndex) * shardAngle), sin(float(shardIndex) * shardAngle));

            if (progress < 0.5) {
                // 前半段：玻璃破碎散落
                float t = progress * 2.0;
                float fallDistance = t * 0.5 * (seed + 0.5);

                vec2 shatteredUV = uv + shardDir * fallDistance;
                colorFrom = texture(from, shatteredUV);
                colorTo = colorFrom;
                mixFactor = 0.0;
            } else {
                // 后半段：新图从裂缝中显现
                float t = (progress - 0.5) * 2.0;
                vec2 shatteredUV = uv - shardDir * (1.0 - t) * 0.5 * (seed + 0.5);

                colorFrom = texture(to, shatteredUV);
                colorTo = colorFrom;
                mixFactor = 1.0;
            }

            // 添加玻璃反光效果
            float glare = sin(angle * 4.0 + progress * 10.0) * 0.5 + 0.5;
            colorFrom.rgb += vec3(1.0, 1.0, 1.0) * glare * 0.1;
            colorTo.rgb += vec3(1.0, 1.0, 1.0) * glare * 0.1;

            break;
        }

        case 37: // 电影卷轴效果
        {
            float rollSpeed = progress;
            float rollWidth = 0.15;

            // 计算卷轴位置（从上往下）
            float rollTop = rollSpeed;
            float rollBottom = rollSpeed + rollWidth;

            // 卷轴弯曲效果
            float curve = smoothstep(rollTop, rollTop + 0.02, uv.y) *
                         (1.0 - smoothstep(rollBottom - 0.02, rollBottom, uv.y));

            vec2 rollUV = uv;
            if (uv.y > rollTop && uv.y < rollBottom) {
                // 卷轴区域，应用弯曲
                rollUV.y -= sin((uv.y - rollTop) / rollWidth * 3.14159) * 0.02 * curve;
            }

            if (uv.y < rollTop) {
                // 卷轴上方，显示新图
                colorFrom = texture(to, uv);
                colorTo = colorFrom;
                mixFactor = 1.0;
            } else {
                // 卷轴下方，显示旧图
                colorFrom = texture(from, rollUV);
                colorTo = colorFrom;
                mixFactor = 0.0;
            }

            // 添加卷轴阴影
            if (uv.y > rollTop && uv.y < rollBottom) {
                float shadow = smoothstep(rollTop, rollTop + 0.01, uv.y) *
                             (1.0 - smoothstep(rollBottom - 0.01, rollBottom, uv.y));
                colorFrom.rgb *= (1.0 - shadow * 0.5);
                colorTo.rgb *= (1.0 - shadow * 0.5);
            }

            break;
        }

        case 38: // DNA双螺旋效果
        {
            vec2 center = vec2(0.5, 0.5);
            
            // DNA双螺旋参数 - 调整为更松散的螺旋
            float helixRadius = 0.3;     // 更大的螺旋半径，使螺旋更松散
            float helixTurns = 6.0;      // 更少的螺旋圈数，减少螺旋密度
            float helixSpeed = 1.2;      // 适当的螺旋旋转速度
            
            // 计算螺旋角度（基于Y坐标和进度）
            float angle = (uv.y - 0.5) * helixTurns * 6.28318 + progress * helixSpeed * 6.28318;
            
            // 计算螺旋的径向位置（极坐标转换）
            float radius = distance(uv.x, center.x);
            float normalizedRadius = radius / helixRadius;
            
            // 计算当前点在螺旋结构中的位置参数 - 调整为更松散的螺旋
            float spiralPosition = angle + normalizedRadius * 1.5; // 降低径向影响，使螺旋更松散
            
            // 创建螺旋过渡掩码 - 只保留图片的螺旋过渡效果
            float transitionWidth = 0.25; // 增加过渡带宽度，使过渡更平滑
            float transitionMask = fract(spiralPosition / 6.28318 + progress * 0.4); // 调整进度影响，使过渡更自然
            
            // 基于螺旋位置计算混合因子
            // 旧图片在螺旋的"波谷"先消失，新图片在螺旋的"波峰"先显现
            float spiralBlend = smoothstep(0.0, transitionWidth, transitionMask) - 
                               smoothstep(1.0 - transitionWidth, 1.0, transitionMask);
            
            // 结合进度控制，确保整体过渡流畅
            float progressBlend = smoothstep(0.0, 1.0, progress);
            mixFactor = progressBlend + (spiralBlend - 0.5) * 0.6; // 降低螺旋混合强度，使过渡更自然
            mixFactor = clamp(mixFactor, 0.0, 1.0);
            
            // 为图片添加螺旋扭曲效果 - 更轻微的扭曲
            vec2 twistedUVFrom = uv;
            vec2 twistedUVTo = uv;
            
            // 计算扭曲强度，随进度变化，更轻微的扭曲
            float twistIntensity = sin(progress * 3.14159) * 0.12; // 降低扭曲强度
            
            // 旧图片向外扭曲，新图片向内扭曲 - 更自然的扭曲效果
            twistedUVFrom.x += twistIntensity * cos(angle * 1.5 + uv.y * 15.0); // 降低频率，使扭曲更松散
            twistedUVFrom.y += twistIntensity * sin(angle * 1.0 + uv.x * 10.0);
            
            twistedUVTo.x -= twistIntensity * cos(angle * 1.5 + uv.y * 15.0);
            twistedUVTo.y -= twistIntensity * sin(angle * 1.0 + uv.x * 10.0);
            
            // 采样扭曲后的图像
            colorFrom = texture(from, twistedUVFrom);
            colorTo = texture(to, twistedUVTo);

            break;
        }

        case 39: // 极坐标映射效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);
            float angle = atan(uvOffset.y, uvOffset.x);

            if (progress < 0.5) {
                // 前半段：旧图转换为极坐标
                float t = progress * 2.0;
                float r = mix(dist, 0.5, t);
                float theta = mix(angle, angle + t * 6.28318, t);

                vec2 polarUV = center + r * vec2(cos(theta), sin(theta));
                colorFrom = texture(from, polarUV);
                colorTo = colorFrom;
                mixFactor = 0.0;
            } else {
                // 后半段：新图从极坐标展开
                float t = (progress - 0.5) * 2.0;
                float r = mix(0.5, dist, t);
                float theta = mix(angle + (1.0 - t) * 6.28318, angle, t);

                vec2 polarUV = center + r * vec2(cos(theta), sin(theta));
                colorFrom = texture(to, polarUV);
                colorTo = colorFrom;
                mixFactor = 1.0;
            }

            break;
        }

        case 40: // 横向幕布效果
        {
            // 幕布角度：0到90度（π/2）
            float curtainAngle = progress * 1.5708;

            // 判断当前像素在左幕布还是右幕布区域
            bool isLeftCurtain = (uv.x < 0.5);
            bool isRightCurtain = (uv.x >= 0.5);

            if (isLeftCurtain) {
                // 左幕布：从左侧向中间闭合，旧图被拉伸
                // 将UV坐标转换到幕布的局部坐标系
                float localX = (0.5 - uv.x) * 2.0;  // [0, 1] (从铰链向外)

                // 3D透视：随角度变化，幕布的可见宽度
                float curtainVisibility = cos(curtainAngle);

                // 计算采样位置（透视映射）
                float sampleX = 0.5 - localX * 0.5 * curtainVisibility;

                // 检查像素是否在可见范围内
                if (uv.x >= 0.5 - 0.5 * curtainVisibility) {
                    // 显示幕布的旧图（被拉伸）
                    vec2 sampleUV = vec2(sampleX, uv.y);
                    colorFrom = texture(from, sampleUV);
                    colorTo = colorFrom;
                    mixFactor = 0.0;

                    // 透视光影：幕布越闭合越暗
                    float lightFactor = 0.7 + 0.3 * curtainVisibility;
                    colorFrom.rgb *= lightFactor;
                    colorTo.rgb *= lightFactor;
                } else {
                    // 幕布外区域，显示新图
                    colorFrom = texture(to, uv);
                    colorTo = colorFrom;
                    mixFactor = 1.0;
                }

            } else if (isRightCurtain) {
                // 右幕布：从右侧向中间闭合，旧图被拉伸
                // 将UV坐标转换到幕布的局部坐标系
                float localX = (uv.x - 0.5) * 2.0;  // [0, 1] (从铰链向外)

                // 3D透视：随角度变化，幕布的可见宽度
                float curtainVisibility = cos(curtainAngle);

                // 计算采样位置（透视映射）
                float sampleX = 0.5 + localX * 0.5 * curtainVisibility;

                // 检查像素是否在可见范围内
                if (uv.x <= 0.5 + 0.5 * curtainVisibility) {
                    // 显示幕布的旧图（被拉伸）
                    vec2 sampleUV = vec2(sampleX, uv.y);
                    colorFrom = texture(from, sampleUV);
                    colorTo = colorFrom;
                    mixFactor = 0.0;

                    // 透视光影：幕布越闭合越暗
                    float lightFactor = 0.7 + 0.3 * curtainVisibility;
                    colorFrom.rgb *= lightFactor;
                    colorTo.rgb *= lightFactor;
                } else {
                    // 幕布外区域，显示新图
                    colorFrom = texture(to, uv);
                    colorTo = colorFrom;
                    mixFactor = 1.0;
                }
            }

            break;
        }

        case 41: // 纵向幕布效果
        {
            // 幕布角度：0到90度（π/2）
            float curtainAngle = progress * 1.5708;

            // 判断当前像素在上幕布还是下幕布区域
            bool isTopCurtain = (uv.y < 0.5);
            bool isBottomCurtain = (uv.y >= 0.5);

            if (isTopCurtain) {
                // 上幕布：从上侧向中间闭合，旧图被拉伸
                // 将UV坐标转换到幕布的局部坐标系
                float localY = (0.5 - uv.y) * 2.0;  // [0, 1] (从铰链向外)

                // 3D透视：随角度变化，幕布的可见高度
                float curtainVisibility = cos(curtainAngle);

                // 计算采样位置（透视映射）
                float sampleY = 0.5 - localY * 0.5 * curtainVisibility;

                // 检查像素是否在可见范围内
                if (uv.y >= 0.5 - 0.5 * curtainVisibility) {
                    // 显示幕布的旧图（被拉伸）
                    vec2 sampleUV = vec2(uv.x, sampleY);
                    colorFrom = texture(from, sampleUV);
                    colorTo = colorFrom;
                    mixFactor = 0.0;

                    // 透视光影：幕布越闭合越暗
                    float lightFactor = 0.7 + 0.3 * curtainVisibility;
                    colorFrom.rgb *= lightFactor;
                    colorTo.rgb *= lightFactor;
                } else {
                    // 幕布外区域，显示新图
                    colorFrom = texture(to, uv);
                    colorTo = colorFrom;
                    mixFactor = 1.0;
                }

            } else if (isBottomCurtain) {
                // 下幕布：从下侧向中间闭合，旧图被拉伸
                // 将UV坐标转换到幕布的局部坐标系
                float localY = (uv.y - 0.5) * 2.0;  // [0, 1] (从铰链向外)

                // 3D透视：随角度变化，幕布的可见高度
                float curtainVisibility = cos(curtainAngle);

                // 计算采样位置（透视映射）
                float sampleY = 0.5 + localY * 0.5 * curtainVisibility;

                // 检查像素是否在可见范围内
                if (uv.y <= 0.5 + 0.5 * curtainVisibility) {
                    // 显示幕布的旧图（被拉伸）
                    vec2 sampleUV = vec2(uv.x, sampleY);
                    colorFrom = texture(from, sampleUV);
                    colorTo = colorFrom;
                    mixFactor = 0.0;

                    // 透视光影：幕布越闭合越暗
                    float lightFactor = 0.7 + 0.3 * curtainVisibility;
                    colorFrom.rgb *= lightFactor;
                    colorTo.rgb *= lightFactor;
                } else {
                    // 幕布外区域，显示新图
                    colorFrom = texture(to, uv);
                    colorTo = colorFrom;
                    mixFactor = 1.0;
                }
            }

            break;
        }

        case 42: // 霓虹灯效果
        {
            // 平滑的进度曲线，确保过渡初期和结束时更平滑
            float smoothProgress = smoothstep(0.0, 1.0, progress);
            
            // 彩色条纹参数
            float stripeWidth = 0.15;  // 条纹宽度
            float glowWidth = 0.05;    // 光晕宽度
            
            // 彩条位置：从屏幕左侧外（-stripeWidth）开始，到屏幕右侧（1.0）结束
            // 进度为0时，彩条在屏幕左侧外
            // 进度为1时，彩条在屏幕右侧
            float stripePos = -stripeWidth + smoothProgress * (1.0 + stripeWidth);
            
            // 计算过渡区域的范围：
            // - 左侧边缘：stripePos - glowWidth
            // - 右侧边缘：stripePos + glowWidth
            // - 彩条中心：stripePos
            
            // 混合因子计算：
            // 彩条从左向右滑动，滑过的地方显示新图片
            // - 当 uv.x < stripePos 时：显示新图片（mixFactor = 1，彩条已滑过）
            // - 当 uv.x > stripePos + stripeWidth 时：显示旧图片（mixFactor = 0，彩条未滑过）
            // - 当 stripePos < uv.x < stripePos + stripeWidth 时：平滑过渡
            float transitionStart = stripePos;
            float transitionEnd = stripePos + stripeWidth;
            
            // 使用 1.0 - smoothstep() 实现正确的过渡逻辑
            // 这样彩条滑过的区域（uv.x < stripePos）显示新图片
            mixFactor = 1.0 - smoothstep(transitionStart, transitionEnd, uv.x);
            mixFactor = clamp(mixFactor, 0.0, 1.0);
            
            // 生成彩虹色条纹
            float hue = uv.y + smoothProgress * 0.5;
            hue = fract(hue); // 确保hue在0-1之间
            
            // HSL到RGB转换
            vec3 neonColor;
            if (hue < 1.0/6.0) {
                neonColor = vec3(1.0, hue * 6.0, 0.0);
            } else if (hue < 2.0/6.0) {
                neonColor = vec3((2.0/6.0 - hue) * 6.0, 1.0, 0.0);
            } else if (hue < 3.0/6.0) {
                neonColor = vec3(0.0, 1.0, (hue - 2.0/6.0) * 6.0);
            } else if (hue < 4.0/6.0) {
                neonColor = vec3(0.0, (4.0/6.0 - hue) * 6.0, 1.0);
            } else if (hue < 5.0/6.0) {
                neonColor = vec3((hue - 4.0/6.0) * 6.0, 0.0, 1.0);
            } else {
                neonColor = vec3(1.0, 0.0, (1.0 - hue) * 6.0);
            }
            
            // 采样旧图片和新图片
            vec4 oldColor = texture(from, uv);
            vec4 newColor = texture(to, uv);
            
            // 设置采样结果
            colorFrom = oldColor;
            colorTo = newColor;
            
            // 计算彩条和光晕的掩码
            float distToStripe = abs(uv.x - stripePos);
            float stripeMask = smoothstep(stripeWidth + glowWidth, stripeWidth, distToStripe);
            float glowMask = smoothstep(stripeWidth, 0.0, distToStripe) - 
                           smoothstep(stripeWidth + glowWidth, stripeWidth, distToStripe);
            
            // 给彩条和光晕添加颜色
            vec3 stripeGlow = neonColor * (stripeMask + glowMask * 0.5) * 0.8;
            
            // 在彩条区域添加霓虹效果
            colorFrom.rgb += stripeGlow * (1.0 - mixFactor);
            colorTo.rgb += stripeGlow * mixFactor;
            
            break;
        }

        case 43: // 传送门效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);
            float angle = atan(uvOffset.y, uvOffset.x);

            // 传送门参数
            float maxPortalRadius = 0.8;
            float currentPortalRadius = progress * maxPortalRadius;

            // 传送门边缘发光效果
            float portalEdgeWidth = 0.05;
            float portalEdge = smoothstep(currentPortalRadius - portalEdgeWidth, currentPortalRadius, dist) *
                              (1.0 - smoothstep(currentPortalRadius, currentPortalRadius + portalEdgeWidth, dist));

            // 传送门旋转
            float portalRotate = progress * 6.28318 * 2.0;  // 旋转两圈

            if (dist < currentPortalRadius) {
                // 传送门内：显示新图
                vec2 portalUV = uv;

                // 传送门内的螺旋扭曲效果
                float spiralAngle = angle - portalRotate;
                float spiralDist = dist / currentPortalRadius;  // 归一化距离
                vec2 spiralUV = center + spiralDist * vec2(cos(spiralAngle), sin(spiralAngle)) * currentPortalRadius;

                // 混合正常UV和螺旋UV
                float spiralMix = 1.0 - smoothstep(0.0, 0.3, progress);
                portalUV = mix(spiralUV, uv, spiralMix);

                colorFrom = texture(to, portalUV);
                colorTo = colorFrom;
                mixFactor = 1.0;
            } else {
                // 传送门外：显示旧图
                vec2 outsideUV = uv;

                // 旧图的螺旋扭曲吸入效果
                float suction = progress * 0.5;
                float spiralAngle = angle + portalRotate;
                float suctionDist = dist - suction * (dist - currentPortalRadius) / (1.0 - currentPortalRadius);
                suctionDist = max(suctionDist, currentPortalRadius);

                vec2 spiralUV = center + suctionDist * vec2(cos(spiralAngle), sin(spiralAngle));

                // 混合正常UV和螺旋UV
                float spiralMix = smoothstep(0.0, 0.3, progress);
                outsideUV = mix(uv, spiralUV, spiralMix);

                colorFrom = texture(from, outsideUV);
                colorTo = colorFrom;
                mixFactor = 0.0;
            }

            // 传送门边缘发光
            vec3 portalColor = vec3(0.0, 0.5, 1.0);
            colorFrom.rgb += portalColor * portalEdge * 0.8;
            colorTo.rgb += portalColor * portalEdge * 0.8;

            break;
        }

        case 44: // 粒子重组效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);

            // 粒子参数
            float particleSize = 0.015;
            float particleGridSize = 40.0;

            // 粒子网格
            vec2 gridUV = uv * particleGridSize;
            vec2 gridID = floor(gridUV);
            vec2 gridPos = fract(gridUV);

            // 为每个粒子生成随机性
            float seed = fract(sin(dot(gridID, vec2(12.9898, 78.233))) * 43758.5453);
            vec2 targetOffset = (vec2(random(vec2(seed, 0.0)), random(vec2(seed + 0.5, 0.0))) - 0.5) * 2.0;

            if (progress < 0.5) {
                // 前半段：旧图分解成粒子
                float t = progress * 2.0;
                vec2 particleUV = uv + targetOffset * t * 0.5;

                // 粒子形状
                float particleMask = smoothstep(0.5, 0.2, length(gridPos - 0.5));

                vec4 oldColor = texture(from, particleUV);
                colorFrom = oldColor * particleMask;
                colorTo = vec4(0.0, 0.0, 0.0, 0.0);
                mixFactor = 0.0;
            } else {
                // 后半段：粒子重组成新图
                float t = (progress - 0.5) * 2.0;
                vec2 particleUV = uv - targetOffset * (1.0 - t) * 0.5;

                // 粒子形状
                float particleMask = smoothstep(0.5, 0.2, length(gridPos - 0.5));

                vec4 newColor = texture(to, particleUV);
                colorFrom = newColor * particleMask;
                colorTo = newColor * particleMask;
                mixFactor = 1.0;
            }

            // 添加粒子发光
            if (progress > 0.2 && progress < 0.8) {
                float glow = sin(progress * 6.28318) * 0.5 + 0.5;
                colorFrom.rgb += vec3(0.5, 0.8, 1.0) * glow * 0.2;
                colorTo.rgb += vec3(0.5, 0.8, 1.0) * glow * 0.2;
            }

            break;
        }

        case 45: // 黑白颜色过渡效果
        {
            // 计算灰度值：0.299*R + 0.587*G + 0.114*B（人眼感知权重）
            float grayFrom = dot(colorFrom.rgb, vec3(0.299, 0.587, 0.114));
            float grayTo = dot(colorTo.rgb, vec3(0.299, 0.587, 0.114));

            // 前半段（0-0.5）：旧图逐渐变黑白，新图逐渐显示（保持黑白）
            // 后半段（0.5-1.0）：新图从黑白逐渐恢复彩色

            // 新旧图混合比例：持续平滑从0到1
            mixFactor = progress;

            if (progress < 0.5) {
                // 前半段：旧图变黑白，新图保持黑白
                float t = progress * 2.0;  // 0到1
                vec3 oldColor = mix(colorFrom.rgb, vec3(grayFrom), t);
                vec3 newColor = vec3(grayTo);

                colorFrom.rgb = oldColor;
                colorTo.rgb = newColor;
            } else {
                // 后半段：新图从黑白恢复彩色
                float t = (progress - 0.5) * 2.0;  // 0到1
                vec3 oldColor = vec3(grayFrom);
                vec3 newColor = mix(vec3(grayTo), colorTo.rgb, t);

                colorFrom.rgb = oldColor;
                colorTo.rgb = newColor;
            }

            break;
        }

        case 46: // 球体映射效果
        {
            // 将图片映射到3D球体上旋转切换
            vec2 center = vec2(0.5, 0.5);
            vec2 delta = uv - center;

            // 计算到中心的距离
            float dist = length(delta);

            // 球体半径
            float radius = 0.4;

            // 旋转角度：整个过渡过程旋转360度
            float totalRotation = progress * 6.28318;

            // 3D球体映射算法
            // 将2D UV坐标映射到球体表面，再投影回2D

            // 计算球体坐标（3D到2D的投影）
            // 使用球面投影：x = r * sin(theta) * cos(phi), y = r * sin(theta) * sin(phi)
            // 其中 theta 是极角，phi 是方位角

            float maxDist = 0.35;  // 球体最大半径
            float sphereMask = smoothstep(maxDist, maxDist * 0.8, dist);  // 球体内部mask
            sphereMask = clamp(sphereMask, 0.0, 1.0);

            // 计算球体表面的点
            // 对于球体内的像素，计算其在球体表面的投影
            vec2 sphereUV;
            if (dist < maxDist * 1.1) {
                // 球体区域：使用球体投影
                float normalizedDist = dist / maxDist;
                // 使用抛物线计算球体表面高度
                float sphereHeight = sqrt(1.0 - normalizedDist * normalizedDist);

                // 计算球体表面的2D投影坐标
                // 球体边缘向中心收缩
                float projectedDist = dist * sphereHeight * 1.2;

                // 计算角度
                float angle = atan(delta.y, delta.x);

                // 基础球体坐标
                vec2 baseSphereUV = center + vec2(cos(angle), sin(angle)) * projectedDist;

                // 旋转后的球体坐标
                vec2 rotatedAngle = vec2(
                    cos(angle + totalRotation),
                    sin(angle + totalRotation)
                );
                vec2 rotatedSphereUV = center + rotatedAngle * projectedDist;

                sphereUV = rotatedSphereUV;
            } else {
                // 球体外部：使用原始坐标
                sphereUV = uv;
            }

            // 阶段控制：
            // 阶段1（progress 0-0.33）：旧图从平面逐渐变成球体
            // 阶段2（progress 0.33-0.67）：球体旋转，从旧图过渡到新图
            // 阶段3（progress 0.67-1.0）：新图从球体逐渐变成平面

            vec2 fromUV;
            vec2 toUV;
            float fromSphere = 0.0;
            float toSphere = 0.0;

            if (progress < 0.33) {
                // 阶段1：旧图从平面变成球体
                float phase1Progress = progress / 0.33;
                float easePhase1 = phase1Progress * phase1Progress * (3.0 - 2.0 * phase1Progress);

                // 计算未旋转的球体坐标
                float angle = atan(delta.y, delta.x);
                float normalizedDist = clamp(dist / maxDist, 0.0, 1.0);
                float sphereHeight = sqrt(1.0 - normalizedDist * normalizedDist);
                float projectedDist = dist * sphereHeight * 1.2;
                vec2 unrotatedSphereUV = center + vec2(cos(angle), sin(angle)) * projectedDist;

                // 从平面坐标过渡到球体坐标
                fromUV = mix(uv, unrotatedSphereUV, easePhase1 * sphereMask);
                toUV = uv;

                fromSphere = easePhase1 * sphereMask;

                // 采样
                colorFrom = texture(from, clamp(fromUV, 0.0, 1.0));
                colorTo = vec4(0.0);
                mixFactor = 0.0;
            } else if (progress < 0.67) {
                // 阶段2：球体旋转，从旧图过渡到新图
                float phase2Progress = (progress - 0.33) / 0.34;
                float easePhase2 = phase2Progress * phase2Progress * (3.0 - 2.0 * phase2Progress);

                // 计算旋转前后的球体坐标
                float angle = atan(delta.y, delta.x);
                float normalizedDist = clamp(dist / maxDist, 0.0, 1.0);
                float sphereHeight = sqrt(1.0 - normalizedDist * normalizedDist);
                float projectedDist = dist * sphereHeight * 1.2;

                vec2 startSphereUV = center + vec2(cos(angle), sin(angle)) * projectedDist;
                vec2 endSphereUV = center + vec2(cos(angle + totalRotation), sin(angle + totalRotation)) * projectedDist;

                fromUV = startSphereUV * sphereMask + uv * (1.0 - sphereMask);
                toUV = endSphereUV * sphereMask + uv * (1.0 - sphereMask);

                // 采样
                vec4 fromColor = texture(from, clamp(fromUV, 0.0, 1.0));
                vec4 toColor = texture(to, clamp(toUV, 0.0, 1.0));

                // 混合
                colorFrom = fromColor * (1.0 - easePhase2);
                colorTo = toColor * easePhase2;
                mixFactor = easePhase2;
            } else {
                // 阶段3：新图从球体变成平面
                float phase3Progress = (progress - 0.67) / 0.33;
                float easePhase3 = phase3Progress * phase3Progress * (3.0 - 2.0 * phase3Progress);

                // 计算旋转后的球体坐标
                float angle = atan(delta.y, delta.x);
                float normalizedDist = clamp(dist / maxDist, 0.0, 1.0);
                float sphereHeight = sqrt(1.0 - normalizedDist * normalizedDist);
                float projectedDist = dist * sphereHeight * 1.2;
                vec2 rotatedSphereUV = center + vec2(cos(angle + totalRotation), sin(angle + totalRotation)) * projectedDist;

                // 从球体坐标过渡到平面坐标
                toUV = mix(rotatedSphereUV, uv, easePhase3);
                fromUV = uv;

                toSphere = (1.0 - easePhase3) * sphereMask;

                // 采样
                colorFrom = vec4(0.0);
                colorTo = texture(to, clamp(toUV, 0.0, 1.0));
                mixFactor = 1.0;
            }

            // 添加球体边缘光效和阴影
            float edgeGlow = smoothstep(0.25, 0.3, dist) * (1.0 - smoothstep(0.3, 0.35, dist));
            float glowIntensity = 1.0 - abs(progress - 0.5) * 2.0;
            if (edgeGlow > 0.05) {
                vec3 glowColor = vec3(0.3, 0.6, 1.0) * edgeGlow * glowIntensity * 0.5;
                colorFrom.rgb += glowColor;
                colorTo.rgb += glowColor;
            }

            // 添加球体内部阴影效果
            float shadow = 1.0 - smoothstep(0.0, 0.3, dist);
            shadow *= (fromSphere + toSphere);
            if (shadow > 0.05) {
                colorFrom.rgb *= (1.0 - shadow * 0.1);
                colorTo.rgb *= (1.0 - shadow * 0.1);
            }

            break;
        }

        case 47: // 棱镜折射效果
        {
            // 类似透过棱镜看到的效果，色彩分离
            vec2 center = vec2(0.5, 0.5);
            vec2 delta = uv - center;
            float dist = length(delta);
            
            // 创建三角形棱镜形状
            float angle = atan(delta.y, delta.x);
            float prismAngle = angle + progress * 6.28318;  // 旋转棱镜
            
            // 创建6个三角形棱镜面
            float prismMask = 0.0;
            for (int i = 0; i < 6; i++) {
                float sectorAngle = prismAngle + float(i) * 1.0472;  // 60度
                float angleDiff = mod(abs(angle - sectorAngle), 6.28318);
                if (angleDiff > 3.14159) angleDiff = 6.28318 - angleDiff;
                
                // 在扇形区域内
                if (angleDiff < 0.5 && dist < 0.5) {
                    prismMask = 1.0;
                    break;
                }
            }
            
            // 色彩分离：对RGB通道分别应用不同的偏移
            float refractStrength = 0.03 * prismMask * (1.0 - abs(progress - 0.5) * 2.0);
            
            vec2 uvR = uv + vec2(refractStrength, 0.0);
            vec2 uvG = uv + vec2(-refractStrength * 0.5, refractStrength * 0.5);
            vec2 uvB = uv + vec2(0.0, -refractStrength);
            
            // 采样旧图的RGB分离版本
            vec4 fromR = texture(from, uvR);
            vec4 fromG = texture(from, uvG);
            vec4 fromB = texture(from, uvB);
            
            vec4 toR = texture(to, uvR);
            vec4 toG = texture(to, uvG);
            vec4 toB = texture(to, uvB);
            
            // 根据棱镜区域和进度混合
            if (prismMask > 0.5) {
                float refractMix = smoothstep(0.3, 0.7, dist);
                mixFactor = progress;
                
                colorFrom = vec4(fromR.r, fromG.g, fromB.b, fromR.a);
                colorTo = vec4(toR.r, toG.g, toB.b, toR.a);
            }
            break;
        }

        case 48: // 螺旋变形效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 delta = uv - center;
            
            float dist = length(delta);
            float angle = atan(delta.y, delta.x);
            
            // 变形强度：从0增长到1再降到0，保证开始和结束都是原始图片
            float deform = 1.0 - abs(progress - 0.5) * 2.0;
            // 平滑缓动
            deform = deform * deform * (3.0 - 2.0 * deform);
            
            // 总旋转：持续旋转，不倒退
            float totalRotation = progress * 4.0 * 3.14159;
            
            // 螺旋扭曲
            float twistAngle = angle + dist * 8.0 * deform;
            // 持续旋转叠加
            twistAngle += totalRotation * deform;
            
            // 距离变化
            float newDist = dist * (1.0 + sin(progress * 3.14159 + dist * 5.0) * 0.2 * deform);
            
            // 变形后的UV
            vec2 spiralUV = center + vec2(cos(twistAngle), sin(twistAngle)) * newDist;
            
            // 采样：都从螺旋UV采样，但混合比例不同
            vec4 fromColor = texture(from, clamp(spiralUV, 0.0, 1.0));
            vec4 toColor = texture(to, clamp(spiralUV, 0.0, 1.0));
            
            // 平滑混合：0→1
            float easeProgress = progress * progress * (3.0 - 2.0 * progress);
            mixFactor = easeProgress;
            
            colorFrom = fromColor * (1.0 - easeProgress);
            colorTo = toColor * easeProgress;
            
            break;
        }

        case 49: // 马赛克旋转效果
        {
            // 马赛克块参数
            float tileSize = 0.08;
            vec2 tileIndex = floor(uv / tileSize);
            vec2 tileCenter = (tileIndex + 0.5) * tileSize;
            vec2 tileUV = uv - tileCenter;  // 相对中心的坐标

            // 每个马赛克块的随机性
            float tileSeed = random(tileIndex);
            float tileOffset = tileSeed * 0.3;  // 每个块有不同的过渡时间偏移

            // 计算每个块的进度（带随机偏移）
            float localProgress = clamp((progress - tileOffset) / (1.0 - tileOffset * 0.5), 0.0, 1.0);

            vec2 sampledUV;
            vec4 finalColor;

            if (localProgress < 0.5) {
                // 前半段：旧图从原始状态旋转到180度
                float t = localProgress * 2.0;  // 0到1
                float rotation = t * 3.14159;  // 0到180度

                // 旋转马赛克块内的UV坐标
                float cosRot = cos(rotation);
                float sinRot = sin(rotation);
                vec2 rotatedUV;
                rotatedUV.x = tileUV.x * cosRot - tileUV.y * sinRot;
                rotatedUV.y = tileUV.x * sinRot + tileUV.y * cosRot;

                // 转换回纹理坐标
                sampledUV = tileCenter + rotatedUV;

                // 采样旧图
                finalColor = texture(from, clamp(sampledUV, 0.0, 1.0));

                colorFrom = finalColor;
                colorTo = finalColor;
                mixFactor = 0.0;
            } else {
                // 后半段：新图从180度旋转到360度（完成一整圈）
                // 计算后半段的归一化进度（0到1，确保所有块同步）
                float phase2Progress = clamp((progress - 0.5 - tileOffset * 0.25) / (0.5 - tileOffset * 0.25), 0.0, 1.0);

                // 旋转角度：从180度旋转到360度
                float rotation = 3.14159 + phase2Progress * 3.14159;  // 180度到360度

                // 旋转马赛克块内的UV坐标
                float cosRot = cos(rotation);
                float sinRot = sin(rotation);
                vec2 rotatedUV;
                rotatedUV.x = tileUV.x * cosRot - tileUV.y * sinRot;
                rotatedUV.y = tileUV.x * sinRot + tileUV.y * cosRot;

                // 转换回纹理坐标
                sampledUV = tileCenter + rotatedUV;

                // 采样新图
                finalColor = texture(to, clamp(sampledUV, 0.0, 1.0));

                colorFrom = finalColor;
                colorTo = finalColor;
                mixFactor = 1.0;
            }

            break;
        }

        case 50: // 液态融合效果
        {
            // 两张图片像液体一样融合混合，带有扭曲效果
            // 使用正弦波创建液态扭曲
            vec2 distortUV = uv;
            
            float time = progress * 6.28318;
            distortUV.x += sin(uv.y * 10.0 + time) * 0.02 * sin(progress * 3.14159);
            distortUV.y += cos(uv.x * 10.0 + time) * 0.02 * sin(progress * 3.14159);
            
            // 液态混合：使用噪声或波浪函数
            float wave1 = sin(distortUV.x * 8.0 + time) * 0.5 + 0.5;
            float wave2 = sin(distortUV.y * 8.0 + time * 0.7) * 0.5 + 0.5;
            float liquidMix = (wave1 + wave2) * 0.5;
            
            // 混合因子随进度变化
            mixFactor = smoothstep(liquidMix - 0.3, liquidMix + 0.3, progress);
            
            // 应用扭曲到颜色采样
            colorFrom = texture(from, distortUV);
            colorTo = texture(to, distortUV);
            
            // 添加液态光泽效果
            float shine = sin(distortUV.x * 15.0 + time * 1.5) * sin(distortUV.y * 15.0 + time * 1.2);
            if (shine > 0.8) {
                colorFrom.rgb += vec3(0.3, 0.5, 0.8) * (shine - 0.8) * 0.5;
                colorTo.rgb += vec3(0.3, 0.5, 0.8) * (shine - 0.8) * 0.5;
            }
            break;
        }

        case 51: // 马赛克飞散 - 旧图块向外飞散消失，新图块向内聚合显现
        {
            float gridSize = 10.0;
            float tileSize = 1.0 / gridSize;
            
            // 遍历所有块，找到覆盖当前uv的块
            vec4 resultColor = vec4(0.0);
            
            for (float i = 0.0; i < gridSize; i += 1.0) {
                for (float j = 0.0; j < gridSize; j += 1.0) {
                    vec2 gridIdx = vec2(i, j);
                    vec2 tileCenter = (gridIdx + 0.5) * tileSize;
                    
                    // 该块的随机属性
                    float seed = random(gridIdx);
                    float flyAngle = seed * 6.28318;
                    float flySpeed = 0.6 + seed * 0.6;
                    float delay = seed * 0.15;
                    
                    // 块进度
                    float blockProg = clamp((progress - delay) / (1.0 - delay), 0.0, 1.0);
                    
                    // 旧图阶段：块向外飞散 (0-0.5)
                    if (progress < 0.55) {
                        float flyDist = blockProg * flySpeed;
                        vec2 flyOffset = vec2(cos(flyAngle), sin(flyAngle)) * flyDist;
                        vec2 scatteredPos = tileCenter + flyOffset;
                        
                        // 检查当前uv是否在这个飞散后的块内
                        vec2 delta = uv - scatteredPos;
                        if (abs(delta.x) < tileSize * 0.5 && abs(delta.y) < tileSize * 0.5) {
                            // 计算采样位置
                            vec2 localUV = (delta / tileSize) + 0.5;
                            vec2 samplePos = gridIdx * tileSize + localUV * tileSize;
                            
                            float fade = 1.0 - smoothstep(0.2, 0.8, blockProg);
                            resultColor = texture(from, samplePos) * fade;
                        }
                    }
                    
                    // 新图阶段：块向内聚合 (0.45-1.0)
                    if (progress > 0.45) {
                        // 反向：从外向内
                        float gatherProg = 1.0 - blockProg;
                        float gatherDist = gatherProg * flySpeed;
                        vec2 gatherOffset = vec2(cos(flyAngle), sin(flyAngle)) * gatherDist;
                        vec2 gatheredPos = tileCenter + gatherOffset;
                        
                        // 检查当前uv是否在这个聚合中的块内
                        vec2 delta = uv - gatheredPos;
                        if (abs(delta.x) < tileSize * 0.5 && abs(delta.y) < tileSize * 0.5) {
                            // 计算采样位置
                            vec2 localUV = (delta / tileSize) + 0.5;
                            vec2 samplePos = gridIdx * tileSize + localUV * tileSize;
                            
                            float fade = smoothstep(0.2, 0.7, blockProg);
                            vec4 newCol = texture(to, samplePos) * fade;
                            
                            // 混合
                            resultColor = mix(resultColor, newCol, fade);
                        }
                    }
                }
            }
            
            mixFactor = progress;
            colorFrom = resultColor;
            colorTo = resultColor;
            
            break;
        }

        default: // 默认淡入淡出
        {
            mixFactor = progress;
            break;
        }
    }


    // 确保透明区域显示背景色，混合最终输出
    colorFrom = applyBackground(colorFrom, backgroundColor);
    colorTo = applyBackground(colorTo, backgroundColor);
    
    fragColor = mix(colorFrom, colorTo, mixFactor) * qt_Opacity;
}
