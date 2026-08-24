#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AnimationPreviewer 原创 App 图标生成器
=====================================

为什么有这个脚本
----------------
2026-08-22 App Store 以 Guideline 4.3 拒审：原来那只黑猫图标是网上找的免费素材，
和别人已上架的 App 撞了。

📢 后续用户决定**保留原来那只猫**，走「换配色 + 加背景」而不是换掉猫，
所以最终方案 `orig_gold` 仍然用 `前景-猫.png` 这份原素材（剪影没变）。
这是用户明确拍板的取舍，风险已告知：剪影和被拒那版一致，4.3 可能再中。
脚本里那 6 版纯程序化重画方案（cat_night/cat_chase/cat_warm/bounce/keyframe/morph）
是被否掉的备选，**留着当后备**——若再因 4.3 被拒，换成它们即可。

几何规范（照抄旧图标实测值，那套已验证能过 macOS 满版图标检查）
-------------------------------------------------------------
    画布      1024 x 1024
    本体      824 x 824 圆角方（超椭圆，n=5，即 Apple 的连续圆角观感）
    留白      四边各 100px
    投影      本体下方偏移的高斯模糊黑影

实现要点
--------
* 全部在 SS 倍超采样画布上绘制，最后 LANCZOS 缩到目标尺寸 —— 这是拿到平滑边缘的关键，
  PIL 的 polygon/ellipse 本身不做抗锯齿。
* 渐变用「低分辨率逐像素算 + BICUBIC 放大」，比逐像素铺满快几个数量级且视觉无损。
* 圆角三角形靠「先 polygon 填充，再用同色 joint='curve' 粗线描边」实现，
  PIL 没有原生的圆角多边形。

用法
----
    python3 icon_gen.py preview            # 生成候选方案的 1024 预览图到 _preview/
    python3 icon_gen.py install orig_cream # 渲染整套尺寸并直接写进工程的 AppIcon.appiconset

