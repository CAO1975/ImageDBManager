#version 450

// 输入 & 输出
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// Qt ShaderEffect 自动提供的 uniform
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int effectType;  // 效果类型: 0=溶解, 1=马赛克, 2=水波扭曲, 3=从左向右擦除, 4=从右向左擦除, 5=从上向下擦除, 6=从下向上擦除, 7=X轴窗帘, 8=Y轴窗帘, 9=故障, 10=旋转, 11=拉伸, 12=百叶窗, 13=扭曲呼吸, 14=涟漪扩散, 15=鱼眼, 16=切片, 17=反色, 18=模糊渐变, 19=破碎, 20=雷达扫描, 21=万花筒, 22=火焰燃烧, 23=水墨晕染, 24=时空隧道, 25=镜像分屏
    vec3 backgroundColor;  // 背景色 (RGB)
};

// Samplers
layout(binding = 1) uniform sampler2D from;
layout(binding = 2) uniform sampler2D to;

// 伪随机函数
float random(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
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
            // 扭曲强度随 progress 变化：0→1→0（仅在过渡过程中有扭曲）
            float waveIntensity = sin(progress * 3.14159);
            float wave = sin(uv.y * 20.0 + progress * 10.0) * 0.02 * waveIntensity;
            vec2 uvFrom = vec2(uv.x - wave, uv.y);
            vec2 uvTo = vec2(uv.x + wave, uv.y);
            colorFrom = texture(from, uvFrom);
            colorTo = texture(to, uvTo);
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
            // 图片从中间向两侧展开：左半部分向左移动，右半部分向右移动
            // 中心点 X 坐标
            float centerX = 0.5;

            // 计算当前像素距离中心的距离（0.0 到 0.5）
            float distFromCenter = abs(uv.x - centerX);

            // 窗帘拉开的位置：从中心向两侧扩展
            float curtainPos = progress * 0.5;

            // 如果当前像素在窗帘开合位置之外，显示新图
            // 否则显示旧图
            mixFactor = step(distFromCenter, curtainPos);
            break;
        }

        case 8: // Y轴窗帘（从中心向上下）
        {
            // 图片从中间向上下展开：上半部分向上移动，下半部分向下移动
            // 中心点 Y 坐标
            float centerY = 0.5;

            // 计算当前像素距离中心的距离（0.0 到 0.5）
            float distFromCenter = abs(uv.y - centerY);

            // 窗帘拉开的位置：从中心向上下扩展
            float curtainPos = progress * 0.5;

            // 如果当前像素在窗帘开合位置之外，显示新图
            // 否则显示旧图
            mixFactor = step(distFromCenter, curtainPos);
            break;
        }

        case 9: // 故障艺术
        {
            float offset = 0.01 * sin(progress * 20.0);
            float r = texture(from, uv + vec2(offset, 0.0)).r;
            float g = texture(from, uv).g;
            float b = texture(from, uv - vec2(offset, 0.0)).b;
            colorFrom = vec4(r, g, b, 1.0);

            float noise = random(uv);
            float glitch = step(noise, progress * 0.1);
            if (progress > 0.3 && progress < 0.7) {
                colorFrom = mix(colorFrom, vec4(1.0, 1.0, 1.0, 1.0), glitch);
            }
            break;
        }

        case 10: // 旋转效果
        {
            vec2 center = vec2(0.5, 0.5);
            float angleFrom = progress * 3.14159;
            float angleTo = (1.0 - progress) * 3.14159;
            mat2 rotFrom = mat2(cos(angleFrom), sin(angleFrom), -sin(angleFrom), cos(angleFrom));
            mat2 rotTo = mat2(cos(angleTo), sin(angleTo), -sin(angleTo), cos(angleTo));
            vec2 uvFrom = center + rotFrom * (uv - center);
            vec2 uvTo = center + rotTo * (uv - center);
            colorFrom = texture(from, uvFrom);
            colorTo = texture(to, uvTo);
            break;
        }

        case 11: // 拉伸效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvFromCenter = uv - center;

            // 拉伸：旧图在X轴旋转，新图在X轴旋转
            float angle = progress * 3.14159;  // 0→π

            // 决定显示哪张图：拉伸前半段显示旧图，后半段显示新图
            if (angle < 1.5708) {  // π/2
                // 前半段：显示旧图，逐渐变窄
                float scale = abs(cos(angle));
                vec2 uvFrom = center + vec2(uvFromCenter.x * scale, uvFromCenter.y);
                colorFrom = texture(from, uvFrom);
                colorTo = colorFrom;
                mixFactor = 0.0;
            } else {
                // 后半段：显示新图，从窄变宽
                float scale = abs(cos(angle));
                vec2 uvTo = center + vec2(uvFromCenter.x * scale, uvFromCenter.y);
                colorFrom = texture(to, uvTo);
                colorTo = colorFrom;
                mixFactor = 1.0;
            }
            break;
        }

        case 12: // 百叶窗效果
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

        case 13: // 扭曲呼吸
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;

            // 前半段：旧图扭曲并水平压缩成一条垂直线
            // 后半段：新图从垂直线反向扭曲并水平展开

            if (progress < 0.5) {
                // 前半段：显示旧图
                float t = progress * 2.0;  // 0-1

                // 水平压缩：1.0 → 0.02（压扁成线）
                float scaleX = mix(1.0, 0.02, t);
                float scaleY = 1.0;

                // 扭曲角度：随时间增加，最多转0.5圈
                float twistAngle = t * 6.28318 * 0.5;

                // 先应用压缩，再应用扭曲
                vec2 compressedUV = vec2(uvOffset.x * scaleX, uvOffset.y * scaleY);

                // 转换为极坐标进行扭曲
                float dist = length(compressedUV);
                float angle = atan(compressedUV.y, compressedUV.x);

                // 扭曲旋转
                vec2 twistedUV = vec2(
                    cos(angle + twistAngle) * dist,
                    sin(angle + twistAngle) * dist
                );

                colorFrom = texture(from, center + twistedUV);
                colorTo = colorFrom;
                mixFactor = 0.0;
            } else {
                // 后半段：显示新图
                float t = (progress - 0.5) * 2.0;  // 0-1

                // 水平压缩：0.02 → 1.0（从线展开）
                float scaleX = mix(0.02, 1.0, t);
                float scaleY = 1.0;

                // 扭曲角度：从0.5圈减少到0
                float twistAngle = (1.0 - t) * 6.28318 * 0.5;

                // 先应用压缩，再应用扭曲
                vec2 compressedUV = vec2(uvOffset.x * scaleX, uvOffset.y * scaleY);

                // 转换为极坐标进行扭曲
                float dist = length(compressedUV);
                float angle = atan(compressedUV.y, compressedUV.x);

                // 扭曲旋转（反向）
                vec2 twistedUV = vec2(
                    cos(angle - twistAngle) * dist,
                    sin(angle - twistAngle) * dist
                );

                colorFrom = texture(to, center + twistedUV);
                colorTo = colorFrom;
                mixFactor = 1.0;
            }

            break;
        }

        case 14: // 涟漪扩散效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 dir = normalize(uv - center);
            float dist = distance(uv, center);

            // 创建多个同心圆涟漪
            float ripple = sin(dist * 30.0 - progress * 15.0) * 0.02 * sin(progress * 3.14159);

            // 应用涟漪变形
            vec2 uvRipple = uv + dir * ripple;
            colorFrom = texture(from, uvRipple);
            colorTo = texture(to, uvRipple);

            // 涟漪波前从中心向外扩散
            float waveRadius = progress * 0.9;
            mixFactor = smoothstep(waveRadius, waveRadius - 0.1, dist);

            break;
        }

        case 15: // 鱼眼效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);

            if (progress < 0.5) {
                // 前半段：旧图向中心凹陷成点
                float t = progress * 2.0;  // 0-1
                // 凹陷程度：power从1.0逐渐减少到0.1，让边缘像素向中心汇聚
                float power = mix(1.0, 0.1, t);
                float newDist = pow(dist, power);
                vec2 fishEyeUV = center + normalize(uvOffset) * newDist;

                colorFrom = texture(from, fishEyeUV);
                colorTo = colorFrom;
                mixFactor = 0.0;
            } else {
                // 后半段：新图从中心突出成图
                float t = (progress - 0.5) * 2.0;  // 0-1
                // 突出程度：power从0.1逐渐增加到1.0，从中心展开
                float power = mix(0.1, 1.0, t);
                float newDist = pow(dist, power);
                vec2 fishEyeUV = center + normalize(uvOffset) * newDist;

                colorFrom = texture(to, fishEyeUV);
                colorTo = colorFrom;
                mixFactor = 1.0;
            }

            break;
        }

        case 16: // 切片效果
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

        case 17: // 反色效果
        {
            // 计算反色
            vec4 invertedFrom = vec4(1.0 - colorFrom.rgb, colorFrom.a);
            vec4 invertedTo = vec4(1.0 - colorTo.rgb, colorTo.a);

            if (progress < 0.5) {
                // 前半段：旧图逐渐反色
                float t = progress * 2.0;
                colorFrom = mix(colorFrom, invertedFrom, t);
                mixFactor = 0.0;
            } else {
                // 后半段：新图从反色逐渐恢复正常
                float t = (progress - 0.5) * 2.0;
                colorFrom = mix(invertedTo, colorTo, t);
                colorTo = colorFrom;
                mixFactor = 1.0;
            }

            break;
        }

        case 18: // 模糊渐变效果
        {
            float blurAmount;

            if (progress < 0.5) {
                // 前半段：旧图逐渐模糊
                float t = progress * 2.0;
                blurAmount = t * 0.02;

                // 简单盒式模糊
                vec4 blurredColor = vec4(0.0);
                int samples = 4;
                for (int x = -samples; x <= samples; x++) {
                    for (int y = -samples; y <= samples; y++) {
                        vec2 offset = vec2(float(x), float(y)) * blurAmount;
                        blurredColor += texture(from, uv + offset);
                    }
                }
                colorFrom = blurredColor / float((samples * 2 + 1) * (samples * 2 + 1));
                colorTo = colorFrom;
                mixFactor = 0.0;
            } else {
                // 后半段：新图从模糊逐渐清晰
                float t = (progress - 0.5) * 2.0;
                blurAmount = (1.0 - t) * 0.02;

                // 简单盒式模糊
                vec4 blurredColor = vec4(0.0);
                int samples = 4;
                for (int x = -samples; x <= samples; x++) {
                    for (int y = -samples; y <= samples; y++) {
                        vec2 offset = vec2(float(x), float(y)) * blurAmount;
                        blurredColor += texture(to, uv + offset);
                    }
                }
                colorFrom = blurredColor / float((samples * 2 + 1) * (samples * 2 + 1));
                colorTo = colorFrom;
                mixFactor = 1.0;
            }

            break;
        }

        case 19: // 破碎效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);
            float angle = atan(uvOffset.y, uvOffset.x);

            // 破碎参数
            float numShards = 12.0;
            float shardAngle = 2.0 * 3.14159 / numShards;
            int shardIndex = int(mod(angle + 3.14159, 2.0 * 3.14159) / shardAngle);

            // 随机偏移模拟破碎
            float randomOffset = random(vec2(float(shardIndex), progress));
            vec2 shardDir = vec2(cos(float(shardIndex) * shardAngle), sin(float(shardIndex) * shardAngle));

            if (progress < 0.5) {
                // 前半段：旧图破碎向外飞散
                float t = progress * 2.0;
                float flyDistance = t * 0.3 * randomOffset;
                vec2 shatteredUV = uv + shardDir * flyDistance;
                colorFrom = texture(from, shatteredUV);
                colorTo = colorFrom;
                mixFactor = 0.0;
            } else {
                // 后半段：新图从碎片中重组
                float t = (progress - 0.5) * 2.0;
                float flyDistance = (1.0 - t) * 0.3 * randomOffset;
                vec2 shatteredUV = uv - shardDir * flyDistance;
                colorFrom = texture(to, shatteredUV);
                colorTo = colorFrom;
                mixFactor = 1.0;
            }

            break;
        }

        case 20: // 雷达扫描效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = distance(uv, center);
            float angle = atan(uvOffset.y, uvOffset.x);

            // 雷达扫描线从中心旋转扫描，旋转360度（1圈）完成过渡
            float scanAngle = progress * 6.28318;  // 旋转1圈（0到2π）

            // 将角度映射到0-2π范围（从0开始，逆时针方向）
            float normalizedAngle = mod(angle + 3.14159, 6.28318);

            // 判断当前像素的角度是否在扫描线扫过的区域内
            // 扫过的区域（0到scanAngle）：显示新图
            // 未扫过的区域：显示旧图
            mixFactor = smoothstep(0.0, 0.05, scanAngle - normalizedAngle);

            // 采样两张图片
            colorFrom = texture(from, uv);
            colorTo = texture(to, uv);

            break;
        }

        case 21: // 万花筒效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);
            float angle = atan(uvOffset.y, uvOffset.x);

            // 万花筒参数：6重对称
            float numSegments = 6.0;
            float segmentAngle = 2.0 * 3.14159 / numSegments;
            float segmentedAngle = mod(angle + 3.14159, segmentAngle) - segmentAngle / 2.0;

            // 旋转万花筒
            float rotateAngle = progress * 6.28318;

            vec2 kaleidoscopeUV = center + dist * vec2(cos(segmentedAngle + rotateAngle), sin(segmentedAngle + rotateAngle));

            if (progress < 0.5) {
                // 前半段：显示旧图万花筒
                colorFrom = texture(from, kaleidoscopeUV);
                colorTo = colorFrom;
                mixFactor = 0.0;
            } else {
                // 后半段：显示新图万花筒
                colorFrom = texture(to, kaleidoscopeUV);
                colorTo = colorFrom;
                mixFactor = 1.0;
            }

            break;
        }

        case 22: // 火焰燃烧效果
        {
            vec2 center = vec2(0.5, 0.5);
            float distFromBottom = 1.0 - uv.y;  // 距离底部的距离

            // 火焰从底部向上蔓延
            float flameHeight = progress * 1.2;

            // 火焰边缘抖动
            float flameJitter = sin(uv.x * 20.0 + progress * 10.0) * 0.02 * sin(progress * 3.14159);
            float flameEdge = flameHeight + flameJitter;

            // 判断像素是否在火焰边缘附近（燃烧的旧图区域）
            // burningZone: 1表示在燃烧边缘（火焰上方），0表示其他位置
            float burningZone = smoothstep(flameEdge - 0.15, flameEdge, distFromBottom);
            burningZone *= (1.0 - smoothstep(flameEdge, flameEdge + 0.05, distFromBottom));

            // mixFactor控制新旧图片的混合：火焰下方显示旧图，上方显示新图
            mixFactor = 1.0 - smoothstep(flameEdge - 0.05, flameEdge + 0.05, distFromBottom);

            // 采样原始图片
            colorFrom = texture(from, uv);
            colorTo = texture(to, uv);

            // 只在燃烧的旧图区域添加火焰效果
            if (burningZone > 0.01) {
                // 火焰颜色渐变：底部红色 -> 中间橙色 -> 顶部黄色
                vec3 fireColor = mix(vec3(1.0, 0.0, 0.0), vec3(1.0, 0.5, 0.0), smoothstep(0.0, 0.5, distFromBottom / flameEdge));
                fireColor = mix(fireColor, vec3(1.0, 0.8, 0.2), smoothstep(0.5, 1.0, distFromBottom / flameEdge));

                // 添加火焰闪烁
                float flicker = sin(uv.x * 30.0 + uv.y * 30.0 + progress * 20.0) * 0.5 + 0.5;
                fireColor *= (0.8 + 0.4 * flicker);

                // 只对旧图添加火焰效果
                colorFrom.rgb += fireColor * 0.5 * burningZone;
            }

            break;
        }

        case 23: // 水墨晕染效果
        {
            vec2 center = vec2(0.5, 0.5);
            float dist = distance(uv, center);

            // 水墨从中心晕染扩散
            float inkRadius = progress * 0.9;

            // 晕染边缘不规则
            float inkJitter = random(uv) * 0.05 * sin(progress * 3.14159);
            float inkEdge = inkRadius + inkJitter;

            mixFactor = smoothstep(inkEdge, inkEdge - 0.1, dist);

            // 晕染区域显示新图，带水墨模糊
            vec2 inkBlurUV = uv + random(uv * 10.0 + progress) * 0.01;
            colorFrom = texture(from, uv);
            colorTo = texture(to, inkBlurUV);

            break;
        }

        case 24: // 粒子爆炸效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);

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
            float distFromCenter = length(uvOffset);
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

        case 25: // 极光流动效果
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

        case 26: // 赛博朋克故障效果
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

        case 27: // 黑洞吞噬效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);
            float angle = atan(uvOffset.y, uvOffset.x);

            // 黑洞吞噬：旧图片被吸入黑洞并扭曲，新图片从另一侧显现
            float blackholeRadius = progress * 0.5;  // 黑洞半径

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

            // 新图从另一侧显现
            float newScale = progress;
            vec2 newUV = center + newScale * vec2(cos(angle), sin(angle)) * dist;

            // 混合
            mixFactor = progress;
            colorFrom = texture(from, oldUV);
            colorTo = texture(to, newUV);

            // 黑洞区域显示黑色
            if (dist < blackholeRadius) {
                colorFrom = vec4(0.0, 0.0, 0.0, 1.0);
                colorTo = colorFrom;
            }

            // 添加吸积盘发光
            colorFrom.rgb += diskColor * 0.5;
            colorTo.rgb += diskColor * 0.5;

            break;
        }

        case 28: // 全息投影效果
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

        case 29: // 光速穿越效果
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 uvOffset = uv - center;
            float dist = length(uvOffset);

            // 光速穿越：速度线划过，图片被穿透
            float lineCount = 50.0;
            float lineSpeed = progress * 10.0;

            // 生成速度线
            float lines = 0.0;
            for (float i = 0.0; i < lineCount; i++) {
                float linePos = fract(i / lineCount + progress * 0.5);
                float lineDist = abs(fract(uv.x * lineCount - linePos) - 0.5);
                float lineWidth = 0.01 + sin(i) * 0.005;
                lines += smoothstep(lineWidth, 0.0, lineDist);
            }

            // 速度线高亮
            vec3 speedColor = vec3(1.0, 1.0, 1.0) * lines * 0.8;

            // 图片扭曲（速度感）
            float warpStrength = sin(progress * 3.14159) * 0.02;
            vec2 warpUV = uv + vec2(sin(uv.y * 20.0 + progress * 10.0) * warpStrength,
                                    cos(uv.x * 20.0 + progress * 10.0) * warpStrength);

            // 径向模糊
            float radialBlur = 0.0;
            int blurSamples = 5;
            for (int i = 0; i < blurSamples; i++) {
                float t = float(i) / float(blurSamples);
                vec2 sampleUV = uv + uvOffset * t * progress * 0.1;
                radialBlur += texture(from, sampleUV).r;
            }
            radialBlur /= float(blurSamples);

            // 混合
            mixFactor = progress;
            colorFrom = texture(from, warpUV);
            colorTo = texture(to, warpUV);

            // 添加速度线
            colorFrom.rgb += speedColor;
            colorTo.rgb += speedColor;

            // 星星闪烁
            float star = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
            if (star > 0.99) {
                colorFrom.rgb += vec3(1.0, 1.0, 1.0) * sin(progress * 20.0) * 0.5 + 0.5;
                colorTo.rgb += vec3(1.0, 1.0, 1.0) * sin(progress * 20.0) * 0.5 + 0.5;
            }

            break;
        }

        default: // 默认淡入淡出
        {
            mixFactor = progress;
            break;
        }
    }


    // 确保透明区域显示背景色
    if (colorFrom.a < 0.01) {
        colorFrom = vec4(backgroundColor, 1.0);
    } else {
        colorFrom.a = 1.0;
    }
    if (colorTo.a < 0.01) {
        colorTo = vec4(backgroundColor, 1.0);
    } else {
        colorTo.a = 1.0;
    }

    // 混合两张图片
    vec4 finalColor = mix(colorFrom, colorTo, mixFactor);
    finalColor.a *= qt_Opacity;
    fragColor = finalColor;
}
