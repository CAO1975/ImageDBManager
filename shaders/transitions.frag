#version 450

// 输入 & 输出
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// Qt ShaderEffect 自动提供的 uniform
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int effectType;  // 效果类型: 0=溶解, 1=马赛克, 2=水波扭曲, 3=从左向右擦除, 4=从右向左擦除, 5=从上向下擦除, 6=从下向上擦除, 7=X轴窗帘, 8=Y轴窗帘, 9=故障, 10=旋转, 11=拉伸, 12=百叶窗, 13=扭曲呼吸, 14=涟漪扩散, 15=鱼眼, 16=切片, 17=反色, 18=模糊渐变
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

        default: // 默认淡入淡出
        {
            mixFactor = progress;
            break;
        }
    }

    // 鱼眼效果的额外淡入淡出
    if (effectType == 15) {
        float fadeAlpha;
        if (progress < 0.5) {
            // 前半段：淡出
            float t = progress * 2.0;
            fadeAlpha = 1.0 - t;  // 1.0 → 0.0
        } else {
            // 后半段：淡入
            float t = (progress - 0.5) * 2.0;
            fadeAlpha = t;  // 0.0 → 1.0
        }

        // 在mix之后应用淡入淡出
        colorFrom.rgb *= fadeAlpha;
        colorTo.rgb *= fadeAlpha;
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
