# LottiePreviewer

一个用于快速预览Lottie的Mac小工具。

    Feature：
        ✅ 可立即预览lottie的动画效果；
        ✅ 可截取动画任意一帧生成图片；
        ✅ 可导出视频。

## 使用效果

- 快速预览lottie（把zip包丢进App即可）

![example1](https://github.com/Rogue24/JPCover/raw/master/LottiePreviewer/example1.gif)

- 截取动画任意一帧生成图片 & 导出动画视频

![example2](https://github.com/Rogue24/JPCover/raw/master/LottiePreviewer/example2.gif)

## Tips

1. 只能接收lottie的压缩包（.zip）

2. 文件内容需要保持一致：

```swift
lottie:
    - data.json
    - images
        - img_0.png
          img_0.png
          img_0.png
          ...
```
