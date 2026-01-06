#version 450

// 输入 & 输出
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// Qt ShaderEffect 自动提供的 uniform
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    int effectType;  // 效果类型: 0=溶解, 1=马赛克, 2=波纹, 3=水波, 4=从左向右擦除, 5=从右向左擦除, 6=从上向下擦除, 7=从下向上擦除, 8=X轴窗帘, 9=Y轴窗帘, 10=故障, 11=旋转, 12=拉伸, 13=百叶窗
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

        case 2: // 波纹扩散（带涟漪变形）
        {
            vec2 center = vec2(0.5, 0.5);
            vec2 dir = normalize(uv - center);
            float dist = distance(uv, center);

            // 涟漪强度：只在过渡过程中有变形，过渡前后无变形
            float rippleIntensity = sin(progress * 3.14159);  // 0→1→0

            // 创建涟漪效果：多个同心圆波纹
            float ripple = sin(dist * 30.0 - progress * 20.0) * 0.01 * rippleIntensity;
            // 涟漪强度随距离衰减
            ripple *= smoothstep(0.7, 0.0, dist);

            // 应用涟漪偏移
            vec2 uvRipple = uv + dir * ripple;

            // 波纹从中心向外扩散，波纹内显示新图，外部显示旧图
            float waveRadius = progress * 0.8;
            mixFactor = smoothstep(waveRadius, waveRadius - 0.08, dist);

            // 对两张图都应用涟漪变形
            colorFrom = texture(from, uvRipple);
            colorTo = texture(to, uvRipple);
            break;
        }

        case 3: // 水波扭曲
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

        case 4: // 从左向右擦除
        {
            mixFactor = step(uv.x, progress);
            break;
        }

        case 5: // 从右向左擦除
        {
            mixFactor = 1.0 - step(uv.x, 1.0 - progress);
            break;
        }

        case 6: // 从上向下擦除
        {
            mixFactor = step(uv.y, progress);
            break;
        }

        case 7: // 从下向上擦除
        {
            mixFactor = 1.0 - step(uv.y, 1.0 - progress);
            break;
        }

        case 8: // X轴窗帘（从中心向两侧）
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

        case 9: // Y轴窗帘（从中心向上下）
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

        case 10: // 故障艺术
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

        case 11: // 旋转效果
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

        case 12: // 拉伸效果
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
