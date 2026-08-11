# Icon Composer 素材(macOS 26 Liquid Glass 图标)

这些素材用于把 App 图标升级为 macOS 26 Tahoe 的 `.icon` 分层格式(真·玻璃质感 + 暗色/色调变体)。
当前项目里的 `AppIcon.appiconset` 已经是「满版新规格」,能正常编译过审;`.icon` 是可选的进一步升级。

## 文件

| 文件 | 用途 |
|---|---|
| `前景-猫.png` | 透明底、已居中的猫,作为 Icon Composer 的**前景图层** |
| `背景-白.png` | 纯白背景层(也可在 Icon Composer 里直接选背景色/渐变,不必用这张) |

## 在 Icon Composer 里的操作步骤

1. 打开 `Icon Composer.app`(已安装),新建文档。
2. 背景:直接在右侧 inspector 选一个背景色(建议纯白 `#FFFFFF`),或拖入 `背景-白.png`。
3. 前景:把 `前景-猫.png` 拖进图层区,作为最上层。
4. (可选)把前景归到一个 Group,在 Group 上开启 Liquid Glass、调透明度/高光/阴影。
   - ⚠️ 整个图标**最多 4 个 Group**,超过无法正确编译。
5. 生成 Dark / Tinted / Clear 变体(inspector 里逐个外观微调)。
6. 菜单 File ▸ Export,导出为 `AppIcon.icon`。
7. 把 `AppIcon.icon` 拖进 Xcode 工程,Target ▸ General ▸ App Icon 选它;
   或在 Build Settings 把 `ASSETCATALOG_COMPILER_APPICON_NAME` 指向它。

## Mac Catalyst 注意事项

本项目主 App 是 **Mac Catalyst**(`SUPPORTS_MACCATALYST = YES`)。社区反馈:
Mac Catalyst + `.icon` 在 App Store Connect / Mac App Store(macOS 26)偶有
「灰边」或「列表页只显示占位图」的问题。上架前请在真机 / TestFlight 验证一次。
若遇到,回退到当前的 `AppIcon.appiconset` 满版方案即可,那套是稳妥、能过审的。

参考:
- Apple Icon Composer: https://developer.apple.com/icon-composer/
- https://successfulsoftware.net/2025/09/26/updating-application-icons-for-macos-26-tahoe-and-liquid-glass/
- https://www.hendrik-erz.de/post/supporting-liquid-glass-icons-in-apps-without-xcode
