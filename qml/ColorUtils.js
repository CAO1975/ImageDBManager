.pragma library

/**
 * 根据背景颜色计算合适的文字颜色（黑或白）
 * 使用 YIQ 亮度公式: brightness = 0.299*R + 0.587*G + 0.114*B
 * @param {color} backgroundColor - 背景颜色
 * @returns {string} - 返回 "#000000" 或 "#FFFFFF"
 */
function getTextColor(backgroundColor) {
    let brightness = 0.299 * backgroundColor.r + 0.587 * backgroundColor.g + 0.114 * backgroundColor.b
    return brightness > 0.5 ? "#000000" : "#FFFFFF"
}

/**
 * 判断颜色是否为亮色
 * @param {color} color - 颜色值
 * @returns {boolean} - 是否为亮色
 */
function isLightColor(color) {
    let brightness = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
    return brightness > 0.5
}

/**
 * 获取对比色（黑或白）
 * @param {color} color - 颜色值
 * @returns {string} - 对比色
 */
function getContrastColor(color) {
    return isLightColor(color) ? "#000000" : "#FFFFFF"
}