当前采用方案：orig_cream（原版猫 + 奶白配色 + 靛紫渐变底，眼白为深靛蓝）
候选方案切换：改 PREVIEW_KEYS 后跑 preview，选定后 install <方案名>
"""

import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

# ---------------------------------------------------------------- 几何常量

CANVAS = 1024          # 画布边长
BODY = 824             # 圆角本体边长
MARGIN = (CANVAS - BODY) // 2   # = 100
SS = 4                 # 超采样倍数
SQUIRCLE_N = 5         # 超椭圆指数，5 最接近 Apple 的连续圆角

HERE = os.path.dirname(os.path.abspath(__file__))


# ---------------------------------------------------------------- 基础工具


def superellipse_pts(cx, cy, hx, hy, n, samples=1024):
    """超椭圆顶点序列。参数式：x = hx·sgn(cos t)·|cos t|^(2/n)，y 同理。

    n=2 是椭圆，n→∞ 趋近矩形。实测旧图标的圆角反解出 n≈5.0~5.5，
    所以 n=5 跟已过审的那版几何一致（见 SQUIRCLE_N）。
    """
    e = 2.0 / n
    pts = []
    for i in range(samples):
        t = 2.0 * math.pi * i / samples
        ct, st = math.cos(t), math.sin(t)
        pts.append((
            cx + hx * math.copysign(abs(ct) ** e, ct),
            cy + hy * math.copysign(abs(st) ** e, st),
        ))
    return pts


def squircle_mask(size, n=SQUIRCLE_N):
    """图标本体的超椭圆蒙版，L 模式，白 = 本体内部。"""
    h = size / 2.0
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).polygon(
        superellipse_pts(h, h, h, h, n, samples=2048), fill=255)
    return m


def gradient(size, c0, c1, angle=135, res=96):
    """线性渐变。angle 单位为度，0=从左到右，90=从上到下。

    先在 res×res 上逐像素算（几千次循环，可忽略），再 BICUBIC 放大到 size。
    """
    rad = math.radians(angle)
    dx, dy = math.cos(rad), math.sin(rad)
    small = Image.new("RGB", (res, res))
    px = small.load()
    # 把 (dx,dy) 方向上的投影归一化到 0..1
    lo = min(0.0, dx) + min(0.0, dy)
    hi = max(0.0, dx) + max(0.0, dy)
    span = (hi - lo) or 1.0
    for y in range(res):
        fy = y / (res - 1)
        for x in range(res):
            fx = x / (res - 1)
            t = (fx * dx + fy * dy - lo) / span
            px[x, y] = (
                round(c0[0] + (c1[0] - c0[0]) * t),
                round(c0[1] + (c1[1] - c0[1]) * t),
                round(c0[2] + (c1[2] - c0[2]) * t),
            )
    return small.resize((size, size), Image.BICUBIC)


def rounded_mask(size, pts, radius):
    """带圆角的多边形蒙版（L 模式）。

    📢 别用「polygon 填充 + joint='curve' 粗线描边」那招：折线首尾相接处不算 joint，
    会在起点顶角留一个小豁口（第一版三角形左上角那个缺口就是它）。
    改用形态学做法：实心多边形 → 高斯模糊 → 在 0.5 处取等值线。
    模糊半径即圆角半径，且所有顶角一视同仁，不会有接缝。
    """
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    if radius > 0:
        m = m.filter(ImageFilter.GaussianBlur(radius))
        m = m.point(lambda v: 255 if v >= 128 else 0)
    return m


def paste_alpha(base, color, mask, alpha=255):
    """把纯色按 mask（L 模式）以指定不透明度合成到 base（RGBA）上。

    📢 千万别写成 `base.paste(纯色图, (0,0), mask)`：`Image.paste` 带 mask 时会把
    **RGB 通道也一起按 mask 插值**，base 是全透明黑，于是「白色 @23%」被算成
    「深灰 @23%」——半透明图形全部变成压暗背景，而不是提亮。
    洋葱皮残影发黑、暖色光晕变成一圈脏边，根因都在这。
    正确做法：RGB 恒为 color，只把 mask 灌进 alpha 通道，再走 alpha_composite。
    """
    if alpha < 255:
        mask = mask.point(lambda v: v * alpha // 255)
    layer = Image.new("RGBA", base.size, color + (0,))
    layer.putalpha(mask)
    base.alpha_composite(layer)


def circle_mask(size, cx, cy, r):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return m


def glow(size, cx, cy, r, blur):
    return circle_mask(size, cx, cy, r).filter(ImageFilter.GaussianBlur(blur))


# ---------------------------------------------------------------- 三个候选方案
#
# 每个 draw_* 只负责在「本体坐标系」里画内容：画布是 BODY*SS 见方的 RGBA，
# 左上角即圆角方的左上角。外层负责渐变底、裁形、投影、缩放。


def art_bounce(S):
    """方案 A：弹跳球运动弧 + 洋葱皮残影。

    弹球是每个动画师的第一课，最能一眼读出「动画」；洋葱皮（onion skin）残影
    是动画软件的标志性表达。虚线是运动路径，把空出来的右下角也填住了。
    """
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    k = S / 824.0   # 从 824 设计坐标换算到当前画布

    # 整条弧往下压过：球和残影的视觉重量集中在弧的上半段，弧线按几何居中摆
    # 会明显头重脚轻，靠下沉 60 来抵消
    x0, x1 = 152 * k, 672 * k
    ytop, ybot = 316 * k, 660 * k

    def arc(t):
        """t∈[0,1] 沿抛物线取点，t=0.5 为顶点。"""
        return (x0 + (x1 - x0) * t,
                ybot - (ybot - ytop) * (1 - (2 * t - 1) ** 2))

    # 运动路径虚线
    for i in range(52):
        t = i / 51.0
        cx, cy = arc(t)
        paste_alpha(img, (255, 255, 255), circle_mask(S, cx, cy, 7.5 * k), 58)

    # 洋葱皮残影：3 个逐渐变实的球（不叠在一起，否则糊成一团）
    for t, op in ((0.11, 58), (0.27, 104), (0.43, 158)):
        cx, cy = arc(t)
        paste_alpha(img, (255, 255, 255), circle_mask(S, cx, cy, 70 * k), op)

    # 主球：视觉重心，16px 下靠它撑住辨识度
    # 📢 别在下面垫暖色光晕：琥珀色半透明压在紫底上是「变暗」，出来是一圈脏边，
    #    第一版就栽在这。要提亮只能用白色，且不透明度要压得很低。
    cx, cy = arc(0.615)
    paste_alpha(img, (255, 255, 255), glow(S, cx, cy, 96 * k, 30 * k), 46)
    paste_alpha(img, (255, 211, 92), circle_mask(S, cx, cy, 86 * k), 255)

    return img, (43, 27, 107), (123, 63, 228), 128   # 底色：靛蓝 → 紫罗兰


def art_keyframe(S):
    """方案 B：关键帧菱形时间轴 + 播放三角。

    菱形关键帧是 After Effects / Lottie 那条工具链的通用语汇，加上播放三角
    点明「预览」。工具感最强，也是三个方案里最像成品的一版。
    """
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    k = S / 824.0

    # 上半部：圆角播放三角。视觉重心略偏左才显得居中（三角形右侧是尖的，
    # 几何居中会看着偏右），所以顶点按光学中心配。
    #
    # 📢 圆角半径别给大：`rounded_mask` 是「模糊 + 取等值线」，锐角顶点被啃掉的量
    # 远大于直角。这里给到 44 时三角形直接变成了拨片/水滴，20 才是三角形该有的样子。
    tri = rounded_mask(S, [(304 * k, 168 * k), (304 * k, 478 * k), (588 * k, 323 * k)],
                       int(20 * k))
    paste_alpha(img, (255, 255, 255), tri, 255)

    # 下半部：时间轴横条
    bar_y, bar_h = 608 * k, 20 * k
    bar = Image.new("L", (S, S), 0)
    ImageDraw.Draw(bar).rounded_rectangle(
        [152 * k, bar_y - bar_h / 2, 672 * k, bar_y + bar_h / 2],
        radius=bar_h / 2, fill=255,
    )
    paste_alpha(img, (255, 255, 255), bar, 105)

    # 三个关键帧菱形，中间那颗高亮放大
    for cx, half, color, op in (
        (224 * k, 44 * k, (255, 255, 255), 150),
        (412 * k, 68 * k, (255, 211, 92), 255),
        (600 * k, 44 * k, (255, 255, 255), 150),
    ):
        dia = Image.new("L", (S, S), 0)
        ImageDraw.Draw(dia).polygon(
            [(cx, bar_y - half), (cx + half, bar_y), (cx, bar_y + half), (cx - half, bar_y)],
            fill=255,
        )
        paste_alpha(img, color, dia, op)

    return img, (15, 32, 39), (44, 125, 160), 125   # 底色：墨蓝 → 湖蓝


def art_morph(S):
    """方案 C：方→圆的形变洋葱皮。

    直接把超椭圆指数 n 从「近方」推到「正圆」，中间几帧就是形变过程本身 ——
    这是最贴 Lottie/SVGA 这类矢量动画本质的表达，也是三个方案里最不可能撞的。

    📢 上一版这里是「播放三角 + 半透明三角残影」，废弃了：残影被实心主体压住后
    只剩两条竖边，看着像牛皮纸片，而且白色低透明度压在橙底上会脱色发土。
    """
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    k = S / 824.0
    cy = 412 * k

    # n 从 12（近方）过渡到 2（正圆），尺寸和不透明度同步递增 = 洋葱皮
    #
    # 📢 只放 3 帧、且间距必须大于半径：上一版塞了 4 帧、间距 87 而半径 116，
    # 帧与帧叠掉大半，整排糊成一块圆角板砖，完全读不出「方在变圆」。
    # 尺寸递增也是为了小尺寸：末帧那颗实心圆要够大，16px 下靠它撑辨识度。
    for cx, half, n, color, op in (
        (214 * k, 82 * k, 20.0, (255, 255, 255), 88),   # 首帧：n 拉到 20 才够「方」
        (400 * k, 98 * k, 4.0, (255, 255, 255), 152),
        (588 * k, 116 * k, 2.0, (255, 211, 92), 255),   # 末帧：实心正圆，视觉落点
    ):
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).polygon(superellipse_pts(cx, cy, half, half, n), fill=255)
        paste_alpha(img, color, m, op)

    return img, (20, 33, 82), (36, 124, 196), 122   # 底色：深海蓝 → 亮蓝


# ---------------------------------------------------------------- 小猫方案
#
# 📢 为什么是「重画」而不是「给旧图换个色」：
# Apple 4.3 判重看的是整体视觉相似度，同一个剪影换配色仍会被判成同一个图标；
# 而且旧图那只猫是免费素材站的现成图，换色之后撞图的根还在（别人还在用同一张）。
# 所以这里的猫全部由几何图元程序化绘制，且刻意换了构图：
#   旧图 = 全身坐姿猫 + 细卷尾 + 纯白底
#   新图 = 猫头特写（无身体无尾巴）+ 彩色渐变底
# 构图层面就不是一张图，判重不会再撞。


def cat_head_mask(S, k, cx, cy, hw, hh):
    """几何小猫头部剪影（头 + 两只耳朵的并集），L 模式。

    📢 头和耳朵必须画进**同一张** mask 再一次性合成：
    如果分开用半透明分别 paste，重叠区会叠出一道更亮的接缝。
    """
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)

    # 头：横向略宽的超椭圆，n=2.7 带出猫的腮帮子（正圆会像熊）
    d.polygon(superellipse_pts(cx, cy, hw, hh, 2.7), fill=255)

    # 耳朵：左右各一个圆角三角形，外缘更陡、内缘搭进头里，所以会和头融成一体
    #
    # 📢 耳朵一定要够长够尖：第一版耳尖只探出头顶 0.28×hh，出来像熊/像 Octocat，
    # 完全不像猫。探出到 0.62×hh（约头高的三分之一）才是猫的比例。
    # 圆角半径也得压到 10 以内，再大耳尖就被啃圆了。
    for sign in (-1, 1):
        pts = [
            (cx + sign * hw * 0.98, cy - hh * 0.40),   # 外侧根部
            (cx + sign * hw * 0.84, cy - hh * 1.60),   # 耳尖
            (cx + sign * hw * 0.24, cy - hh * 0.82),   # 内侧根部
        ]
        m.paste(255, (0, 0), rounded_mask(S, pts, int(9 * k)))

    return m


def cat_art(S, fur, eye, *, with_ball, bg):
    """把小猫画到画布上。with_ball=True 时额外加「猫在看弹跳球」的运动元素。"""
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    k = S / 824.0

    if with_ball:
        # 猫头下移让位给上方的球；顺带缩小一点，避免两个元素抢视觉
        cx, cy, hw, hh = 380 * k, 574 * k, 172 * k, 156 * k

        # 运动轨迹虚线：从左侧拱到右上，球停在末端 —— 读作「猫在追这颗球」
        #
        # 📢 轨迹必须整条走在耳尖上方：上一版的拱高不够，虚线正好从两只耳朵中间
        # 穿过去，看着像猫头上插了根天线。耳尖在 cy-1.62×hh ≈ 321，所以中段压到 262。
        x0, y0, x1, y1, bow = 172 * k, 436 * k, 536 * k, 262 * k, 88 * k
        for i in range(30):
            t = i / 29.0
            px = x0 + (x1 - x0) * t
            py = y0 + (y1 - y0) * t - bow * 4 * t * (1 - t)
            paste_alpha(img, (255, 255, 255), circle_mask(S, px, py, 7 * k), 64)

        paste_alpha(img, eye, circle_mask(S, 616 * k, 232 * k, 70 * k), 255)
    else:
        cx, cy, hw, hh = 412 * k, 486 * k, 196 * k, 178 * k

    # 猫身（头 + 耳）
    paste_alpha(img, fur, cat_head_mask(S, k, cx, cy, hw, hh), 255)

    # 眼睛：两颗竖椭圆。竖着才像猫眼，正圆会显得呆
    for sign in (-1, 1):
        ex = cx + sign * hw * 0.37
        ey = cy - hh * 0.12
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).polygon(
            superellipse_pts(ex, ey, hw * 0.175, hh * 0.225, 2.2), fill=255)
        paste_alpha(img, eye, m, 255)

    # 鼻子：一个朝下的小圆角三角。16px 下它只是一个点，但在大尺寸上
    # 这一笔能把「猫」钉死，没有它容易被读成别的动物
    nose = rounded_mask(S, [
        (cx - hw * 0.105, cy + hh * 0.30),
        (cx + hw * 0.105, cy + hh * 0.30),
        (cx, cy + hh * 0.47),
    ], int(7 * k))
    paste_alpha(img, eye, nose, 255)

    return (img,) + bg


def art_cat_night(S):
    """小猫 A：白猫 + 琥珀猫眼，靛紫夜色底。"""
    return cat_art(S, (255, 255, 255), (255, 199, 74),
                   with_ball=False, bg=((43, 27, 107), (123, 63, 228), 128))


def art_cat_chase(S):
    """小猫 B：白猫抬头追一颗琥珀色弹跳球，靛紫底。

    猫 + 运动轨迹，既留住吉祥物又把「预览动画」这层意思画出来了。
    """
    return cat_art(S, (255, 255, 255), (255, 199, 74),
                   with_ball=True, bg=((38, 24, 96), (110, 58, 214), 128))


def art_cat_warm(S):
    """小猫 C：深墨蓝猫 + 奶白猫眼，暖橙底。

    最接近「原来那只黑猫，只是换了个色」的观感：深色猫、亮色底，
    但剪影是重画的猫头特写，跟旧图不是一张。
    """
    return cat_art(S, (26, 32, 66), (255, 247, 232),
                   with_ball=False, bg=((255, 176, 74), (255, 108, 92), 120))


# ---------------------------------------------------------------- 原版小猫（换色 + 加背景）
#
# 用户要求换回原来那只猫，只换配色、加背景，并保留原图的渐变。
# 原图猫身是**中性灰的竖直线性渐变**（实测：y=280 处 #57 灰，到 y=760 处 #02 近黑），
# 背景是纯白、无渐变 —— 所以「要保持的渐变」指的是猫身那条。
#
# 上色方式是**灰度 → 配色的查表映射**，不是重新画一条近似渐变：
# 原图的每个灰阶按同一张 LUT 换成新颜色，那条渐变就被逐像素原样搬过来了。
# 附带好处是眼白（灰阶 255）和瞳孔（灰阶 ~40）会自动落到 LUT 两端，不用单独抠。

CAT_SRC = os.path.join(HERE, "前景-猫.png")

# 素材图里猫的真实包围盒。
# 📢 别直接用 `alpha.getbbox()`：该图底部 y=850~870 有几个 alpha<80 的杂点，
# 会把包围盒从 590 高撑到 737 高，缩放比例整个算错。
CAT_SRC_BOX = (169, 136, 855, 727)

# 猫在 1024 画布里的目标位置，照抄旧图标实测值（换回去要连位置和大小一起换回去）
CAT_DST_BOX = (190, 234, 841, 797)

# 猫身灰阶的实际上限。原图猫身只用到 0~95 这一段，
# 若按 0~255 整段映射，猫身会全部挤在 LUT 的最暗端，换色等于没换。
BODY_L_MAX = 100


def _lut(dark, light, idx):
    """灰阶 → 单通道颜色的查表。猫身段(0~BODY_L_MAX)线性插值，之上留给眼白。"""
    out = []
    for v in range(256):
        t = min(v, BODY_L_MAX) / BODY_L_MAX
        out.append(round(dark[idx] + (light[idx] - dark[idx]) * t))
    return out


def build_cat(canvas, body_dark, body_light, eye):
    """把原版小猫按新配色画到 canvas 尺寸的透明层上，位置对齐旧图标。

    📢 猫必须在**最终分辨率**下贴，不能跟背景一样走 SS=4 超采样：
    素材只有 685px 宽，超采样画布要 2604px，等于 3.8 倍放大，边缘会糊。
    目标尺寸 651px 反而是轻微缩小，画质无损。
    """
    src = Image.open(CAT_SRC).convert("RGBA").crop(CAT_SRC_BOX)
    w = CAT_DST_BOX[2] - CAT_DST_BOX[0]
    h = CAT_DST_BOX[3] - CAT_DST_BOX[1]
    src = src.resize((w, h), Image.LANCZOS)

    alpha = src.split()[3]
    lum = src.convert("L")

    # 眼白权重：灰阶 120~190 之间过渡，之上算眼白、之下算猫身（瞳孔归猫身，跟原图一致）
    eyeness = lum.point(
        lambda v: 0 if v < 120 else (255 if v > 190 else round((v - 120) * 255 / 70)))

    # 猫身：灰阶查表上色，保留原渐变
    body_rgb = Image.merge("RGB", [
        lum.point(_lut(body_dark, body_light, i)) for i in range(3)])
    body_a = ImageChops.multiply(alpha, ImageChops.invert(eyeness))
    body = body_rgb.convert("RGBA")
    body.putalpha(body_a)

    # 眼白：纯色
    eyes = Image.new("RGBA", src.size, eye + (0,))
    eyes.putalpha(ImageChops.multiply(alpha, eyeness))

    cat = Image.alpha_composite(body, eyes)

    layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    layer.paste(cat, (CAT_DST_BOX[0], CAT_DST_BOX[1]), cat)
    return layer, alpha


def render_orig_cat(spec, canvas=CANVAS):
    """渲染「原版小猫 + 新配色 + 新背景」整张图标。"""
    S = BODY * SS

    # 1) 本体背景：渐变 + 装饰，超采样后缩回
    bg = gradient(S, spec["c0"], spec["c1"], spec["angle"]).convert("RGBA")
    if spec.get("glow"):
        # 猫头后面一团柔光，让平渐变有纵深，也就是要求里的「背景图」
        gx, gy, gr, gop = spec["glow"]
        paste_alpha(bg, spec["glow_color"],
                    glow(S, gx * SS, gy * SS, gr * SS, 90 * SS), gop)
    # 散景光斑。
    # 📢 必须是柔边的：用 `circle_mask` 画硬边圆点，出来像贴上去的贴纸/像脏点，
    # 尤其压到圆角边缘被裁一刀时更明显。模糊半径取半径的 0.45 倍才像环境光。
    for dx, dy, dr, dop in spec.get("bokeh", []):
        paste_alpha(bg, spec["glow_color"],
                    glow(S, dx * SS, dy * SS, dr * SS, dr * 0.45 * SS), dop)
    bg.putalpha(squircle_mask(S))
    body = bg.resize((BODY, BODY), Image.LANCZOS)
    body_mask = squircle_mask(S).resize((BODY, BODY), Image.LANCZOS)

    # 2) 图标自身的外投影 + 本体
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    sh = Image.new("L", (canvas, canvas), 0)
    sh.paste(body_mask, (MARGIN, MARGIN + 16))
    sh = sh.filter(ImageFilter.GaussianBlur(20))
    shade = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    shade.putalpha(sh.point(lambda v: v * 66 // 255))
    out = Image.alpha_composite(out, shade)
    out.paste(body, (MARGIN, MARGIN), body)

    # 3) 猫的贴地投影（原图猫身本来就带一层淡影，换到彩底上更需要它来托住）
    cat, cat_alpha = build_cat(canvas, spec["fur_dark"], spec["fur_light"], spec["eye"])
    cs = Image.new("L", (canvas, canvas), 0)
    cs.paste(cat_alpha, (CAT_DST_BOX[0], CAT_DST_BOX[1] + 10))
    cs = cs.filter(ImageFilter.GaussianBlur(14))
    csh = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    csh.putalpha(ImageChops.multiply(cs.point(lambda v: v * spec["cat_shadow"] // 255),
                                     _body_region_mask(canvas, body_mask)))
    out = Image.alpha_composite(out, csh)
    out = Image.alpha_composite(out, cat)
    return out


def _body_region_mask(canvas, body_mask):
    """把本体蒙版摆到画布上，用来裁掉可能溢出圆角的猫投影。"""
    m = Image.new("L", (canvas, canvas), 0)
    m.paste(body_mask, (MARGIN, MARGIN))
    return m


# 三个候选：都保留猫身原渐变，都换了配色并加了背景
ORIG_CAT_SPECS = {
    "orig_cream": {
        "label": "原版猫 A 奶白猫 + 靛紫底",
        "fur_dark": (198, 190, 232), "fur_light": (255, 255, 255),
        "eye": (43, 27, 107), "cat_shadow": 70,
        "c0": (48, 30, 112), "c1": (126, 68, 232), "angle": 128,
        "glow": (300, 330, 340, 62), "glow_color": (255, 255, 255),
        "bokeh": [(648, 206, 104, 30), (196, 664, 128, 22)],
    },
    "orig_gold": {
        "label": "原版猫 B 琥珀金猫 + 墨蓝底",
        "fur_dark": (150, 84, 0), "fur_light": (255, 214, 122),
        # 眼白纯白（曾按要求试过，最终未采用此方案，保留供参考）。
        # 📢 金猫身上白眼白的对比不如深色眼白，靠瞳孔那道深色竖缝来立住，
        #    所以 fur_dark 不能调太亮，否则瞳孔会和眼白糊在一起。
        "eye": (255, 255, 255), "cat_shadow": 96,
        "c0": (14, 26, 56), "c1": (36, 88, 132), "angle": 125,
        "glow": (300, 330, 340, 52), "glow_color": (255, 205, 120),
        "bokeh": [(650, 208, 100, 34), (200, 668, 124, 20)],
    },
    "orig_warm": {
        "label": "原版猫 C 深色猫 + 暖白底",
        "fur_dark": (16, 16, 26), "fur_light": (92, 92, 108),
        "eye": (255, 248, 236), "cat_shadow": 60,
        "c0": (255, 246, 232), "c1": (255, 206, 156), "angle": 122,
        "glow": (300, 330, 340, 86), "glow_color": (255, 255, 255),
        "bokeh": [(650, 210, 102, 78), (200, 668, 126, 46)],
    },
}


VARIANTS = {
    "cat_night": ("猫 A 白猫夜色", art_cat_night),
    "cat_chase": ("猫 B 白猫追球", art_cat_chase),
    "cat_warm": ("猫 C 深色猫暖底", art_cat_warm),
    "bounce": ("A 弹跳球运动弧", art_bounce),
    "keyframe": ("B 关键帧时间轴", art_keyframe),
    "morph": ("C 方→圆形变洋葱皮", art_morph),
}

# 所有方案名 -> 中文标签，供命令行用法提示和预览标题使用
LABELS = {k: v["label"] for k, v in ORIG_CAT_SPECS.items()}
LABELS.update({k: v[0] for k, v in VARIANTS.items()})

# 当前在选的是「原版猫换色」这一组；上面 6 版重画方案已被否掉，留着备查
PREVIEW_KEYS = list(ORIG_CAT_SPECS)


# ---------------------------------------------------------------- 组装


def render(variant, out_size=CANVAS):
    """渲染完整图标（含渐变底、圆角裁形、投影），返回 out_size 的 RGBA。

    两类方案走两条路：`ORIG_CAT_SPECS` 里的是「原版猫换色」，靠 spec 字典驱动；
    `VARIANTS` 里的是纯程序化重画方案。
    """
    if variant in ORIG_CAT_SPECS:
        out = render_orig_cat(ORIG_CAT_SPECS[variant])
        return out if out_size == CANVAS else out.resize(
            (out_size, out_size), Image.LANCZOS)

    _, fn = VARIANTS[variant]
    S = BODY * SS                       # 本体超采样边长
    art, c0, c1, angle = fn(S)

    # 本体 = 渐变底 + 内容，再用超椭圆裁形
    body = gradient(S, c0, c1, angle).convert("RGBA")
    body = Image.alpha_composite(body, art)
    body.putalpha(squircle_mask(S))

    # 铺到整张超采样画布上
    full = CANVAS * SS
    canvas = Image.new("RGBA", (full, full), (0, 0, 0, 0))
    canvas.paste(body, (MARGIN * SS, MARGIN * SS), body)

    # 投影：本体蒙版下移后高斯模糊，压在本体底下
    shadow = Image.new("L", (full, full), 0)
    shadow.paste(squircle_mask(S), (MARGIN * SS, (MARGIN + 16) * SS))
    shadow = shadow.filter(ImageFilter.GaussianBlur(20 * SS))
    shade = Image.new("RGBA", (full, full), (0, 0, 0, 0))
    shade.paste(Image.new("RGBA", (full, full), (0, 0, 0, 255)),
                (0, 0), shadow.point(lambda v: v * 66 // 255))

    out = Image.alpha_composite(shade, canvas)
    return out.resize((out_size, out_size), Image.LANCZOS)


# macOS appiconset 的 10 个槽位：(基准尺寸, 倍数, 实际像素, 文件名)
#
# 📢 32 / 256 / 512 这三个像素尺寸各被两个槽位用到（如 16@2x 和 32@1x 都是 32px）。
# 这里给每个槽位单独写一份文件、不共用文件名 —— 旧工程就是这么做的
# （那三个带空格的 "cat_32 1.png" 就是这个用途）。共用文件名 actool 有时会告警，
# 重新提审阶段不值得为省 3 个小文件去冒这个险。
ICON_SLOTS = [
    (16, 1, 16, "cat_16.png"),
    (16, 2, 32, "cat_32.png"),
    (32, 1, 32, "cat_32_1x.png"),
    (32, 2, 64, "cat_64.png"),
    (128, 1, 128, "cat_128.png"),
    (128, 2, 256, "cat_256.png"),
    (256, 1, 256, "cat_256_1x.png"),
    (256, 2, 512, "cat_512.png"),
    (512, 1, 512, "cat_512_1x.png"),
    (512, 2, 1024, "cat_1024.png"),
]

APPICONSET = os.path.normpath(os.path.join(
    HERE, "..", "AnimationPreviewer", "Assets.xcassets", "AppIcon.appiconset"))


def install(variant):
    """把选中方案渲染成整套尺寸，写进工程的 AppIcon.appiconset 并重写 Contents.json。"""
    master = render(variant)
    written = set()

    for base, scale, px, name in ICON_SLOTS:
        master.resize((px, px), Image.LANCZOS).save(os.path.join(APPICONSET, name))
        written.add(name)
        print(f"✓ {name:18s} {base}x{base}@{scale}x -> {px}px")

    entries = ",\n".join(
        '    {\n'
        f'      "filename" : "{name}",\n'
        '      "idiom" : "mac",\n'
        f'      "scale" : "{scale}x",\n'
        f'      "size" : "{base}x{base}"\n'
        '    }'
        for base, scale, px, name in ICON_SLOTS
    )
    contents = (
        '{\n  "images" : [\n' + entries + '\n  ],\n'
        '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n'
    )
    with open(os.path.join(APPICONSET, "Contents.json"), "w") as f:
        f.write(contents)
    print("✓ Contents.json")

    # 清掉不再被引用的旧文件（旧图那三个带空格的重复件）
    for old in sorted(os.listdir(APPICONSET)):
        if old.endswith(".png") and old not in written:
            os.remove(os.path.join(APPICONSET, old))
            print(f"✗ 移除旧文件 {old}")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "preview"

    if cmd == "preview":
        out = os.path.join(HERE, "_preview")
        os.makedirs(out, exist_ok=True)
        for key in PREVIEW_KEYS:
            label = LABELS[key]
            img = render(key)
            img.save(os.path.join(out, f"{key}_1024.png"))
            # 顺手出一张 16/32/128 拼图，用来检查小尺寸辨识度
            strip = Image.new("RGBA", (176, 128), (255, 255, 255, 0))
            x = 8
            for s in (16, 32, 128):
                strip.paste(img.resize((s, s), Image.LANCZOS), (x, (128 - s) // 2))
                x += s + 8
            strip.save(os.path.join(out, f"{key}_small.png"))
            print(f"✓ {label} → _preview/{key}_1024.png")

    elif cmd == "install":
        if len(sys.argv) < 3 or sys.argv[2] not in LABELS:
            sys.exit(f"用法: icon_gen.py install [{'|'.join(LABELS)}]")
        install(sys.argv[2])

    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
