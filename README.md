# AnimationPreviewer

![icon](https://github.com/Rogue24/JPCover/raw/master/AnimationPreviewer/icon.png) 一个用于快速预览`Lottie`&`SVGA`的Mac小工具。

    Feature：
        ✅ 可立即预览 Lottie & SVGA 的动画效果；
        ✅ 可截取动画任意一帧生成图片；
        ✅ 可导出动画视频（目前仅支持Lottie）。

## 使用效果

- 快速预览动画效果（把`Lottie文件`/`SVGA文件`/`zip包`丢进App即可）：

![example1](https://github.com/Rogue24/JPCover/raw/master/AnimationPreviewer/example1.gif)

- 截取动画任意一帧生成图片 & 导出动画视频（目前仅支持`Lottie`可导出视频）：

![example2](https://github.com/Rogue24/JPCover/raw/master/AnimationPreviewer/example2.gif)

## Tips

1. 拖拽预览支持`Lottie文件`、`SVGA文件`、及其对应的`zip包`

2. `Lottie文件`内容需要跟以下规格保持一致：

```swift
lottie_dir:
    - data.json
    - images:
        - img_0.png
          img_1.png
          img_2.png
          ...
```
