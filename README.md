# AnimationPreviewer

![icon](https://github.com/Rogue24/JPCover/raw/master/AnimationPreviewer/icon.png) 一个用于快速预览`Lottie`&`SVGA`&`GIF`的Mac小工具。

    Feature：
        ✅ 可立即预览 Lottie & SVGA & GIF 的动画效果；
        ✅ 可截取动画任意一帧生成图片；
        ✅ 可将动画制作成视频并导出；
        ✅ 提供多种预览模式；
        ✅ 支持通过双击文件、拖到Dock图标、右键「打开方式」打开App进行预览；
        ✅ 支持拖拽动画文件到App进行预览；
        ✅ 支持通过菜单栏选择动画文件进行预览；
        ✅ 支持自定义App背景。

## 使用效果

- 快速预览动画效果（把`Lottie文件`/`SVGA文件`/`GIF文件`/`zip包`丢进App即可）：

![example1](https://github.com/Rogue24/JPCover/raw/master/AnimationPreviewer/example1.gif)

- 可截取动画的任意一帧图片保存 & 可将动画制作成视频并导出（`Lottie`&`SVGA`&`GIF`都支持）：

![example2](https://github.com/Rogue24/JPCover/raw/master/AnimationPreviewer/example2.gif)

## Tips

1. 拖拽预览支持`Lottie文件`、`SVGA文件`、`GIF文件`及其对应的`zip包`。

2. 📢 注意【带图片】的`Lottie`文件的内容需要跟以下规格保持一致：

```swift
lottie_dir:
    - data.json
    - images:
        - img_0.png
          img_1.png
          img_2.png
          ...
```

3. 除了拖拽，还能通过菜单栏打开动画文件：

![example3](https://github.com/Rogue24/JPCover/raw/master/AnimationPreviewer/example3.jpeg)

4. 可以自定义App背景图片：

![example4](https://github.com/Rogue24/JPCover/raw/master/AnimationPreviewer/example4.jpeg)

5. 可以自定义预览区域的背景色：

![example5](https://github.com/Rogue24/JPCover/raw/master/AnimationPreviewer/example5.gif)
