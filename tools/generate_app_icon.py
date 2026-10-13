#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 Frostland Express 应用图标：蒸汽火车头剪影 + 雪原暮色背景。
输出：assets/icon_app_192.png（主图标）、assets/icon_adaptive_fg_432.png、assets/icon_adaptive_bg_432.png
"""
from PIL import Image, ImageDraw

def draw_loco(d: ImageDraw.Draw, ox: float, oy: float, s: float, color):
    """蒸汽火车头侧面剪影（ox,oy 为地面参考点，s 为缩放）"""
    # 锅炉（大圆筒）
    d.rounded_rectangle([ox + 20*s, oy - 55*s, ox + 105*s, oy - 5*s], radius=25*s, fill=color)
    # 烟囱
    d.rectangle([ox + 30*s, oy - 78*s, ox + 44*s, oy - 52*s], fill=color)
    d.rectangle([ox + 26*s, oy - 84*s, ox + 48*s, oy - 76*s], fill=color)
    # 驾驶室（后部）
    d.rectangle([ox + 105*s, oy - 70*s, ox + 145*s, oy - 5*s], fill=color)
    d.polygon([(ox + 105*s, oy - 70*s), (ox + 118*s, oy - 88*s), (ox + 145*s, oy - 88*s), (ox + 145*s, oy - 70*s)], fill=color)
    # 车灯（前部）
    d.ellipse([ox + 2*s, oy - 32*s, ox + 20*s, oy - 14*s], fill=color)
    # 轮子
    for wx in (35, 70, 105, 132):
        d.ellipse([ox + wx*s - 14*s, oy - 28*s, ox + wx*s + 14*s, oy], fill=color)
        d.ellipse([ox + wx*s - 6*s, oy - 20*s, ox + wx*s + 6*s, oy - 8*s], fill=(235, 240, 245))
    # 底盘
    d.rectangle([ox + 10*s, oy - 10*s, ox + 150*s, oy - 4*s], fill=color)

def main():
    # 主图标 192×192：圆角底 + 雪原 + 车头
    W = H = 192
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 暮色背景（深蓝→橙渐变）
    for y in range(H):
        t = y / H
        r = int(24 + t * 96); g = int(46 + t * 42); b = int(84 + t * 20)
        d.line([(0, y), (W, y)], fill=(r, g, b, 255))
    # 雪原
    d.polygon([(0, 132), (60, 118), (130, 126), (192, 112), (192, 192), (0, 192)], fill=(226, 236, 246, 255))
    d.polygon([(0, 152), (80, 140), (192, 148), (192, 192), (0, 192)], fill=(240, 246, 252, 255))
    # 月亮
    d.ellipse([138, 28, 166, 56], fill=(250, 244, 220, 255))
    # 火车头（深红黑）
    draw_loco(d, 24, 150, 1.0, (52, 26, 24))
    # 烟
    for i, (px, py, pr) in enumerate([(30, 92, 8), (16, 78, 10), (44, 72, 7)]):
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(200, 205, 215, 180 - i * 40))
    # 圆角遮罩
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, W, H], radius=28, fill=255)
    img.putalpha(mask)
    img.save("assets/icon_app_192.png")
    print("icon_app_192.png OK")

    # 自适应前景 432×432：透明底 + 居中车头
    S = 432
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fg)
    draw_loco(fd, S * 0.13, S * 0.62, 2.4, (60, 30, 28))
    # 前景可裁剪区（安全区中心 66%），车头放在中心偏下
    crop = fg.crop((int(S * 0.17), int(S * 0.17), int(S * 0.83), int(S * 0.83)))
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fg.paste(crop, (int(S * 0.17), int(S * 0.17)), crop)
    fg.save("assets/icon_adaptive_fg_432.png")
    print("icon_adaptive_fg_432.png OK")

    # 自适应背景 432×432：纯色深蓝
    bg = Image.new("RGBA", (S, S), (22, 40, 72, 255))
    bg.save("assets/icon_adaptive_bg_432.png")
    print("icon_adaptive_bg_432.png OK")

if __name__ == "__main__":
    main()
